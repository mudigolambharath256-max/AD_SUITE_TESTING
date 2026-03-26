# AD Suite — static assessment dashboard

Purple Knight / Ping Castle–style **local** UI: open `dashboard.html` in a browser, load JSON produced by the scanner. **No data leaves your machine** (no upload, no cloud).

## Quick start

1. Run a scan (from repo root, on a domain-joined host):

   ```powershell
   .\Invoke-ADSuiteScan.ps1 -ChecksJsonPath .\checks.json -OutputDirectory .\out\latest
   ```

2. Open **`ui\dashboard.html`** in Chrome, Edge, or Firefox (double-click or `start .\ui\dashboard.html`).

3. Click **Load scan results** and select **`out\latest\scan-results.json`**.

4. Optional: regenerate and load the catalog summary:

   ```powershell
   .\tools\Export-ADSuiteCatalogSummary.ps1
   ```

   Then **Load catalog summary** and choose **`ui\catalog-summary.json`**. Use the **Scan planner** to select categories and copy a ready-made `Invoke-ADSuiteScan.ps1` command (scoped `-Category`).

## Features

- Global risk score, aggregates, rule pack meta (when present in JSON)
- **By category** table (checks, findings, errors, raw score per category) when `scan-results.json` includes `byCategory` / `aggregate.scoreByCategory`
- Top 10 checks by score
- Category chips to filter the checks table
- Sortable columns (click headers)
- Expandable row details: description, remediation, references, errors, findings preview
- **Scan planner** (after loading `catalog-summary.json`): full-catalog run (Ping Castle–style whole scan), category-scoped runs, optional `-IncludeCheckId` list, copy-ready command
- Download filtered results as JSON; print-friendly layout

## Link from `report.html`

Each scan run writes **`report.html`** next to **`scan-results.json`**. That HTML includes a link to **`../../ui/dashboard.html`** (valid when the report path is **`out\<run>\report.html`** under the repo). If your output folder layout differs, open `ui\dashboard.html` from the repository and load the JSON manually.

## Security notes

- The dashboard only reads files **you** select via the file picker. It does not phone home.
- `scan-results.json` can contain sensitive AD data (names, DNs). Treat exports like any security assessment output: restrict sharing and storage.

## Regenerating `catalog-summary.json`

After editing `checks.json`:

```powershell
.\tools\Export-ADSuiteCatalogSummary.ps1 -ChecksJsonPath .\checks.json -OutputPath .\ui\catalog-summary.json
```

Optional: `-ChecksOverridesPath` to match your scan configuration.
