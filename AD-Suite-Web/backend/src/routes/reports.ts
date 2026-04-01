import express from 'express';
import fs from 'fs/promises';
import archiver from 'archiver';
import PDFDocument from 'pdfkit';
import { authenticate, authorize } from '../middleware/auth';
import { auditMutations } from '../middleware/auditMiddleware';
import { ScanService } from '../services/scanService';
import { findingsToCsv } from '../utils/scanExportCsv';

const router = express.Router();
const readRoles = authorize('admin', 'analyst', 'viewer');
const writeRoles = authorize('admin', 'analyst');

router.use(authenticate);
router.use(auditMutations);

function buildExecutiveHtml(doc: Record<string, unknown>): string {
    const meta = (doc.meta || doc.Meta || {}) as Record<string, unknown>;
    const agg = (doc.aggregate || doc.Aggregate || {}) as Record<string, unknown>;
    const score = agg.globalScore ?? agg.GlobalScore ?? '—';
    const band = String(agg.globalRiskBand ?? agg.GlobalRiskBand ?? '');
    const findings = (agg.totalFindings ?? agg.TotalFindings ?? 0) as number;
    const checksRun = (agg.checksRun ?? meta.checksRun ?? '—') as string | number;
    const title = 'AD Suite — Executive summary';
    const esc = (s: string) =>
        s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
    return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1"/>
  <title>${esc(title)}</title>
  <style>
    body { font-family: Segoe UI, system-ui, sans-serif; margin: 2rem; color: #1a1a1a; }
    h1 { font-size: 1.5rem; border-bottom: 2px solid #2563eb; padding-bottom: 0.5rem; }
    .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(160px, 1fr)); gap: 1rem; margin: 1.5rem 0; }
    .card { background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 8px; padding: 1rem; }
    .label { font-size: 0.75rem; text-transform: uppercase; color: #64748b; }
    .value { font-size: 1.5rem; font-weight: 600; }
    p.note { font-size: 0.9rem; color: #475569; max-width: 42rem; }
  </style>
</head>
<body>
  <h1>${esc(title)}</h1>
  <p class="note">Indicative risk band only — not a CVSS score or legal attestation. See docs/HEALTH_SCORE_METHODOLOGY.md.</p>
  <div class="grid">
    <div class="card"><div class="label">Global score</div><div class="value">${esc(String(score))}</div></div>
    <div class="card"><div class="label">Risk band</div><div class="value">${esc(band || '—')}</div></div>
    <div class="card"><div class="label">Total findings</div><div class="value">${esc(String(findings))}</div></div>
    <div class="card"><div class="label">Checks run</div><div class="value">${esc(String(checksRun))}</div></div>
  </div>
  <p style="font-size:0.85rem;color:#94a3b8">Generated ${esc(new Date().toISOString())}</p>
</body>
</html>`;
}

// GET /api/reports/scans
router.get('/scans', readRoles, async (req, res, next) => {
    try {
        const scans = await ScanService.listAvailableScans();
        res.json(scans);
    } catch (error) {
        next(error);
    }
});

// GET /api/reports/executive/:id/html — printable executive summary
router.get('/executive/:id/html', readRoles, async (req, res, next) => {
    try {
        const doc = await ScanService.getScanContent(req.params.id);
        if (!doc) {
            return res.status(404).json({ message: 'Scan not found' });
        }
        res.setHeader('Content-Type', 'text/html; charset=utf-8');
        res.send(buildExecutiveHtml(doc as Record<string, unknown>));
    } catch (error) {
        next(error);
    }
});

// GET /api/reports/pdf/:id — one-page PDF summary
router.get('/pdf/:id', readRoles, async (req, res, next) => {
    try {
        const doc = await ScanService.getScanContent(req.params.id);
        if (!doc) {
            return res.status(404).json({ message: 'Scan not found' });
        }
        const d = doc as Record<string, unknown>;
        const agg = (d.aggregate || d.Aggregate || {}) as Record<string, unknown>;
        const score = agg.globalScore ?? agg.GlobalScore ?? '—';
        const band = String(agg.globalRiskBand ?? '');
        const findings = agg.totalFindings ?? 0;

        res.setHeader('Content-Type', 'application/pdf');
        res.setHeader(
            'Content-Disposition',
            `inline; filename="adsuite-executive-${req.params.id}.pdf"`
        );
        const pdf = new PDFDocument({ margin: 50 });
        pdf.pipe(res);
        pdf.fontSize(18).text('AD Suite — Executive summary', { align: 'center' });
        pdf.moveDown();
        pdf.fontSize(10).text('Indicative score only — see docs/HEALTH_SCORE_METHODOLOGY.md', {
            align: 'center'
        });
        pdf.moveDown(2);
        pdf.fontSize(12).text(`Global score: ${score}`);
        pdf.text(`Risk band: ${band || '—'}`);
        pdf.text(`Total findings: ${findings}`);
        pdf.end();
    } catch (error) {
        next(error);
    }
});

// GET /api/reports/scans/:id/findings
router.get('/scans/:id/findings', readRoles, async (req, res, next) => {
    try {
        const id = req.params.id;
        const doc = await ScanService.getScanContent(id);
        
        if (!doc) {
            return res.status(404).json({ message: 'Scan not found' });
        }

        // Normalize extraction
        let results = doc.results || doc.Results || doc.checks || doc.Checks || [];
        
        let findingsArray = [];
        if (Array.isArray(results)) {
            findingsArray = results;
        } else if (results && Array.isArray(results.checks)) {
             findingsArray = results.checks;
        }

        res.json({ findings: findingsArray });
    } catch (error) {
        res.status(404).json({ message: 'Scan not found or parsing failed' });
    }
});

// POST /api/reports/export — bulk ZIP (json or csv per scan file)
router.post('/export', writeRoles, async (req, res, next) => {
    try {
        const { scanIds, format } = req.body as { scanIds?: string[]; format?: string };
        if (!scanIds || !Array.isArray(scanIds) || scanIds.length === 0) {
            return res.status(400).json({ message: 'scanIds must be a non-empty array' });
        }
        const fmt = (format || 'json').toLowerCase();
        if (fmt !== 'json' && fmt !== 'csv') {
            return res.status(400).json({ message: 'format must be json or csv' });
        }

        const scans = await ScanService.listAvailableScans();
        const selected = scanIds
            .map((id) => scans.find((s) => s.id === id || s.filename === id))
            .filter((s): s is (typeof scans)[0] => Boolean(s));

        if (selected.length === 0) {
            return res.status(404).json({ message: 'No matching scans found' });
        }

        const archive = archiver('zip', { zlib: { level: 9 } });
        archive.on('error', (err) => next(err));
        res.setHeader('Content-Type', 'application/zip');
        res.setHeader(
            'Content-Disposition',
            `attachment; filename="adsuite-export-${Date.now()}.zip"`
        );
        archive.pipe(res);

        for (const s of selected) {
            const raw = await fs.readFile(s.path, 'utf-8');
            if (fmt === 'csv') {
                const doc = JSON.parse(raw.replace(/^\uFEFF/, ''));
                archive.append(findingsToCsv(doc), { name: `${s.id}.csv` });
            } else {
                archive.append(raw, { name: `${s.id}.json` });
            }
        }
        await archive.finalize();
    } catch (error) {
        next(error);
    }
});

// DELETE /api/reports/scans
router.delete('/scans', authorize('admin'), async (req, res, next) => {
    try {
        const { scanIds } = req.body;
        if (!Array.isArray(scanIds)) {
            return res.status(400).json({ message: 'scanIds must be an array' });
        }

        let deletedCount = 0;
        const scans = await ScanService.listAvailableScans();

        await Promise.all(scanIds.map(async id => {
            const scan = scans.find(s => s.id === id || s.filename === id);
            if (!scan) return;
            try {
                await fs.unlink(scan.path);
                deletedCount++;
            } catch (e) {
                console.error(`Failed to delete ${id}`, e);
            }
        }));

        res.json({ success: true, deletedCount, message: `Successfully deleted ${deletedCount} scans.` });
    } catch (error) {
        next(error);
    }
});

// GET /api/reports/export/:id/:format
router.get('/export/:id/:format', readRoles, async (req, res, next) => {
    try {
        const { id, format } = req.params;
        const scans = await ScanService.listAvailableScans();
        const scan = scans.find(s => s.id === id || s.filename === id);

        if (!scan) {
            return res.status(404).json({ message: 'Report file not found' });
        }

        res.download(scan.path, `AD_Suite_Scan_${id}.${format}`);
    } catch (error) {
        next(error);
    }
});

export default router;
