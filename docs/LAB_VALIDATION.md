# Lab validation gate

Use a **non-production** domain or snapshot lab before trusting new risk rules.

## Steps

1. **Catalog integrity**

   ```powershell
   .\Test-ADSuiteCatalog.ps1 -CatalogPath .\checks.json
   ```

   Exit code must be `0`. Fix duplicate IDs or missing required fields before continuing.

2. **Full risk scan (lab DC)**

   ```powershell
   .\Invoke-ADSuiteScan.ps1 -ChecksJsonPath .\checks.json -ServerName <lab_dc_fqdn> -OutputDirectory .\out\review-$(Get-Date -Format yyyyMMdd-HHmm)
   ```

   Run from a host that can LDAP to the lab and reach SYSVOL if filesystem checks are included.

3. **Review outputs**

   - Open `report.html`: confirm global score, Top 10, and per-check errors.
   - In `scan-results.json`, note `aggregate.checksWithErrors` and any `Result: Error` rows.
   - Rules returning **very large** finding counts may need filter tuning or `excludeSamAccountName`.

4. **Optional automated summary**

   ```powershell
   .\Test-ADSuiteCatalog.ps1 -CatalogPath .\checks.json -LiveScan -ServerName <lab_dc_fqdn> -OutputDirectory .\out\catalog-live
   ```

   Uses the same scan script and prints error checks and high-count warnings.

## Acceptance

- **Low LDAP error rate**: most checks `Pass` or `Fail`, not `Error` (bind/search issues are environment problems).
- **Analyst spot-check**: sampled findings match the rule intent (not pure inventory noise).
