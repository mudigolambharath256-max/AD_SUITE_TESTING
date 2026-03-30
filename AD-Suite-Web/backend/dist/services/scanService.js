"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.ScanService = void 0;
const promises_1 = __importDefault(require("fs/promises"));
const path_1 = __importDefault(require("path"));
const logger_1 = require("../utils/logger");
const repoRoot_1 = require("../utils/repoRoot");
class ScanService {
    static async listAvailableScans() {
        const scans = [];
        // 1. Scan uploads directory
        try {
            await promises_1.default.mkdir(this.UPLOAD_DIR, { recursive: true });
            const uploadFiles = await promises_1.default.readdir(this.UPLOAD_DIR);
            for (const file of uploadFiles.filter(f => f.endsWith('.json'))) {
                const fullPath = path_1.default.join(this.UPLOAD_DIR, file);
                const summary = await this.getScanSummary(fullPath, file);
                if (summary)
                    scans.push(summary);
            }
        }
        catch (err) {
            logger_1.logger.error(`Error scanning uploads: ${err}`);
        }
        // 2. Scan out directory (recursive for scan-results.json)
        try {
            await promises_1.default.mkdir(this.OUT_DIR, { recursive: true });
            const outDirs = await promises_1.default.readdir(this.OUT_DIR, { withFileTypes: true });
            for (const dirent of outDirs) {
                if (dirent.isDirectory()) {
                    const resultFile = path_1.default.join(this.OUT_DIR, dirent.name, 'scan-results.json');
                    try {
                        await promises_1.default.access(resultFile);
                        const summary = await this.getScanSummary(resultFile, dirent.name);
                        if (summary)
                            scans.push(summary);
                    }
                    catch { /* No result file in this subfolder */ }
                }
                else if (dirent.name.endsWith('.json')) {
                    // Also check for direct json files in out/
                    const fullPath = path_1.default.join(this.OUT_DIR, dirent.name);
                    const summary = await this.getScanSummary(fullPath, dirent.name);
                    if (summary)
                        scans.push(summary);
                }
            }
        }
        catch (err) {
            logger_1.logger.error(`Error scanning out: ${err}`);
        }
        // Filter duplicates by path and sort by timestamp NEWEST first
        return scans
            .filter((v, i, a) => a.findIndex(t => t.path === v.path) === i)
            .sort((a, b) => b.timestamp - a.timestamp);
    }
    static async getScanSummary(filePath, id) {
        try {
            const stats = await promises_1.default.stat(filePath);
            const raw = await promises_1.default.readFile(filePath, 'utf-8');
            const data = JSON.parse(raw.replace(/^\uFEFF/, ''));
            // Normalize Metadata
            const meta = data.meta || data.Meta || data.metadata || data.Metadata || {};
            const agg = data.aggregate || data.Aggregate || data.aggregation || data.Aggregation || {};
            const results = data.results || data.Results || data.checks || data.Checks || [];
            const timestampStr = meta.scanTimeUtc || meta.ScanTimeUtc || meta.Timestamp || stats.mtime.toISOString();
            const timestamp = new Date(timestampStr).getTime();
            let displayName = id.replace('.json', '');
            try {
                const sidecarPath = path_1.default.join(path_1.default.dirname(filePath), 'scan.meta.json');
                const sideRaw = await promises_1.default.readFile(sidecarPath, 'utf-8');
                const side = JSON.parse(sideRaw);
                if (side.name) {
                    displayName = String(side.name);
                }
            }
            catch {
                /* optional */
            }
            // Calculate severity if not summarized
            const severity = { critical: 0, high: 0, medium: 0, low: 0 };
            const rows = Array.isArray(results) ? results : (results.checks || []);
            rows.forEach((r) => {
                const sev = (r.Severity || r.severity || '').toLowerCase();
                const count = r.FindingCount ?? r.findingCount ?? 0;
                if (count > 0 && severity[sev] !== undefined) {
                    severity[sev] += count;
                }
            });
            return {
                id,
                name: displayName,
                filename: path_1.default.basename(filePath),
                path: filePath,
                timestamp,
                totalFindings: agg.totalFindings || agg.TotalFindings || 0,
                globalRiskBand: agg.globalRiskBand || agg.GlobalRiskBand || 'Low',
                status: (agg.checksWithErrors || 0) > 0 ? 'Warning' : 'Complete',
                engine: meta.defaultNamingContext ? 'ADSI' : 'Local',
                severity
            };
        }
        catch (err) {
            return null;
        }
    }
    static async getScanContent(id) {
        // Try direct file access first if ID is a filename
        try {
            const uploadPath = path_1.default.join(this.UPLOAD_DIR, id);
            await promises_1.default.access(uploadPath);
            const raw = await promises_1.default.readFile(uploadPath, 'utf-8');
            return JSON.parse(raw.replace(/^\uFEFF/, ''));
        }
        catch { }
        const scans = await this.listAvailableScans();
        const scan = scans.find(s => s.id === id || s.filename === id);
        if (!scan)
            return null;
        const raw = await promises_1.default.readFile(scan.path, 'utf-8');
        return JSON.parse(raw.replace(/^\uFEFF/, ''));
    }
}
exports.ScanService = ScanService;
ScanService.UPLOAD_DIR = path_1.default.join((0, repoRoot_1.getRepoRoot)(), 'AD-Suite-Web', 'backend', 'uploads', 'analysis');
ScanService.OUT_DIR = path_1.default.join((0, repoRoot_1.getRepoRoot)(), 'out');
//# sourceMappingURL=scanService.js.map