import { Request, Response } from 'express';
import { spawn } from 'child_process';
import path from 'path';
import fs from 'fs';
import fsPromises from 'fs/promises';
import { broadcastScanUpdate } from '../websocket';
import { logger } from '../utils/logger';
import { ScanService } from '../services/scanService';
import { settingsService } from '../services/settingsService';
import { getRepoRoot } from '../utils/repoRoot';
import { findingsToCsv } from '../utils/scanExportCsv';
import { resolveChecksJsonPath, resolveChecksOverridesPath } from '../utils/catalogPaths';

export class ScanController {
    public getScans = async (_req: Request, res: Response) => {
        try {
            const scans = await ScanService.listAvailableScans();
            res.json(scans);
        } catch (e: unknown) {
            const msg = e instanceof Error ? e.message : 'Failed to list scans';
            res.status(500).json({ message: msg });
        }
    };

    public getScan = async (req: Request, res: Response) => {
        try {
            const doc = await ScanService.getScanContent(req.params.id);
            if (!doc) {
                return res.status(404).json({ message: 'Scan not found' });
            }
            const meta = doc.meta || doc.Meta || {};
            const aggregate = doc.aggregate || doc.Aggregate || {};
            res.json({
                id: req.params.id,
                meta,
                aggregate,
                results: doc.results || doc.Results || [],
                byCategory: doc.byCategory || doc.ByCategory
            });
        } catch (e: unknown) {
            const msg = e instanceof Error ? e.message : 'Failed to load scan';
            res.status(500).json({ message: msg });
        }
    };

    public createScan = (_req: Request, res: Response) => {
        const id = Date.now();
        res.json({ id, message: 'POST /api/scans/:id/execute to run the scan engine' });
    };

    public executeScan = async (req: Request, res: Response) => {
        const { id } = req.params;
        const { categories, includeCheckIds, name } = req.body as {
            categories?: string[];
            includeCheckIds?: string[];
            name?: string;
        };
        const scanId = parseInt(id, 10) || Date.now();

        logger.info(
            `Starting scan ${scanId} with categories: ${categories?.length || 0}, checkIds: ${includeCheckIds?.length || 0}`
        );
        broadcastScanUpdate(scanId, {
            status: 'running',
            message: 'Initializing Security Assessment Engine...',
            progress: 0
        });

        const rootDir = getRepoRoot();
        const scriptPath = path.join(rootDir, 'Invoke-ADSuiteScan.ps1');
        const checksJsonPath = resolveChecksJsonPath(rootDir);
        const checksOverridesPath = resolveChecksOverridesPath(rootDir);
        const outputDir = path.join(rootDir, 'out', `scan-${scanId}`);

        if (!fs.existsSync(scriptPath)) {
            logger.error(`Scan script not found at: ${scriptPath}`);
            return res.status(500).json({ error: `Scan engine script not found at ${scriptPath}` });
        }

        if (!fs.existsSync(checksJsonPath)) {
            logger.error(`Checks catalog not found at: ${checksJsonPath}`);
            return res.status(500).json({ error: `Checks catalog not found at ${checksJsonPath}` });
        }

        const overridesEnv = process.env.AD_SUITE_CHECKS_OVERRIDES || process.env.CHECKS_OVERRIDES_PATH;
        if (overridesEnv && !checksOverridesPath) {
            const attempted = path.isAbsolute(overridesEnv)
                ? overridesEnv
                : path.join(rootDir, overridesEnv);
            logger.warn(`Checks overrides env set but file not found: ${attempted}`);
        }

        const settings = await settingsService.getSettings();

        try {
            await fsPromises.mkdir(outputDir, { recursive: true });
            const metaSidecar = {
                name: name || `Scan ${scanId}`,
                scanId,
                startedAt: new Date().toISOString(),
                categories: categories || [],
                includeCheckIdsCount: includeCheckIds?.length ?? 0,
                checksJsonPath,
                checksOverridesPath: checksOverridesPath ?? null
            };
            await fsPromises.writeFile(
                path.join(outputDir, 'scan.meta.json'),
                JSON.stringify(metaSidecar, null, 2),
                'utf-8'
            );
        } catch (e) {
            logger.warn(`Could not write scan.meta.json: ${e}`);
        }

        const args: string[] = [];
        if (settings.powershell.noProfile) {
            args.push('-NoProfile');
        }
        args.push('-ExecutionPolicy', settings.powershell.executionPolicy);
        if (settings.powershell.nonInteractive) {
            args.push('-NonInteractive');
        }
        args.push('-File', scriptPath);
        args.push('-ChecksJsonPath', checksJsonPath);
        args.push('-OutputDirectory', outputDir);
        if (checksOverridesPath) {
            args.push('-ChecksOverridesPath', checksOverridesPath);
        }

        if (categories && Array.isArray(categories) && categories.length > 0) {
            categories.forEach((cat) => {
                args.push('-Category', cat);
            });
        }

        if (includeCheckIds && Array.isArray(includeCheckIds) && includeCheckIds.length > 0) {
            if (includeCheckIds.length < 100) {
                includeCheckIds.forEach((cid) => {
                    args.push('-IncludeCheckId', cid);
                });
            } else {
                logger.info(
                    `Large check count (${includeCheckIds.length}), skipping individual -IncludeCheckId to avoid CLI limits.`
                );
            }
        }

        logger.info(`Spawning: powershell.exe ${args.join(' ')}`);

        const ps = spawn('powershell.exe', args);
        let errorOutput = '';

        ps.stdout.on('data', (data) => {
            const lines = data.toString();
            const lastLine = lines.trim().split('\n').pop();
            broadcastScanUpdate(scanId, {
                status: 'running',
                message: lastLine || 'Processing...',
                progress: 50
            });
        });

        ps.stderr.on('data', (data) => {
            const err = data.toString();
            errorOutput += err;
            logger.error(`PS Error: ${err}`);
        });

        ps.on('close', (code) => {
            logger.info(`Scan ${scanId} exited with code ${code}`);
            if (code !== 0) {
                logger.error(`Scan failed. Stderr: ${errorOutput}`);
            }

            const resultPath = path.join(outputDir, 'scan-results.json');
            let summary: Record<string, unknown> = {};
            if (code === 0 && fs.existsSync(resultPath)) {
                try {
                    const raw = fs.readFileSync(resultPath, 'utf-8');
                    const doc = JSON.parse(raw.replace(/^\uFEFF/, ''));
                    const agg = doc.aggregate || doc.Aggregate || {};
                    summary = {
                        totalFindings: agg.totalFindings ?? agg.TotalFindings,
                        globalRiskBand: agg.globalRiskBand ?? agg.GlobalRiskBand,
                        checksRun: agg.checksRun,
                        globalScore: agg.globalScore,
                        checksWithErrors: agg.checksWithErrors,
                        totalFindingsAgg: agg.totalFindings
                    };
                } catch (e) {
                    logger.warn(`Could not parse scan-results.json: ${e}`);
                }
            }

            broadcastScanUpdate(scanId, {
                status: code === 0 ? 'completed' : 'failed',
                message:
                    code === 0
                        ? 'Assessment complete. Results generated.'
                        : `Scan failed (exit ${code}). Check server logs.`,
                progress: 100,
                results: {
                    summary,
                    scanResultsPath: resultPath
                }
            });
        });

        res.json({
            message: 'Scan sequence initiated',
            id: scanId,
            status: 'running',
            checksJsonPath,
            checksOverridesPath: checksOverridesPath ?? null,
            outputDir
        });
    };

    public stopScan = (_req: Request, res: Response) => {
        res.status(501).json({
            message: 'Scan stop is not implemented (no process registry).'
        });
    };

    public deleteScan = async (req: Request, res: Response) => {
        try {
            const scans = await ScanService.listAvailableScans();
            const scan = scans.find((s) => s.id === req.params.id || s.filename === req.params.id);
            if (!scan) {
                return res.status(404).json({ message: 'Scan not found' });
            }
            await fsPromises.unlink(scan.path);
            const dir = path.dirname(scan.path);
            const metaPath = path.join(dir, 'scan.meta.json');
            try {
                await fsPromises.unlink(metaPath);
            } catch {
                /* optional */
            }
            res.json({ success: true });
        } catch (e: unknown) {
            const msg = e instanceof Error ? e.message : 'Delete failed';
            res.status(500).json({ message: msg });
        }
    };

    public getScanResults = async (req: Request, res: Response) => {
        try {
            const doc = await ScanService.getScanContent(req.params.id);
            if (!doc) {
                return res.status(404).json({ message: 'Scan not found' });
            }
            res.json(doc);
        } catch (e: unknown) {
            const msg = e instanceof Error ? e.message : 'Failed to load results';
            res.status(500).json({ message: msg });
        }
    };

    public getScanFindings = async (req: Request, res: Response) => {
        try {
            const doc = await ScanService.getScanContent(req.params.id);
            if (!doc) {
                return res.status(404).json({ message: 'Scan not found' });
            }
            let results = doc.results || doc.Results || doc.checks || doc.Checks || [];
            if (!Array.isArray(results) && results && Array.isArray((results as any).checks)) {
                results = (results as any).checks;
            }
            res.json({ findings: Array.isArray(results) ? results : [] });
        } catch (e: unknown) {
            res.status(404).json({ message: 'Scan not found or parsing failed' });
        }
    };

    public exportScan = async (req: Request, res: Response) => {
        try {
            const { id, format } = req.params;
            const scans = await ScanService.listAvailableScans();
            const scan = scans.find((s) => s.id === id || s.filename === id);
            if (!scan) {
                return res.status(404).json({ message: 'Scan not found' });
            }

            if (format === 'csv') {
                const raw = await fsPromises.readFile(scan.path, 'utf-8');
                const doc = JSON.parse(raw.replace(/^\uFEFF/, ''));
                const csv = findingsToCsv(doc);
                res.setHeader('Content-Type', 'text/csv; charset=utf-8');
                res.setHeader(
                    'Content-Disposition',
                    `attachment; filename="AD_Suite_Scan_${id}.csv"`
                );
                return res.send(csv);
            }

            const ext = format === 'json' ? 'json' : 'json';
            res.download(scan.path, `AD_Suite_Scan_${id}.${ext}`);
        } catch (e: unknown) {
            const msg = e instanceof Error ? e.message : 'Export failed';
            res.status(500).json({ message: msg });
        }
    };
}
