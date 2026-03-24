const express = require('express');
const router = express.Router();
const fs = require('fs');
const path = require('path');
const { v4: uuidv4 } = require('uuid');
const db = require('../services/db');
const executor = require('../services/executor');

const REPORTS_DIR = executor.REPORTS_DIR;

const formatMap = { json: 'findings.json', csv: 'findings.csv', pdf: 'report.pdf' };
const contentTypeMap = { json: 'application/json', csv: 'text/csv', pdf: 'application/pdf' };
const extMap = { json: '.json', csv: '.csv', pdf: '.pdf' };

// POST /api/reports/export - Export scan results
router.post('/export', async (req, res) => {
  try {
    const { scanIds, format } = req.body;

    if (!scanIds || !Array.isArray(scanIds) || !format) {
      return res.status(400).json({ error: 'Missing scanIds or format' });
    }

    if (!['json', 'csv', 'pdf'].includes(format)) {
      return res.status(400).json({ error: 'Invalid format. Must be json, csv, or pdf' });
    }

    // Single scan export
    if (scanIds.length === 1) {
      const filePath = path.join(REPORTS_DIR, scanIds[0], formatMap[format]);

      if (!fs.existsSync(filePath)) {
        return res.status(404).json({ error: 'Report not found. Run the scan first.' });
      }

      // Set proper headers for download
      res.setHeader('Content-Disposition', `attachment; filename="scan_${scanIds[0]}_findings${extMap[format]}"`);
      res.setHeader('Content-Type', contentTypeMap[format]);
      res.setHeader('Content-Length', fs.statSync(filePath).size);
      res.setHeader('Cache-Control', 'no-cache');

      const stream = fs.createReadStream(filePath);
      stream.on('error', (err) => {
        console.error('Stream error:', err);
        if (!res.headersSent) {
          res.status(500).json({ error: 'Failed to read file' });
        }
      });

      stream.pipe(res);
      return;
    }

    // Merge multiple scans
    const allFindings = scanIds.flatMap(id => db.getScanFindings(id));
    const mergedId = 'merged_' + uuidv4();
    const mergedDir = path.join(REPORTS_DIR, mergedId);

    fs.mkdirSync(mergedDir, { recursive: true });

    // Write export files to merged directory
    await executor.writeExportFiles(mergedId, allFindings);

    const mergedFile = path.join(mergedDir, formatMap[format]);

    if (!fs.existsSync(mergedFile)) {
      return res.status(500).json({ error: 'Failed to generate merged report' });
    }

    // Set proper headers for download
    res.setHeader('Content-Disposition', `attachment; filename="merged_report${extMap[format]}"`);
    res.setHeader('Content-Type', contentTypeMap[format]);
    res.setHeader('Content-Length', fs.statSync(mergedFile).size);
    res.setHeader('Cache-Control', 'no-cache');

    const stream = fs.createReadStream(mergedFile);

    stream.on('error', (err) => {
      console.error('Stream error:', err);
      if (!res.headersSent) {
        res.status(500).json({ error: 'Failed to read file' });
      }
    });

    stream.pipe(res);

    res.on('finish', () => {
      // Clean up merged directory after sending
      try {
        fs.rmSync(mergedDir, { recursive: true, force: true });
      } catch (err) {
        console.error('Error cleaning up merged directory:', err);
      }
    });

  } catch (error) {
    console.error('Export error:', error);
    res.status(500).json({ error: error.message });
  }
});

// POST /api/reports/delete - Delete scan reports
router.post('/delete', async (req, res) => {
  try {
    const { scanIds } = req.body;

    if (!scanIds || !Array.isArray(scanIds)) {
      return res.status(400).json({ error: 'Missing scanIds array' });
    }

    let deletedScans = 0;
    let deletedFindings = 0;

    for (const scanId of scanIds) {
      // Delete from database
      const findings = db.getScanFindings(scanId);
      deletedFindings += findings.length;

      // Delete findings
      db.db.prepare('DELETE FROM findings WHERE scan_id = ?').run(scanId);

      // Delete scan
      db.db.prepare('DELETE FROM scans WHERE id = ?').run(scanId);
      deletedScans++;

      // Delete report files
      const reportDir = path.join(REPORTS_DIR, scanId);
      if (fs.existsSync(reportDir)) {
        fs.rmSync(reportDir, { recursive: true, force: true });
      }
    }

    res.json({
      deleted: true,
      scansDeleted: deletedScans,
      findingsDeleted: deletedFindings
    });

  } catch (error) {
    console.error('Delete error:', error);
    res.status(500).json({ error: error.message });
  }
});

// GET /api/dashboard/severity-summary - Get severity summary for latest scan
router.get('/dashboard/severity-summary', (req, res) => {
  try {
    const scanId = db.getLatestCompletedScanId();

    if (!scanId) {
      return res.json({ CRITICAL: 0, HIGH: 0, MEDIUM: 0, LOW: 0, INFO: 0 });
    }

    const summary = db.getSeveritySummaryForScan(scanId);
    res.json(summary);

  } catch (error) {
    console.error('Error getting severity summary:', error);
    res.status(500).json({ error: error.message });
  }
});

// GET /api/dashboard/category-summary - Get category summary for latest scan
router.get('/dashboard/category-summary', (req, res) => {
  try {
    const scanId = db.getLatestCompletedScanId();

    if (!scanId) {
      return res.json([]);
    }

    const rows = db.db.prepare(`
      SELECT category, COUNT(*) as count 
      FROM findings 
      WHERE scan_id = ? 
      GROUP BY category 
      ORDER BY count DESC
    `).all(scanId);

    res.json(rows);

  } catch (error) {
    console.error('Error getting category summary:', error);
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;
