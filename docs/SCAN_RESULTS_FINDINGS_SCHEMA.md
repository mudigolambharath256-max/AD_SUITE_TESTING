# Scan results JSON: findings shape

This document matches how the **backend** (`extractResultsArrayFromScanDocument`) and **frontend** (`extractScanResultsArray` in `AD-Suite-Web/frontend/src/lib/scanFindings.ts`) resolve the per-check results array from a scan document.

## Top-level document

Typical keys (example: `out/scan-<id>/scan-results.json`):

| Key | Role |
|-----|------|
| `schemaVersion` | Optional version number |
| `meta` | Run metadata (timestamp, domain, paths, etc.) |
| `aggregate` | Rollups such as `totalFindings`, severity counts |
| `byCategory` | Optional per-category summaries |
| `results` | **Primary** array of check objects |

Aliases supported when reading: `Results`, `checks`, `Checks`. If `results` is an object with a nested `checks` array, that inner array is used.

## Each element of `results[]` (a “check” row)

| Key | Notes |
|-----|------|
| `CheckId` | Stable id for the check |
| `CheckName` | Display name |
| `Category` | Grouping for filters / charts |
| `Severity` | Often **lowercase** in engine output (`critical`, `high`, `medium`, `low`); UI normalizes for filters |
| `FindingCount` | Count of nested findings (may duplicate `Findings.length`) |
| `Result` | Pass/fail style outcome |
| `Findings` | Array of per-object rows (users, groups, GPOs, etc.) |

Nested **finding** objects usually repeat `CheckId` / `Severity` and add AD-specific fields (`SamAccountName`, `DistinguishedName`, etc.).

## Counts vs rows

- **`aggregate.totalFindings`** is the authoritative total count of nested findings across checks.
- **Analysis** lists and filters **check-level** rows from `results[]` (one row per check), not one row per nested finding.
- **Attack Path** and **entity graph** flatten `results[].Findings[]` into rows via `flattenFindingRows` (parent check metadata is merged when missing on child rows).

## Empty `results`

If the file only has `aggregate` and no recognizable `results` / `checks` array, the app treats findings as **zero** until the array is present. Ensure exports use the structure above.
