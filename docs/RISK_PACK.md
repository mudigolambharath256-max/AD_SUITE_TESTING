# AD Suite risk pack contract

This document defines how check definitions behave in the **risk scan** (Ping Castle–style rigor: trustworthy findings and explainable scores).

## Catalog files

| File | Role |
|------|------|
| `checks.unified.json` | **Single merged catalog** (optional artifact): `checks.generated.json` + `checks.overrides.phaseB-complete.json`, then **`checks.json` wins on every matching `id`** (adds ADCS/ACL/filesystem-only curated rows). Regenerate: `node tools/Merge-UnifiedChecksCatalog.js`. When this file exists in the repo root, `Invoke-ADSuiteScan.ps1`, `Test-ADSuiteCatalog.ps1`, and the web API default to it instead of `checks.json`. |
| `checks.json` | **Curated risk pack** (source): reviewed rules and `defaults`; also the overlay source for `checks.unified.json`. Use this path explicitly when you want the small pack only and no unified file. |
| `checks.overrides.json` | Optional **patches only**: same `schemaVersion`, `checks` array of partial objects keyed by `id`. Non-null fields override the base catalog. Use to **promote** a stub from inventory to `ldap` / `filesystem`, adjust `severity`, `description`, or fix `ldapFilter` without copying full definitions. |
| `checks.generated.json` | Legacy exporter output (`Export-ChecksJsonFromLegacyScripts.ps1`): **every check defaults to `engine: inventory`**. It is a full LDAP stub listing for reference, **not** a production risk catalog until individual IDs are promoted (overrides or copy into `checks.json`). |
| `checks.overrides.phaseB1.json` | **Phase B wave B1 only** (71 checks): **`Kerberos_Security`** + **`Access_Control`**. Same merge rules as below. Regenerate: `node tools/Generate-PhaseB1Overrides.js`. |
| `checks.overrides.phaseB-complete.json` | **Phase B waves B1–B11** (661 checks): promotes every stub in `checks.generated.json` **except** **`Certificate_Services`** and **`Azure_AD_Integration`** (Phase C/D). Merges **metadata from `checks.json`** where `id` matches; otherwise heuristic **severity** and generic **remediation** / **references** via `tools/phaseBOverrideHelpers.js`. Regenerate: `node tools/Generate-PhaseBCompleteOverrides.js`. Validate: `Test-ADSuiteCatalog.ps1 -CatalogPath .\checks.generated.json -OverridesPath .\checks.overrides.phaseB-complete.json`. Full LDAP scan (no CERT/Azure): `Invoke-ADSuiteScan.ps1 -ChecksJsonPath .\checks.generated.json -ChecksOverridesPath .\checks.overrides.phaseB-complete.json` (optionally `-ExcludeCheckId` for categories still under review). |

**Production vs staging:** if `checks.unified.json` is present, the scanner and API default to it (one file, full Phase B + curated overlay). Otherwise default to `-ChecksJsonPath .\checks.json` (plus optional overrides). Pointing the scanner at `checks.generated.json` alone will **skip all checks** for risk (all inventory) unless you patch specific IDs to `ldap`, `filesystem`, or **`adcs`** via `checks.overrides.json` or promote into `checks.json`.

**AD-Suite-Web backend:** `GET /api/checks` and scan execution use the **same** resolution: `CHECKS_JSON_PATH` or `AD_SUITE_CHECKS_JSON` (default: `checks.unified.json` if it exists, else `checks.json`), merged with `CHECKS_OVERRIDES_PATH` or `AD_SUITE_CHECKS_OVERRIDES`, or automatic `checks.overrides.json` when that file exists. The API lists only **runnable** checks (`ldap`, `filesystem`, `adcs`, `acl`) unless you pass **`?includeInventory=1`**, which also includes `inventory` stubs for reference.

**Phase C (AD CS):** curated checks `ADCS-ESC1` … `ADCS-ESC8` use `engine: adcs` and `adcsCheck: ESC1` … `ESC8`, implemented in `Modules/ADSuite.Adcs.psm1`. Optional scan switches: `-AdcsSkipACLChecks` (skip ESC4, ESC5, ESC7), `-AdcsSkipNetworkProbes` (skip `certutil` ESC6 and HTTP/S probes for ESC8). ESC6 may return **Info** findings when the scanning host cannot reach the CA over RPC for `certutil`.

**Certificate_Services LDAP (`CERT-*`):** `checks.json` includes promoted **`engine: ldap`** rules sourced from `checks.generated.json` (metadata in `tools/CertificateServicesLdapMetadata.json`). **`CERT-002`–`CERT-005` and `CERT-020`–`CERT-022` are omitted** here because they overlap **`ADCS-ESC1`–`ESC8`**. Configuration-partition PKI objects use **`searchBase: Configuration`**; **`CERT-023` / `CERT-024`** (`userCertificate` on users/computers) use **`Domain`**. Regenerate / re-merge: `tools\Build-CertificateServicesLdapChecks.ps1 -MergeIntoChecksJson`.

**See also:** [CATALOG_ESC_CERT_AND_AAD.md](CATALOG_ESC_CERT_AND_AAD.md) — **`ADCS-ESC*`** vs **`CERT-*`** stubs and **`AAD-*`** / Azure limitations.

### Promoting many stubs from `checks.generated.json`

Overrides **merge into the base file** by `id`; every `id` in `checks.overrides.json` must already exist in the base catalog (`Merge-ADSuiteCatalogOverrides` skips unknown ids with a warning). Typical workflows:

1. **Curated-only:** keep production rules in `checks.json` and use `checks.overrides.json` only for small patches (severity, `ldapFilter` fixes, metadata).
2. **Large generated catalog + promotions:** use `-ChecksJsonPath .\checks.generated.json` and put partial promotions (e.g. `"engine": "ldap"`, `severity`, `remediation`) in `checks.overrides.json` for IDs that exist in the generated file. That promotes individual rules without duplicating the full 700+ rows into `checks.json`.
3. **Classification before promotion:** run `tools\Classify-GeneratedCatalogStubs.ps1` to see counts by category/engine and buckets (e.g. `Certificate_Services`, `Azure_AD_Integration`) for Phase B LDAP-first work.

To bulk-reset a generated file to inventory defaults (after editing), use `tools\Set-GeneratedCatalogInventoryDefault.ps1`.

Load order: read base JSON → merge `defaults` per check → apply overrides by `id` → run validation (`Test-ADSuiteCatalog.ps1`).

**Title vs LDAP implementation:** Some catalog rows reuse generic `ldapFilter` values while names imply machine policy (SMB/LDAP signing, NTLM, ports, etc.). Regenerate the audit with `node tools/Audit-CheckSemantics.js` → `docs/CHECK_SEMANTICS_AUDIT.md` and `docs/check-semantics-audit.json`.

## Engines

| `engine` | Risk scan | Meaning |
|----------|-----------|---------|
| `ldap` | Included | LDAP query; each returned row is a **finding** unless post-filtered in code (e.g. UAC masks). |
| `filesystem` | Included | Host-accessible paths (e.g. SYSVOL); finding rows from implementation. |
| `registry` | **Skipped in scan** | Not executed until implemented; definitions may exist in catalogs but `Invoke-ADSuiteScan.ps1` excludes `engine: registry` so runs do not fail on an unimplemented engine. |
| `adcs` | Included | AD Certificate Services ESC-style checks (LDAP + ACL analysis; optional `certutil` / HTTP per check). Requires **`adcsCheck`**: `ESC1` … `ESC8`. See `Modules/ADSuite.Adcs.psm1`. |
| `acl` | Included | Paged LDAP with **DACL read** (`nTSecurityDescriptor`). Flags **Allow** ACEs where the trustee is **not** in the baseline privileged SID set (same idea as AD CS ACL helpers) and the rights intersect **`dangerousRights`** (e.g. `GenericAll`, `WriteDacl`). **`maxObjects`** caps work per check; **`ScanNote`** records caps or per-object ACL read failures while the scan continues. Not a CVSS substitute—high volume on broad filters (e.g. `WriteProperty`). Prefer a writable DC via **`-ServerName`**; scope is single domain / partition from **`searchBase`**. Overlaps in theme with **AD CS** template/CA ACL checks (**ADCS-ESC***) but targets arbitrary LDAP scopes. See `Invoke-ADSuiteAclCheck` in `Modules/ADSuite.Adsi.psm1`. |
| `inventory` | **Excluded** | Documentation / raw listing only; not pass/fail misconfiguration. Use `adsi.ps1` after setting `engine` to `ldap` for debugging, or run inventory-only tooling separately. |

## Required fields (risk checks)

- **`id`**, **`category`**, **`engine`**, **`severity`**, **`description`**

For `ldap`: **`searchBase`**, **`ldapFilter`**.

For `filesystem`: **`filesystemKind`** (and kind-specific fields, e.g. `sysvolPoliciesPath`). **`SysvolGptTmplSecedit`** reads `\\<domain>\SYSVOL\<domain>\Policies\{GUID}\Machine\Microsoft\Windows NT\SecEdit\GptTmpl.inf` and evaluates **`gptTmplRules`** against the `[Registry Values]` section (dword pairs `4,<value>`). Use for SMB/LDAP signing, NTLM compatibility, and related policy **as deployed via GPO templates** — not live remote registry.

For `adcs`: **`adcsCheck`** (`ESC1` through `ESC8`).

For `acl`: **`searchBase`**, **`ldapFilter`**, **`dangerousRights`** (array of `ActiveDirectoryRights` names, e.g. `GenericAll`, `WriteDacl`), **`maxObjects`** (positive integer; required cap per check).

## Optional fields

- **`name`**, **`sourcePath`**, **`outputProperties`**, **`propertiesToLoad`**, **`postFilter`** (implementation-specific)
- **`excludeSamAccountName`**: array of `samAccountName` values to drop from LDAP results after the query (post-filter; case-insensitive). Use for known benign accounts (e.g. `krbtgt` on Kerberoast-style rules).
- **`remediation`**: short plain-text guidance (shown in HTML report).
- **`references`**: string or array of URLs / doc IDs (shown in HTML).
- **`scoreWeight`**: multiplier for this check’s contribution to raw score (default `1`). Use to down-rank noisy rules after review.
- **`excludePrivilegedPrincipal`**: for `acl`, when `true` (default), ACEs whose trustee resolves to a **baseline** privileged SID (e.g. SYSTEM, Administrators, Domain Admins, Enterprise Admins, Schema Admins, Enterprise Domain Controllers) are not reported. Set `false` only for specialized reviews.

## Finding semantics

- **Pass** for a risk check: `FindingCount == 0` and no error.
- **Fail**: at least one finding row.
- **Error**: LDAP/filesystem failure, invalid definition, or unimplemented engine.

## Scoring (global risk)

Per check (when not skipped: not Error/Skipped):

1. `weight = Get-ADSuiteSeverityWeight(severity)` (info=1 … critical=5).
2. `capped = min(FindingCount, FindingCapPerCheck)` (default cap 10).
3. `CheckScore = weight × capped × scoreWeight` (default `scoreWeight` = 1).

Aggregate:

- `globalRaw = sum(CheckScore)` over checks.
- `globalScore = min(100, ceil(globalRaw / ScoringNormalizer))` (default normalizer 5).

**Limitations:** The score is a **relative** workload/complexity indicator, **not** a CVSS or compliance pass/fail. It does **not** measure exploitability or business impact by itself. **Do not** report the global score as a penetration-test or audit verdict without analyst review. Tuning `FindingCapPerCheck`, `ScoringNormalizer`, and per-check `scoreWeight` is expected after catalog review.

**Certificate LDAP (`CERT-*`) rows:** Some checks are **explicit listings** (`[Listing]` in the name) or **`scoreWeight: 0`**—they support triage and documentation, not a single “vuln per row” guarantee. Prefer **`ADCS-ESC1`–`ESC8`** for ESC-class analysis; use **`CERT-*`** as supplementary LDAP signals.

## Versioning

Bump `schemaVersion` in the JSON when breaking field meanings; document changes here.
