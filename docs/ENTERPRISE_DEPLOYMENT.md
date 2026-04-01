# Enterprise deployment guide

## Topology

| Component | Requirement |
|-----------|-------------|
| **Scan engine** | Windows PowerShell 5.1+ with LDAP access to Active Directory (typically a **domain-joined** workstation or server). |
| **Catalog files** | `checks.json`, `checks.unified.json`, or generated + overrides; path passed via `-ChecksJsonPath`. |
| **AD CS checks** | `Invoke-ADSuiteAdcsCheck` may need reachability to CAs and optional `certutil` / HTTP probes per check definition. |
| **SYSVOL / GPO checks** | Host must read `\\<domain>\SYSVOL\...` (domain user usually sufficient). |
| **AD-Suite-Web** | Node.js backend defaults to loading the repo root via [`getRepoRoot`](../AD-Suite-Web/backend/src/utils/repoRoot.ts); **the API spawns** [`Invoke-ADSuiteScan.ps1`](../Invoke-ADSuiteScan.ps1) on the **same machine** as the repo. Production layouts either co-locate web + engine on a jump box or run scans via **Task Scheduler / CI** and upload JSON to the API. |

## Scheduling scans (no in-app cron required)

Use **Windows Task Scheduler** or **Azure DevOps / GitHub Actions self-hosted Windows runners** to run:

```powershell
Set-Location 'C:\Path\To\AD_SUITE'
.\Invoke-ADSuiteScan.ps1 -ChecksJsonPath .\checks.unified.json -OutputDirectory .\out\scheduled\$(Get-Date -Format yyyyMMdd-HHmm)
```

Pin the catalog path and archive `scan-results.json` + `meta` for change control.

### Trend file

Successful scans append one JSON line per run to `out\trends-history.jsonl` (repo root `out` folder) for simple trending without a database.

## Web API hardening

- Set **`JWT_SECRET`** (≥ 32 characters) and `NODE_ENV=production`.
- Prefer **HTTPS** reverse proxy (IIS, nginx) in front of the Node listener.
- Optional **OpenID Connect**: configure `OIDC_ISSUER`, `OIDC_CLIENT_ID`, `OIDC_CLIENT_SECRET`, `OIDC_REDIRECT_URI` (see [`AD-Suite-Web/README.md`](../AD-Suite-Web/README.md) once OIDC is enabled).

## Catalog CI

On pull requests that touch `checks.json`, `checks.generated.json`, or merge tooling, run:

```text
node tools/Merge-UnifiedChecksCatalog.js
.\Test-ADSuiteCatalog.ps1
node tools/Audit-CheckSemantics.js
```

See [`.github/workflows/catalog-ci.yml`](../.github/workflows/catalog-ci.yml) if present.

## Secrets

Do not commit `.env`. Prefer OS secret store, Key Vault, or sealed deployment manifests for JWT, OIDC client secrets, and any future DB credentials.
