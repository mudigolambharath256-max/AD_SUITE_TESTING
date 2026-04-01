"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const promises_1 = __importDefault(require("fs/promises"));
const auth_1 = require("../middleware/auth");
const scanService_1 = require("../services/scanService");
const router = express_1.default.Router();
router.use(auth_1.authenticate);
router.use((0, auth_1.authorize)('admin', 'analyst', 'viewer'));
async function getAvailableScans() {
    const summaries = await scanService_1.ScanService.listAvailableScans();
    const details = await Promise.all(summaries.map(async (s) => {
        try {
            const raw = await promises_1.default.readFile(s.path, 'utf-8');
            const safeRaw = raw.replace(/^\uFEFF/, '');
            const doc = JSON.parse(safeRaw);
            let results = doc.Results ?? doc.results ?? doc.checks ?? doc.Checks ?? [];
            if (doc.Aggregation?.checks) {
                results = doc.Aggregation.checks;
            }
            if (!Array.isArray(results) && doc.results?.checks) {
                results = doc.results.checks;
            }
            const meta = doc.meta || doc.Meta || {};
            const timestampRaw = meta.scanTimeUtc ||
                meta.ScanTimeUtc ||
                meta.Timestamp ||
                doc.metadata?.scanTimeUtc ||
                s.timestamp;
            const timestamp = timestampRaw
                ? new Date(timestampRaw).getTime()
                : s.timestamp;
            return {
                id: s.id,
                timestamp,
                results: Array.isArray(results) ? results : []
            };
        }
        catch {
            return null;
        }
    }));
    return details.filter(Boolean).sort((a, b) => b.timestamp - a.timestamp);
}
// GET /api/dashboard/stats
router.get('/stats', async (_req, res, next) => {
    try {
        const scans = await getAvailableScans();
        if (scans.length === 0) {
            return res.json({
                totalChecks: 0,
                severityData: { critical: 0, high: 0, medium: 0, low: 0, info: 0 },
                categoryData: {},
                activeScans: 0,
                riskScore: 0,
                postureScore: 100,
                delta: 0,
                trends: []
            });
        }
        // Latest scan represents "Current Posture"
        const latestScan = scans[0];
        const severityData = {
            critical: 0, high: 0, medium: 0, low: 0, info: 0
        };
        const categoryData = {};
        let totalRiskPenalty = 0;
        latestScan.results.forEach((r) => {
            const sev = (r.Severity || r.severity || '').toLowerCase();
            const cat = r.Category || r.category || 'Unknown';
            const count = r.FindingCount ?? r.findingCount ?? 0;
            if (count > 0) {
                if (sev && severityData[sev] !== undefined) {
                    severityData[sev] += count;
                    if (sev === 'critical')
                        totalRiskPenalty += count * 10;
                    else if (sev === 'high')
                        totalRiskPenalty += count * 5;
                    else if (sev === 'medium')
                        totalRiskPenalty += count * 3;
                    else if (sev === 'low')
                        totalRiskPenalty += count * 1;
                }
                categoryData[cat] = (categoryData[cat] || 0) + count;
            }
        });
        const riskScore = totalRiskPenalty;
        const postureScore = Math.max(0, 100 - (riskScore / 2));
        // Calculate delta (current total findings vs previous scan)
        let delta = 0;
        const currFindings = Object.values(severityData).reduce((a, b) => a + b, 0);
        if (scans.length > 1) {
            const previousScan = scans[1];
            let prevFindings = 0;
            previousScan.results.forEach((r) => {
                prevFindings += (r.FindingCount ?? r.findingCount ?? 0);
            });
            delta = currFindings - prevFindings;
        }
        else {
            delta = currFindings;
        }
        // Generate historical trends
        const trends = scans.slice(0, 10).reverse().map((scan) => {
            let trFindings = 0;
            let trRisk = 0;
            scan.results.forEach((r) => {
                let c = r.FindingCount ?? r.findingCount ?? 0;
                if (c > 0) {
                    trFindings += c;
                    let s = (r.Severity || r.severity || '').toLowerCase();
                    if (s === 'critical')
                        trRisk += c * 10;
                    else if (s === 'high')
                        trRisk += c * 5;
                    else if (s === 'medium')
                        trRisk += c * 3;
                    else if (s === 'low')
                        trRisk += c * 1;
                }
            });
            return {
                id: scan.id,
                timestamp: scan.timestamp,
                totalFindings: trFindings,
                riskScore: trRisk,
                postureScore: Math.max(0, 100 - (trRisk / 2))
            };
        });
        res.json({
            totalChecks: latestScan.results.length,
            severityData,
            categoryData,
            activeScans: 0,
            riskScore,
            postureScore: Math.round(postureScore),
            delta,
            trends
        });
    }
    catch (error) {
        next(error);
    }
});
// GET /api/dashboard/recent
router.get('/recent', async (_req, res, next) => {
    try {
        const scans = await getAvailableScans();
        const recent = scans.slice(0, 10).map((scan) => {
            const totalFindings = scan.results.reduce((acc, r) => acc + (r.FindingCount ?? r.findingCount ?? 0), 0);
            return {
                id: scan.id,
                timestamp: scan.timestamp,
                status: 'completed',
                totalFindings
            };
        });
        res.json({ recent });
    }
    catch (error) {
        next(error);
    }
});
exports.default = router;
//# sourceMappingURL=dashboard.js.map