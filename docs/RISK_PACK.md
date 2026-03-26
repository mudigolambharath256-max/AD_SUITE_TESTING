# AD Suite risk pack contract

This document defines how check definitions behave in the **risk scan** (Ping Castle–style rigor: trustworthy findings and explainable scores).

## Catalog files

| File | Role |
|------|------|
| `checks.json` | **Production risk pack** (curated): use this path for `Invoke-ADSuiteScan.ps1` when you want Ping Castle–style **reviewed** rules only. Optional `defaults` merged into each check. |
| `checks.overrides.json` | Optional **patches only**: same `schemaVersion`, `checks` array of partial objects keyed by `id`. Non-null fields override the base catalog. Use to **promote** a stub from inventory to `ldap` / `filesystem`, adjust `severity`, `description`, or fix `ldapFilter` without copying full definitions. |
| `checks.generated.json` | Legacy exporter output (`Export-ChecksJsonFromLegacyScripts.ps1`): **every check defaults to `engine: inventory`**. It is a full LDAP stub listing for reference, **not** a production risk catalog until individual IDs are promoted (overrides or copy into `checks.json`). |

**Production vs staging:** run risk scans with `-ChecksJsonPath .\checks.json` (plus optional overrides). Pointing the scanner at `checks.generated.json` alone will **skip all checks** for risk (all inventory) unless you patch specific IDs to `ldap` or `filesystem` via `checks.overrides.json`.

To bulk-reset a generated file to inventory defaults (after editing), use `tools\Set-GeneratedCatalogInventoryDefault.ps1`.

Load order: read base JSON → merge `defaults` per check → apply overrides by `id` → run validation (`Test-ADSuiteCatalog.ps1`).

## Engines

| `engine` | Risk scan | Meaning |
|----------|-----------|---------|
| `ldap` | Included | LDAP query; each returned row is a **finding** unless post-filtered in code (e.g. UAC masks). |
| `filesystem` | Included | Host-accessible paths (e.g. SYSVOL); finding rows from implementation. |
| `registry` | Included | Reserved; stub returns error until implemented. |
| `inventory` | **Excluded** | Documentation / raw listing only; not pass/fail misconfiguration. Use `adsi.ps1` after setting `engine` to `ldap` for debugging, or run inventory-only tooling separately. |

## Required fields (risk checks)

- **`id`**, **`category`**, **`engine`**, **`severity`**, **`description`**

For `ldap`: **`searchBase`**, **`ldapFilter`**.

For `filesystem`: **`filesystemKind`** (and kind-specific fields, e.g. `sysvolPoliciesPath`).

## Optional fields

- **`name`**, **`sourcePath`**, **`outputProperties`**, **`propertiesToLoad`**, **`postFilter`** (implementation-specific)
- **`excludeSamAccountName`**: array of `samAccountName` values to drop from LDAP results after the query (post-filter; case-insensitive). Use for known benign accounts (e.g. `krbtgt` on Kerberoast-style rules).
- **`remediation`**: short plain-text guidance (shown in HTML report).
- **`references`**: string or array of URLs / doc IDs (shown in HTML).
- **`scoreWeight`**: multiplier for this check’s contribution to raw score (default `1`). Use to down-rank noisy rules after review.

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

**Limitations:** The score is a **relative** workload/complexity indicator, not a CVSS rating. Tuning `FindingCapPerCheck`, `ScoringNormalizer`, and per-check `scoreWeight` is expected after catalog review.

## Versioning

Bump `schemaVersion` in the JSON when breaking field meanings; document changes here.
