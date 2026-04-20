"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.ScanController = void 0;
const child_process_1 = require("child_process");
const path_1 = __importDefault(require("path"));
const fs_1 = __importDefault(require("fs"));
const promises_1 = __importDefault(require("fs/promises"));
const websocket_1 = require("../websocket");
const logger_1 = require("../utils/logger");
const scanService_1 = require("../services/scanService");
const settingsService_1 = require("../services/settingsService");
const repoRoot_1 = require("../utils/repoRoot");
const scanExportCsv_1 = require("../utils/scanExportCsv");
const scanDocumentResults_1 = require("../utils/scanDocumentResults");
const catalogPaths_1 = require("../utils/catalogPaths");
const scanEngineMapping_1 = require("../utils/scanEngineMapping");
class ScanController {
    constructor() {
        this.getScans = async (_req, res) => {
            try {
                const scans = await scanService_1.ScanService.listAvailableScans();
                res.json(scans);
            }
            catch (e) {
                const msg = e instanceof Error ? e.message : 'Failed to list scans';
                res.status(500).json({ message: msg });
            }
        };
        this.getScan = async (req, res) => {
            try {
                const doc = await scanService_1.ScanService.getScanContent(req.params.id);
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
            }
            catch (e) {
                const msg = e instanceof Error ? e.message : 'Failed to load scan';
                res.status(500).json({ message: msg });
            }
        };
        this.createScan = (_req, res) => {
            const id = Date.now();
            res.json({ id, message: 'POST /api/scans/:id/execute to run the scan engine' });
        };
        this.executeScan = async (req, res) => {
            const { id } = req.params;
            const { categories, includeCheckIds, name, scanEngine: scanEngineBody, serverName: serverNameBody } = req.body;
            const scanId = parseInt(id, 10) || Date.now();
            const { scanEngine, ldapEngine: ldapEnginePs, launchViaCmd } = (0, scanEngineMapping_1.scanMetaSidecarFromApi)(scanEngineBody);
            const serverName = typeof serverNameBody === 'string' && serverNameBody.trim() ? serverNameBody.trim() : undefined;
            logger_1.logger.info(`Starting scan ${scanId} scanEngine=${scanEngine} ldapEngine=${ldapEnginePs} server=${serverName ?? '(default)'} categories: ${categories?.length || 0}, checkIds: ${includeCheckIds?.length || 0}`);
            (0, websocket_1.broadcastScanUpdate)(scanId, {
                status: 'running',
                message: 'Initializing Security Assessment Engine...',
                progress: 0
            });
            const rootDir = (0, repoRoot_1.getRepoRoot)();
            const scriptPath = path_1.default.join(rootDir, 'Invoke-ADSuiteScan.ps1');
            const checksJsonPath = (0, catalogPaths_1.resolveChecksJsonPath)(rootDir);
            const checksOverridesPath = (0, catalogPaths_1.resolveChecksOverridesPath)(rootDir);
            const outputDir = path_1.default.join(rootDir, 'out', `scan-${scanId}`);
            if (!fs_1.default.existsSync(scriptPath)) {
                logger_1.logger.error(`Scan script not found at: ${scriptPath}`);
                return res.status(500).json({ error: `Scan engine script not found at ${scriptPath}` });
            }
            if (!fs_1.default.existsSync(checksJsonPath)) {
                logger_1.logger.error(`Checks catalog not found at: ${checksJsonPath}`);
                return res.status(500).json({ error: `Checks catalog not found at ${checksJsonPath}` });
            }
            const overridesEnv = process.env.AD_SUITE_CHECKS_OVERRIDES || process.env.CHECKS_OVERRIDES_PATH;
            if (overridesEnv && !checksOverridesPath) {
                const attempted = path_1.default.isAbsolute(overridesEnv)
                    ? overridesEnv
                    : path_1.default.join(rootDir, overridesEnv);
                logger_1.logger.warn(`Checks overrides env set but file not found: ${attempted}`);
            }
            const settings = await settingsService_1.settingsService.getSettings();
            try {
                await promises_1.default.mkdir(outputDir, { recursive: true });
                const metaSidecar = {
                    name: name || `Scan ${scanId}`,
                    scanId,
                    startedAt: new Date().toISOString(),
                    categories: categories || [],
                    includeCheckIdsCount: includeCheckIds?.length ?? 0,
                    checksJsonPath,
                    checksOverridesPath: checksOverridesPath ?? null,
                    scanEngine,
                    ldapEngine: ldapEnginePs,
                    serverName: serverName ?? null,
                    launchViaCmd
                };
                await promises_1.default.writeFile(path_1.default.join(outputDir, 'scan.meta.json'), JSON.stringify(metaSidecar, null, 2), 'utf-8');
            }
            catch (e) {
                logger_1.logger.warn(`Could not write scan.meta.json: ${e}`);
            }
            const args = [];
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
                }
                else {
                    logger_1.logger.info(`Large check count (${includeCheckIds.length}), skipping individual -IncludeCheckId to avoid CLI limits.`);
                }
            }
            args.push('-LdapEngine', ldapEnginePs);
            if (serverName) {
                args.push('-ServerName', serverName);
            }
            const csharpRunnerEnv = process.env.AD_SUITE_CSHARP_RUNNER?.trim();
            if (ldapEnginePs === 'Csharp' && csharpRunnerEnv) {
                args.push('-CsharpRunnerPath', csharpRunnerEnv);
            }
            const useCmdLauncher = launchViaCmd;
            const spawnMsg = useCmdLauncher
                ? `cmd.exe /c powershell.exe ${args.join(' ')}`
                : `powershell.exe ${args.join(' ')}`;
            logger_1.logger.info(`Spawn: ${spawnMsg}`);
            const ps = useCmdLauncher ? (0, child_process_1.spawn)('cmd.exe', ['/c', 'powershell.exe', ...args]) : (0, child_process_1.spawn)('powershell.exe', args);
            let errorOutput = '';
            ps.stdout.on('data', (data) => {
                const lines = data.toString();
                const lastLine = lines.trim().split('\n').pop();
                (0, websocket_1.broadcastScanUpdate)(scanId, {
                    status: 'running',
                    message: lastLine || 'Processing...',
                    progress: 50
                });
            });
            ps.stderr.on('data', (data) => {
                const err = data.toString();
                errorOutput += err;
                logger_1.logger.error(`PS Error: ${err}`);
            });
            ps.on('close', (code) => {
                logger_1.logger.info(`Scan ${scanId} exited with code ${code}`);
                if (code !== 0) {
                    logger_1.logger.error(`Scan failed. Stderr: ${errorOutput}`);
                }
                const resultPath = path_1.default.join(outputDir, 'scan-results.json');
                let summary = {};
                if (code === 0 && fs_1.default.existsSync(resultPath)) {
                    try {
                        const raw = fs_1.default.readFileSync(resultPath, 'utf-8');
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
                    }
                    catch (e) {
                        logger_1.logger.warn(`Could not parse scan-results.json: ${e}`);
                    }
                }
                (0, websocket_1.broadcastScanUpdate)(scanId, {
                    status: code === 0 ? 'completed' : 'failed',
                    message: code === 0
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
                outputDir,
                scanEngine,
                ldapEngine: ldapEnginePs,
                serverName: serverName ?? null,
                launchViaCmd: useCmdLauncher
            });
        };
        this.stopScan = (_req, res) => {
            res.status(501).json({
                message: 'Scan stop is not implemented (no process registry).'
            });
        };
        this.deleteScan = async (req, res) => {
            try {
                const scans = await scanService_1.ScanService.listAvailableScans();
                const scan = scans.find((s) => s.id === req.params.id || s.filename === req.params.id);
                if (!scan) {
                    return res.status(404).json({ message: 'Scan not found' });
                }
                await promises_1.default.unlink(scan.path);
                const dir = path_1.default.dirname(scan.path);
                const metaPath = path_1.default.join(dir, 'scan.meta.json');
                try {
                    await promises_1.default.unlink(metaPath);
                }
                catch {
                    /* optional */
                }
                res.json({ success: true });
            }
            catch (e) {
                const msg = e instanceof Error ? e.message : 'Delete failed';
                res.status(500).json({ message: msg });
            }
        };
        this.getScanResults = async (req, res) => {
            try {
                const doc = await scanService_1.ScanService.getScanContent(req.params.id);
                if (!doc) {
                    return res.status(404).json({ message: 'Scan not found' });
                }
                res.json(doc);
            }
            catch (e) {
                const msg = e instanceof Error ? e.message : 'Failed to load results';
                res.status(500).json({ message: msg });
            }
        };
        this.getScanFindings = async (req, res) => {
            try {
                const doc = await scanService_1.ScanService.getScanContent(req.params.id);
                if (!doc) {
                    return res.status(404).json({ message: 'Scan not found' });
                }
                const findings = (0, scanDocumentResults_1.extractResultsArrayFromScanDocument)(doc);
                res.json({ findings });
            }
            catch (e) {
                res.status(404).json({ message: 'Scan not found or parsing failed' });
            }
        };
        this.exportScan = async (req, res) => {
            try {
                const { id, format } = req.params;
                const scans = await scanService_1.ScanService.listAvailableScans();
                const scan = scans.find((s) => s.id === id || s.filename === id);
                if (!scan) {
                    return res.status(404).json({ message: 'Scan not found' });
                }
                if (format === 'csv') {
                    const raw = await promises_1.default.readFile(scan.path, 'utf-8');
                    const doc = JSON.parse(raw.replace(/^\uFEFF/, ''));
                    const csv = (0, scanExportCsv_1.findingsToCsv)(doc);
                    res.setHeader('Content-Type', 'text/csv; charset=utf-8');
                    res.setHeader('Content-Disposition', `attachment; filename="AD_Suite_Scan_${id}.csv"`);
                    return res.send(csv);
                }
                const ext = format === 'json' ? 'json' : 'json';
                res.download(scan.path, `AD_Suite_Scan_${id}.${ext}`);
            }
            catch (e) {
                const msg = e instanceof Error ? e.message : 'Export failed';
                res.status(500).json({ message: msg });
            }
        };
    }
}
exports.ScanController = ScanController;
//# sourceMappingURL=scanController.js.map