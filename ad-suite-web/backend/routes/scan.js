const express = require('express');
const router = express.Router();
const { spawn } = require('child_process');
const { v4: uuidv4 } = require('uuid');
const executor = require('../services/executor');
const db = require('../services/db');

// POST /api/scan/run - Start a new scan
router.post('/run', async (req, res) => {
  try {
    const { suiteRoot, checkIds, engine, domain = null, serverIp = null } = req.body;

    if (!suiteRoot || !checkIds || !Array.isArray(checkIds) || !engine) {
      return res.status(400).json({
        error: 'Missing required parameters: suiteRoot, checkIds, engine'
      });
    }

    if (checkIds.length === 0) {
      return res.status(400).json({ error: 'No checks selected' });
    }

    // Check if scan is already running
    if (executor.isScanning()) {
      return res.status(409).json({ error: 'A scan is already running' });
    }

    const scanId = uuidv4();
    const timestamp = Date.now();

    // Create scan record
    db.createScan({
      id: scanId,
      timestamp,
      engine,
      suiteRoot,
      domain,
      serverIp,
      checkIds,
      checkCount: checkIds.length,
      status: 'running'
    });

    // Run scan asynchronously
    setImmediate(() => {
      executor.runScan({ scanId, checkIds, engine, suiteRoot, domain, serverIp })
        .catch(err => {
          console.error('Scan execution error:', err);
          db.updateScanStatus(scanId, 'error');
        });
    });

    res.json({ scanId });

  } catch (error) {
    console.error('Error starting scan:', error);
    res.status(500).json({ error: error.message });
  }
});

// GET /api/scan/stream/:scanId - SSE stream for scan progress
router.get('/stream/:scanId', (req, res) => {
  const { scanId } = req.params;

  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');
  res.setHeader('X-Accel-Buffering', 'no');
  res.flushHeaders();

  // Register SSE client
  executor.registerSSEClient(scanId, res);

  // If scan is already complete, send final data
  const scan = db.getScan(scanId);
  if (scan && scan.status === 'completed') {
    const findings = db.getScanFindings(scanId);
    const summary = {
      total: findings.length,
      duration: `${Math.floor(scan.duration_ms / 1000)}s`,
      bySeverity: db.getSeveritySummaryForScan(scanId)
    };
    res.write(`data: ${JSON.stringify({ type: 'complete', summary })}\n\n`);
    res.write(`data: ${JSON.stringify({ type: 'done' })}\n\n`);
    return res.end();
  }

  req.on('close', () => {
    executor.unregisterSSEClient(scanId);
  });
});

// GET /api/scan/status/:scanId - Get scan status
router.get('/status/:scanId', (req, res) => {
  try {
    const { scanId } = req.params;
    const scan = db.getScan(scanId);

    if (!scan) {
      return res.status(404).json({ error: 'Scan not found' });
    }

    res.json({
      status: scan.status,
      progress: null,
      findingCount: scan.finding_count
    });

  } catch (error) {
    console.error('Error getting scan status:', error);
    res.status(500).json({ error: error.message });
  }
});

// POST /api/scan/abort/:scanId - Abort a running scan
router.post('/abort/:scanId', (req, res) => {
  try {
    const { scanId } = req.params;

    executor.abortActiveScan();
    db.updateScanStatus(scanId, 'aborted');

    res.json({ aborted: true });

  } catch (error) {
    console.error('Error aborting scan:', error);
    res.status(500).json({ error: error.message });
  }
});

// GET /api/scan/recent - Get recent scans
router.get('/recent', (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 20;
    const scans = db.getRecentScans(limit);
    res.json(scans);

  } catch (error) {
    console.error('Error getting recent scans:', error);
    res.status(500).json({ error: error.message });
  }
});

// GET /api/scan/:scanId/findings - Get findings for a specific scan
router.get('/:scanId/findings', (req, res) => {
  try {
    const { scanId } = req.params;
    const offset = parseInt(req.query.offset) || 0;
    const limit = parseInt(req.query.limit) || 1000;

    const findings = db.getScanFindings(scanId, offset, limit);

    res.json({ findings });

  } catch (error) {
    console.error('Error getting findings:', error);
    res.status(500).json({ error: error.message });
  }
});

// POST /api/scan/validate-target - Test LDAP connectivity to target
router.post('/validate-target', async (req, res) => {
  try {
    const { domain, serverIp } = req.body;

    const target = serverIp || domain || '';
    const ldapUrl = target ? `LDAP://${target}/RootDSE` : `LDAP://RootDSE`;

    const psCommand = `
      try {
        $root = [ADSI]'${ldapUrl}'
        $nc = $root.defaultNamingContext.ToString()
        if ($nc) { 
          Write-Output "OK:$nc" 
        } else { 
          Write-Error "Empty NC" 
        }
      } catch {
        Write-Error "FAIL:$($_.Exception.Message)"
      }
    `.trim();

    const powershell = spawn('powershell.exe', [
      '-ExecutionPolicy', 'Bypass',
      '-NonInteractive',
      '-NoProfile',
      '-Command', psCommand
    ], { shell: false, timeout: 10000 });

    let output = '';
    let error = '';

    powershell.stdout.on('data', (data) => {
      output += data.toString();
    });

    powershell.stderr.on('data', (data) => {
      error += data.toString();
    });

    powershell.on('close', (code) => {
      if (code === 0 && output.includes('OK:')) {
        const match = output.match(/OK:([^\r\n]+)/);
        if (match) {
          res.json({
            valid: true,
            domainNC: match[1].trim(),
            message: 'Connection successful'
          });
        } else {
          res.json({
            valid: false,
            error: 'Unable to extract domain NC from response'
          });
        }
      } else {
        const errorMatch = error.match(/FAIL:([^\r\n]+)/);
        const errorMessage = errorMatch ? errorMatch[1].trim() : error || `Process exited with code ${code}`;

        res.json({
          valid: false,
          error: errorMessage
        });
      }
    });

    powershell.on('error', (err) => {
      console.error('PowerShell process error:', err);
      res.status(500).json({
        valid: false,
        error: err.message
      });
    });

  } catch (error) {
    console.error('Validation error:', error);
    res.status(500).json({
      valid: false,
      error: error.message
    });
  }
});

// POST /api/scan/discover-checks - Discover available checks from suite root
router.post('/discover-checks', async (req, res) => {
  try {
    const { suiteRoot } = req.body;

    if (!suiteRoot) {
      return res.status(400).json({ error: 'suiteRoot is required' });
    }

    const result = await executor.discoverChecks(suiteRoot);
    res.json(result);
  } catch (error) {
    console.error('Error discovering checks:', error);
    res.status(500).json({
      valid: false,
      error: error.message,
      checks: []
    });
  }
});

// GET /api/scan/diagnose - Run a single check with full diagnostics
router.get('/diagnose', async (req, res) => {
  const {
    suiteRoot,
    category = 'Authentication',
    checkId = 'AUTH-001',
    engine = 'adsi',
    domain,
    targetServer,
  } = req.query;

  if (!suiteRoot) {
    return res.status(400).json({ error: 'suiteRoot query param is required' });
  }

  try {
    const result = await executor.runCheck(
      suiteRoot, category, checkId, checkId, engine,
      { domain, targetServer, timeoutMs: 30000 }
    );

    res.json({
      // Path resolution
      scriptPath: result.scriptPath,
      scriptFound: !!result.scriptPath,

      // Execution result
      exitCode: result.exitCode,
      durationMs: result.durationMs,
      error: result.error,

      // Raw output (first 5000 chars)
      stdoutRaw: (result.stdout || '').slice(0, 5000),
      stderrRaw: (result.stderr || '').slice(0, 2000),
      stdoutLength: (result.stdout || '').length,

      // Parsed findings
      findingCount: result.findings.length,
      findings: result.findings.slice(0, 20), // first 20

      // Diagnosis
      diagnosis: executor.diagnoseProblem(result),
    });
  } catch (err) {
    res.status(500).json({ error: err.message, stack: err.stack });
  }
});

module.exports = router;
