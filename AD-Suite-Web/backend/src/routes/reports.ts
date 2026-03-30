import express from 'express';
import fs from 'fs/promises';
import archiver from 'archiver';
import { authenticate } from '../middleware/auth';
import { ScanService } from '../services/scanService';
import { findingsToCsv } from '../utils/scanExportCsv';

const router = express.Router();
router.use(authenticate);

// GET /api/reports/scans
router.get('/scans', async (req, res, next) => {
    try {
        const scans = await ScanService.listAvailableScans();
        res.json(scans);
    } catch (error) {
        next(error);
    }
});

// GET /api/reports/scans/:id/findings
router.get('/scans/:id/findings', async (req, res, next) => {
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
router.post('/export', async (req, res, next) => {
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
router.delete('/scans', async (req, res, next) => {
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
router.get('/export/:id/:format', async (req, res, next) => {
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
