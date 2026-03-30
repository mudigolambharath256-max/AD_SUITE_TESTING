import fs from 'fs/promises';
import path from 'path';
import { logger } from '../utils/logger';
import { getRepoRoot } from '../utils/repoRoot';

export interface ScanSummary {
    id: string;
    name: string;
    filename: string;
    path: string;
    timestamp: number;
    totalFindings: number;
    globalRiskBand: string;
    status: string;
    engine: string;
    severity: { critical: number; high: number; medium: number; low: number };
}

export class ScanService {
    private static readonly UPLOAD_DIR = path.join(
        getRepoRoot(),
        'AD-Suite-Web',
        'backend',
        'uploads',
        'analysis'
    );
    private static readonly OUT_DIR = path.join(getRepoRoot(), 'out');

    public static async listAvailableScans(): Promise<ScanSummary[]> {
        const scans: ScanSummary[] = [];
        
        // 1. Scan uploads directory
        try {
            await fs.mkdir(this.UPLOAD_DIR, { recursive: true });
            const uploadFiles = await fs.readdir(this.UPLOAD_DIR);
            for (const file of uploadFiles.filter(f => f.endsWith('.json'))) {
                const fullPath = path.join(this.UPLOAD_DIR, file);
                const summary = await this.getScanSummary(fullPath, file);
                if (summary) scans.push(summary);
            }
        } catch (err) {
            logger.error(`Error scanning uploads: ${err}`);
        }

        // 2. Scan out directory (recursive for scan-results.json)
        try {
            await fs.mkdir(this.OUT_DIR, { recursive: true });
            const outDirs = await fs.readdir(this.OUT_DIR, { withFileTypes: true });
            for (const dirent of outDirs) {
                if (dirent.isDirectory()) {
                    const resultFile = path.join(this.OUT_DIR, dirent.name, 'scan-results.json');
                    try {
                        await fs.access(resultFile);
                        const summary = await this.getScanSummary(resultFile, dirent.name);
                        if (summary) scans.push(summary);
                    } catch { /* No result file in this subfolder */ }
                } else if (dirent.name.endsWith('.json')) {
                    // Also check for direct json files in out/
                    const fullPath = path.join(this.OUT_DIR, dirent.name);
                    const summary = await this.getScanSummary(fullPath, dirent.name);
                    if (summary) scans.push(summary);
                }
            }
        } catch (err) {
            logger.error(`Error scanning out: ${err}`);
        }

        // Filter duplicates by path and sort by timestamp NEWEST first
        return scans
            .filter((v, i, a) => a.findIndex(t => t.path === v.path) === i)
            .sort((a, b) => b.timestamp - a.timestamp);
    }

    private static async getScanSummary(filePath: string, id: string): Promise<ScanSummary | null> {
        try {
            const stats = await fs.stat(filePath);
            const raw = await fs.readFile(filePath, 'utf-8');
            const data = JSON.parse(raw.replace(/^\uFEFF/, ''));
            
            // Normalize Metadata
            const meta = data.meta || data.Meta || data.metadata || data.Metadata || {};
            const agg = data.aggregate || data.Aggregate || data.aggregation || data.Aggregation || {};
            const results = data.results || data.Results || data.checks || data.Checks || [];

            const timestampStr = meta.scanTimeUtc || meta.ScanTimeUtc || meta.Timestamp || stats.mtime.toISOString();
            const timestamp = new Date(timestampStr).getTime();

            let displayName = id.replace('.json', '');
            try {
                const sidecarPath = path.join(path.dirname(filePath), 'scan.meta.json');
                const sideRaw = await fs.readFile(sidecarPath, 'utf-8');
                const side = JSON.parse(sideRaw);
                if (side.name) {
                    displayName = String(side.name);
                }
            } catch {
                /* optional */
            }
            
            // Calculate severity if not summarized
            const severity = { critical: 0, high: 0, medium: 0, low: 0 };
            const rows = Array.isArray(results) ? results : (results.checks || []);
            
            rows.forEach((r: any) => {
                const sev = (r.Severity || r.severity || '').toLowerCase();
                const count = r.FindingCount ?? r.findingCount ?? 0;
                if (count > 0 && severity[sev as keyof typeof severity] !== undefined) {
                    severity[sev as keyof typeof severity] += count;
                }
            });

            return {
                id,
                name: displayName,
                filename: path.basename(filePath),
                path: filePath,
                timestamp,
                totalFindings: agg.totalFindings || agg.TotalFindings || 0,
                globalRiskBand: agg.globalRiskBand || agg.GlobalRiskBand || 'Low',
                status: (agg.checksWithErrors || 0) > 0 ? 'Warning' : 'Complete',
                engine: meta.defaultNamingContext ? 'ADSI' : 'Local',
                severity
            };
        } catch (err) {
            return null;
        }
    }

    public static async getScanContent(id: string): Promise<any | null> {
        // Try direct file access first if ID is a filename
        try {
           const uploadPath = path.join(this.UPLOAD_DIR, id);
           await fs.access(uploadPath);
           const raw = await fs.readFile(uploadPath, 'utf-8');
           return JSON.parse(raw.replace(/^\uFEFF/, ''));
        } catch {}

        const scans = await this.listAvailableScans();
        const scan = scans.find(s => s.id === id || s.filename === id);
        if (!scan) return null;

        const raw = await fs.readFile(scan.path, 'utf-8');
        return JSON.parse(raw.replace(/^\uFEFF/, ''));
    }
}
