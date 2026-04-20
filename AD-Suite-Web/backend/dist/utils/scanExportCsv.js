"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.findingsToCsv = findingsToCsv;
const scanDocumentResults_1 = require("./scanDocumentResults");
/** Flatten per-check findings from scan-results.json into CSV text. */
function findingsToCsv(doc) {
    const results = (0, scanDocumentResults_1.extractResultsArrayFromScanDocument)(doc);
    const rows = [];
    for (const r of results) {
        const check = r;
        const findings = (check.Findings ?? check.findings ?? []);
        for (const f of findings) {
            rows.push({
                CheckId: check.CheckId ?? check.checkId,
                CheckName: check.CheckName ?? check.checkName,
                Category: check.Category ?? check.category,
                Severity: check.Severity ?? check.severity,
                ...(typeof f === 'object' && f !== null ? f : {})
            });
        }
    }
    if (rows.length === 0) {
        return 'CheckId,CheckName,Category,Severity\n';
    }
    const keySet = new Set();
    rows.forEach((row) => {
        Object.keys(row).forEach((k) => keySet.add(k));
    });
    const keys = Array.from(keySet);
    const esc = (v) => {
        const s = v == null ? '' : String(v);
        if (s.includes(',') || s.includes('"') || s.includes('\n')) {
            return `"${s.replace(/"/g, '""')}"`;
        }
        return s;
    };
    const lines = [keys.join(',')];
    rows.forEach((row) => {
        lines.push(keys.map((k) => esc(row[k])).join(','));
    });
    return lines.join('\n');
}
//# sourceMappingURL=scanExportCsv.js.map