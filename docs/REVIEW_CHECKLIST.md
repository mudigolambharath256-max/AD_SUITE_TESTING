# Risk rule promotion checklist

Use this before moving a check from `checks.generated.json` (inventory) into the curated pack (`checks.json` or `checks.overrides.json`).

## Per check ID

1. **Semantics** – Is every LDAP row a **misconfiguration** or exposure you want flagged, or is the filter a broad inventory (if so, keep `engine: inventory`)?
2. **Benign cases** – Are there known false positives (service accounts, built-ins)? If yes, plan `excludeSamAccountName` or tighten the filter before promoting.
3. **Severity** – Align with impact (info / low / medium / high / critical). Prefer **critical/high** only for directly exploitable or org-wide exposure patterns.
4. **UAC / post-filters** – Does the rule need `userAccountControlMustInclude` / `MustExclude` (already supported) or `excludeSamAccountName` (post-filter)?
5. **Text** – Add `description`, and for high/critical add `remediation` and `references` where practical.
6. **Scoring** – If the rule is noisy, set `scoreWeight` below `1`; if always important, leave `1` or tune after lab runs.

## Sign-off

- [ ] Validated on a **lab domain** (`Test-ADSuiteCatalog.ps1` then `Invoke-ADSuiteScan.ps1` with no unexpected LDAP errors).
- [ ] Spot-checked finding count (not thousands unless expected).
- [ ] `packVersion` bumped in `checks.json` `meta` when the promoted set changes.

See [LAB_VALIDATION.md](LAB_VALIDATION.md) for the validation workflow.
