# Global health score methodology

AD Suite computes a **relative risk indicator** (0–100 scale in reports) from catalog checks. It is **not** a CVSS score, a penetration-test verdict, or a compliance certification.

## Inputs

- Each runnable check (`ldap`, `filesystem`, `adcs`, `acl`) contributes when it completes without error.
- **Severity** maps to a weight (e.g. critical higher than info). See [`docs/RISK_PACK.md`](RISK_PACK.md).
- **Finding count** per check is capped (`FindingCapPerCheck`, default 10) to limit dominance of noisy rules.
- Optional **`scoreWeight`** on a check reduces or zeroes contribution (e.g. informational placeholders).

## Formula (summary)

Per check: `weight(severity) × min(findings, cap) × scoreWeight`.

Aggregate raw score is summed, then normalized to a 0–100 style band using `ScoringNormalizer` (default 5). Exact constants are defined in [`Invoke-ADSuiteScan.ps1`](../Invoke-ADSuiteScan.ps1) and [`Modules/ADSuite.Adsi.psm1`](../Modules/ADSuite.Adsi.psm1) (`Add-ADSuiteScanScores`).

## How to use it

- **Trending:** Compare the same catalog version and scan parameters over time; treat large jumps as triage signals, not proof of exploitation.
- **Tuning:** After catalog review, lower `scoreWeight` on chatty rules or exclude check IDs from production packs.
- **Executive reporting:** Pair the score with **findings counts by severity**, top failing checks, and analyst notes—never the number alone.

## Reproducibility

Each `scan-results.json` includes `meta.scanTimeUtc`, `meta.checksJsonPath`, `meta.adSuiteEngineVersion`, and optional `meta.sourceGitCommit` when git is available. Archive those fields with the report for audit replay discussions.
