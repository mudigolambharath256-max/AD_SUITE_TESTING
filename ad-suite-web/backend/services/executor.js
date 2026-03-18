const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');
const os = require('os');
const { v4: uuidv4 } = require('uuid');
const db = require('./db');
const PDFDocument = require('pdfkit');

// Module-level scan lock
let _activeScanProcess = null;
let _activeScanId = null;

// SSE client registry
const sseClients = new Map();

// Engine file mapping
const ENGINE_FILE_MAP = {
  adsi: 'adsi.ps1',
  powershell: 'powershell.ps1',
  csharp: 'csharp.cs',
  cmd: 'cmd.bat',
  combined: 'combined_multiengine.ps1',
};

const REPORTS_DIR = path.join(__dirname, '..', 'reports');

// Ensure reports directory exists
if (!fs.existsSync(REPORTS_DIR)) {
  fs.mkdirSync(REPORTS_DIR, { recursive: true });
}

function isScanning() {
  return _activeScanId !== null;
}

function abortActiveScan() {
  if (_activeScanProcess) {
    _activeScanProcess.kill('SIGTERM');
    _activeScanProcess = null;
    _activeScanId = null;
  }
}

function emitSSE(scanId, event) {
  const client = sseClients.get(scanId);
  if (client && !client.writableEnded) {
    client.write(`data: ${JSON.stringify(event)}\n\n`);
  }
}

function registerSSEClient(scanId, res) {
  sseClients.set(scanId, res);
}

function unregisterSSEClient(scanId) {
  sseClients.delete(scanId);
}

// FQDN to DN conversion
function fqdnToDN(fqdn) {
  return fqdn.split('.').map(part => `DC=${part}`).join(',');
}

// Script path resolution with nested folder support
function resolveScriptPath(suiteRoot, checkId, engine) {
  const engineFile = ENGINE_FILE_MAP[engine];
  if (!engineFile) {
    throw new Error(`Unknown engine: ${engine}`);
  }

  console.log(`[resolveScriptPath] Looking for ${checkId} with engine ${engine} (file: ${engineFile}) in ${suiteRoot}`);

  // Walk all category folders
  for (const cat of fs.readdirSync(suiteRoot)) {
    const catPath = path.join(suiteRoot, cat);
    if (!fs.existsSync(catPath) || !fs.statSync(catPath).isDirectory()) continue;

    // Walk all check folders in this category
    for (const checkFolder of fs.readdirSync(catPath)) {
      // Match by check ID prefix
      if (!checkFolder.startsWith(checkId + '_') && !checkFolder.startsWith(checkId)) continue;

      console.log(`[resolveScriptPath] Found matching folder: ${checkFolder} in category ${cat}`);

      const checkPath = path.join(catPath, checkFolder);
      if (!fs.statSync(checkPath).isDirectory()) continue;

      // Try direct script
      const directScript = path.join(checkPath, engineFile);
      console.log(`[resolveScriptPath] Checking direct script: ${directScript}`);
      if (fs.existsSync(directScript)) {
        console.log(`[resolveScriptPath] ✓ Found script: ${directScript}`);
        return { scriptPath: directScript, category: cat };
      }

      // Try one level deeper (Domain_Controllers nesting)
      try {
        for (const sub of fs.readdirSync(checkPath)) {
          const subPath = path.join(checkPath, sub);
          if (!fs.statSync(subPath).isDirectory()) continue;

          const nestedScript = path.join(subPath, engineFile);
          console.log(`[resolveScriptPath] Checking nested script: ${nestedScript}`);
          if (fs.existsSync(nestedScript)) {
            console.log(`[resolveScriptPath] ✓ Found nested script: ${nestedScript}`);
            return { scriptPath: nestedScript, category: cat };
          }
        }
      } catch (e) {
        // Ignore read errors in subdirectories
      }
    }
  }

  console.log(`[resolveScriptPath] ✗ No script found for ${checkId} with engine ${engine}`);
  return null;
}

// Build PowerShell command
function buildPsCommand(scriptPath, engine) {
  const escapedPath = scriptPath.replace(/'/g, "''");

  // For combined engine, capture return value
  // For other engines, redirect output to null and capture $output variable
  // This prevents Format-List from interfering with JSON serialization
  const wrapper = engine === 'combined'
    ? `$r = & '${escapedPath}'; $r | ConvertTo-Json -Depth 10 -Compress`
    : `& '${escapedPath}' | Out-Null; if (Get-Variable -Name output -ErrorAction SilentlyContinue) { $output | ConvertTo-Json -Depth 10 -Compress } else { @() | ConvertTo-Json }`;

  return {
    cmd: 'powershell.exe',
    args: [
      '-ExecutionPolicy', 'Bypass',
      '-NonInteractive',
      '-NoProfile',
      '-OutputFormat', 'Text',
      '-Command', wrapper
    ]
  };
}

// Domain/IP injection (temp file approach)
async function injectAndWriteTempScript(scriptPath, domain, serverIp, engine) {
  // Skip injection for CMD and C#
  if (engine === 'cmd' || engine === 'csharp') {
    return scriptPath;
  }

  const content = fs.readFileSync(scriptPath, 'utf8');

  // Build connection preamble
  let preamble = '';
  if (serverIp && domain) {
    const dn = fqdnToDN(domain);
    preamble = `$root = [ADSI]'LDAP://${serverIp}/${dn}'\n$domainNC = '${dn}'\n`;
  } else if (serverIp) {
    preamble = `$root = [ADSI]'LDAP://${serverIp}/RootDSE'\n$domainNC = $root.defaultNamingContext.ToString()\n`;
  } else if (domain) {
    const dn = fqdnToDN(domain);
    preamble = `$root = [ADSI]'LDAP://${dn}'\n$domainNC = '${dn}'\n`;
  }

  if (!preamble) return scriptPath;

  // Replace the RootDSE line
  const modifiedContent = content.replace(
    /\$root\s*=\s*\[ADSI\]['"]LDAP:\/\/RootDSE['"]\s*\n\s*\$domainNC\s*=\s*\$root\.defaultNamingContext\.ToString\(\)/g,
    preamble.trim()
  );

  // Write to temp file
  const tmpPath = path.join(os.tmpdir(), `adsuite_${uuidv4()}.ps1`);
  fs.writeFileSync(tmpPath, modifiedContent, 'utf8');
  return tmpPath;
}

// Parse script output
function parseScriptOutput(stdout, checkId, category) {
  const clean = stdout.replace(/^\uFEFF/, '').trim();
  if (!clean) return [];

  // Extract JSON block
  const jsonStart = clean.search(/[\[{]/);
  if (jsonStart === -1) {
    // No JSON — store raw stdout
    return [{
      checkId,
      category,
      checkName: checkId,
      severity: 'INFO',
      riskScore: 0,
      mitre: '',
      name: 'Script output (non-JSON)',
      distinguishedName: '',
      detailsJson: JSON.stringify({ raw: clean.slice(0, 2000) })
    }];
  }

  const jsonStr = clean.slice(jsonStart);
  const lastClose = Math.max(jsonStr.lastIndexOf(']'), jsonStr.lastIndexOf('}'));
  const jsonBlock = jsonStr.slice(0, lastClose + 1);

  let parsed;
  try {
    parsed = JSON.parse(jsonBlock);
  } catch (e) {
    // Try NDJSON
    try {
      parsed = jsonStr.split('\n')
        .filter(l => l.trim().startsWith('{'))
        .map(l => JSON.parse(l.trim()));
    } catch {
      return [{
        checkId,
        category,
        checkName: checkId,
        severity: 'INFO',
        riskScore: 0,
        mitre: '',
        name: 'Parse error — raw output stored',
        distinguishedName: '',
        detailsJson: JSON.stringify({ raw: clean.slice(0, 2000), parseError: e.message })
      }];
    }
  }

  const items = Array.isArray(parsed) ? parsed : [parsed];
  return items.map(item => ({
    checkId: item.CheckID || checkId,
    category,
    checkName: item.CheckName || item.Label || checkId,
    severity: normalizeSeverity(item.Severity || item.severity || ''),
    riskScore: parseInt(item.RiskScore || item.riskScore || 0) || 0,
    mitre: item.MITRE || item.mitre || '',
    name: item.Name || item.name || item.SamAccountName || '',
    distinguishedName: item.DistinguishedName || item.distinguishedName || '',
    detailsJson: JSON.stringify(item)
  }));
}

function normalizeSeverity(s) {
  const map = {
    critical: 'CRITICAL',
    high: 'HIGH',
    medium: 'MEDIUM',
    low: 'LOW',
    info: 'INFO'
  };
  return map[s.toLowerCase()] || 'INFO';
}

// C# compilation
async function compileCSharp(scriptPath) {
  const cscPath = await detectCsc();
  if (!cscPath) {
    throw new Error('csc.exe not found. Install .NET Framework 4.x or set path in Settings.');
  }

  const exePath = scriptPath.replace(/\.cs$/, '.exe');

  // Skip if already compiled and newer
  if (fs.existsSync(exePath) &&
    fs.statSync(exePath).mtimeMs > fs.statSync(scriptPath).mtimeMs) {
    return exePath;
  }

  return new Promise((resolve, reject) => {
    const proc = spawn(cscPath, [
      '/nologo',
      '/reference:System.DirectoryServices.dll',
      '/reference:System.DirectoryServices.AccountManagement.dll',
      `/out:${exePath}`,
      scriptPath
    ], { shell: false, encoding: 'utf8' });

    let stderr = '';
    proc.stderr.on('data', d => { stderr += d; });
    proc.on('close', code => {
      if (code === 0) resolve(exePath);
      else reject(new Error(`Compilation failed:\n${stderr}`));
    });
  });
}

function detectCsc() {
  const candidates = [
    'C:\\Windows\\Microsoft.NET\\Framework64\\v4.0.30319\\csc.exe',
    'C:\\Windows\\Microsoft.NET\\Framework\\v4.0.30319\\csc.exe',
    'C:\\Program Files\\dotnet\\dotnet.exe'
  ];

  for (const p of candidates) {
    if (fs.existsSync(p)) return Promise.resolve(p);
  }
  return Promise.resolve(null);
}

// Save raw check output
function saveRawCheckOutput(scanId, checkId, rawStdout, parsedFindings) {
  const perCheckDir = path.join(REPORTS_DIR, scanId, 'per_check');
  fs.mkdirSync(perCheckDir, { recursive: true });
  fs.writeFileSync(
    path.join(perCheckDir, `${checkId}_raw.json`),
    JSON.stringify({ checkId, stdout: rawStdout, findings: parsedFindings }, null, 2),
    'utf8'
  );
}

// Build summary
function buildSummary(findings, duration) {
  const bySeverity = { CRITICAL: 0, HIGH: 0, MEDIUM: 0, LOW: 0, INFO: 0 };
  findings.forEach(f => {
    bySeverity[f.severity] = (bySeverity[f.severity] || 0) + 1;
  });

  return {
    total: findings.length,
    duration: `${Math.floor(duration / 1000)}s`,
    bySeverity
  };
}

// Write export files
async function writeExportFiles(scanId, findings) {
  const scanDir = path.join(REPORTS_DIR, scanId);
  fs.mkdirSync(scanDir, { recursive: true });
  fs.mkdirSync(path.join(scanDir, 'per_check'), { recursive: true });

  // JSON
  fs.writeFileSync(
    path.join(scanDir, 'findings.json'),
    JSON.stringify(findings, null, 2),
    'utf8'
  );

  // CSV
  const { stringify } = require('csv-stringify/sync');
  if (findings.length > 0) {
    const csvContent = stringify(findings, {
      header: true,
      columns: Object.keys(findings[0])
    });
    fs.writeFileSync(path.join(scanDir, 'findings.csv'), csvContent, 'utf8');
  } else {
    fs.writeFileSync(path.join(scanDir, 'findings.csv'), 'No findings\n', 'utf8');
  }

  // PDF
  await writePdf(scanDir, scanId, findings);
}

// PDF generation
async function writePdf(scanDir, scanId, findings) {
  return new Promise((resolve) => {
    const doc = new PDFDocument({ margin: 50, size: 'A4' });
    const outPath = path.join(scanDir, 'report.pdf');
    const stream = fs.createWriteStream(outPath);
    doc.pipe(stream);

    // Cover page
    doc.fontSize(22).fillColor('#d4a96a').text('AD Security Suite', { align: 'center' });
    doc.fontSize(16).fillColor('#333').text('Security Scan Report', { align: 'center' });
    doc.moveDown();
    doc.fontSize(11).fillColor('#555');
    doc.text(`Scan ID:  ${scanId}`);
    doc.text(`Generated: ${new Date().toISOString()}`);
    doc.text(`Total Findings: ${findings.length}`);

    const bySev = { CRITICAL: 0, HIGH: 0, MEDIUM: 0, LOW: 0, INFO: 0 };
    findings.forEach(f => { bySev[f.severity] = (bySev[f.severity] || 0) + 1; });
    doc.text(`Severity: CRITICAL ${bySev.CRITICAL} | HIGH ${bySev.HIGH} | MEDIUM ${bySev.MEDIUM} | LOW ${bySev.LOW} | INFO ${bySev.INFO}`);

    doc.addPage();

    // Findings by category
    const byCategory = {};
    findings.forEach(f => {
      if (!byCategory[f.category]) byCategory[f.category] = [];
      byCategory[f.category].push(f);
    });

    for (const [cat, catFindings] of Object.entries(byCategory)) {
      doc.fontSize(14).fillColor('#d4a96a').text(cat.replace(/_/g, ' '));
      doc.moveDown(0.3);

      catFindings.forEach(f => {
        doc.fontSize(9).fillColor('#222').text(`[${f.severity}] ${f.checkName}  —  ${f.name || 'N/A'}`, { continued: false });
        doc.fontSize(8).fillColor('#666').text(`  DN: ${f.distinguishedName || '—'}  |  MITRE: ${f.mitre || '—'}`);
        doc.moveDown(0.2);
      });

      doc.moveDown(0.5);
      if (doc.y > 700) doc.addPage();
    }

    doc.end();
    stream.on('finish', resolve);
  });
}

// Main scan execution
async function runScan({ scanId, checkIds, engine, suiteRoot, domain, serverIp }) {
  const startTime = Date.now();

  // Set active scan ID
  _activeScanId = scanId;

  console.log(`[SCAN ${scanId}] Starting scan with ${checkIds.length} checks using ${engine} engine`);
  console.log(`[SCAN ${scanId}] Suite Root: ${suiteRoot}`);
  console.log(`[SCAN ${scanId}] Check IDs: ${checkIds.join(', ')}`);

  db.updateScanStatus(scanId, 'running');

  let completedCount = 0;
  const total = checkIds.length;
  const allFindings = [];

  console.log(`[SCAN ${scanId}] About to process ${checkIds.length} checks`);
  console.log(`[SCAN ${scanId}] isScanning(): ${isScanning()}`);

  for (const checkId of checkIds) {
    console.log(`[SCAN ${scanId}] Loop iteration for ${checkId}`);
    if (!isScanning()) {
      console.log(`[SCAN ${scanId}] Scan aborted, isScanning() = false`);
      break; // aborted
    }

    console.log(`[SCAN ${scanId}] Processing check ${checkId} with engine ${engine}`);
    const resolved = resolveScriptPath(suiteRoot, checkId, engine);
    if (!resolved) {
      console.log(`[SCAN ${scanId}] Script not found for check ${checkId} with engine ${engine}`);
      emitSSE(scanId, {
        type: 'log',
        line: `[SKIP] ${checkId}: script not found for engine '${engine}'`
      });
      completedCount++;
      continue;
    }

    console.log(`[SCAN ${scanId}] Resolved ${checkId} to: ${resolved.scriptPath}`);
    const { scriptPath, category } = resolved;

    emitSSE(scanId, {
      type: 'progress',
      progress: {
        current: completedCount,
        total,
        currentCheckId: checkId,
        currentCheckName: checkId
      }
    });

    emitSSE(scanId, { type: 'log', line: `\n[${checkId}] Starting — ${scriptPath}` });

    // Apply domain/IP injection if specified
    const execScriptPath = (domain || serverIp)
      ? await injectAndWriteTempScript(scriptPath, domain, serverIp, engine)
      : scriptPath;

    const { cmd, args } = engine === 'cmd'
      ? { cmd: 'cmd.exe', args: ['/c', execScriptPath] }
      : buildPsCommand(execScriptPath, engine);

    console.log(`[SCAN ${scanId}] Executing: ${cmd} ${args.join(' ')}`);

    let stdoutBuffer = '';
    let stderrBuffer = '';

    await new Promise((resolve) => {
      const proc = spawn(cmd, args, {
        shell: false,
        timeout: 120000,
        encoding: 'utf8'
      });

      _activeScanProcess = proc;

      proc.stdout.on('data', (chunk) => {
        const text = chunk.toString('utf8');
        stdoutBuffer += text;
        text.split('\n').filter(l => l.trim()).forEach(line => {
          emitSSE(scanId, { type: 'log', line });
        });
      });

      proc.stderr.on('data', (chunk) => {
        const text = chunk.toString('utf8');
        stderrBuffer += text;
        text.split('\n').filter(l => l.trim()).forEach(line => {
          emitSSE(scanId, { type: 'log', line: `[ERR] ${line}` });
        });
      });

      proc.on('close', (code) => {
        _activeScanProcess = null;

        // Clean up temp file
        if (execScriptPath !== scriptPath) {
          try { fs.unlinkSync(execScriptPath); } catch { }
        }

        // Parse stdout
        const findings = parseScriptOutput(stdoutBuffer, checkId, category);
        allFindings.push(...findings);

        // Store findings in DB
        findings.forEach(f => db.insertFinding({ ...f, scanId, id: uuidv4() }));

        // Save raw per-check JSON
        saveRawCheckOutput(scanId, checkId, stdoutBuffer, findings);

        emitSSE(scanId, {
          type: 'progress',
          progress: {
            current: completedCount + 1,
            total,
            currentCheckId: checkId,
            currentCheckName: checkId
          }
        });

        emitSSE(scanId, {
          type: 'log',
          line: `[${checkId}] Done — ${findings.length} findings (exit ${code})`
        });

        completedCount++;
        resolve();
      });

      proc.on('error', (err) => {
        _activeScanProcess = null;
        emitSSE(scanId, {
          type: 'log',
          line: `[${checkId}] Process error: ${err.message}`
        });
        completedCount++;
        resolve();
      });
    });
  }

  const duration = Date.now() - startTime;
  const summary = buildSummary(allFindings, duration);

  console.log(`[SCAN ${scanId}] Scan complete: ${allFindings.length} findings in ${duration}ms`);

  db.finalizeScan(scanId, allFindings.length, duration, 'completed');

  // Write final export files
  await writeExportFiles(scanId, allFindings);

  emitSSE(scanId, { type: 'complete', summary });
  emitSSE(scanId, { type: 'done' });

  _activeScanId = null;
  sseClients.delete(scanId);
}

// Discover checks
async function discoverChecks(suiteRoot) {
  if (!fs.existsSync(suiteRoot)) {
    return { valid: false, error: 'Path does not exist', checks: [] };
  }

  const categories = require('../lib/categories.js').CATEGORIES || require('./../lib/categories.js').CATEGORIES;
  const discoveredChecks = [];

  for (const category of categories) {
    const categoryPath = path.join(suiteRoot, category.id);

    if (!fs.existsSync(categoryPath)) continue;

    try {
      const folders = fs.readdirSync(categoryPath)
        .filter(item => {
          const itemPath = path.join(categoryPath, item);
          return fs.statSync(itemPath).isDirectory();
        });

      for (const folder of folders) {
        const match = folder.match(/^([A-Z]+)-(\d+)/);
        if (match) {
          const checkId = `${match[1]}-${match[2]}`;
          const checkName = folder.substring(checkId.length + 1).replace(/_/g, ' ');

          discoveredChecks.push({
            id: checkId,
            name: checkName,
            category: category.id,
            categoryDisplay: category.display,
            folder: folder
          });
        }
      }
    } catch (error) {
      console.error(`Error reading category ${category.id}:`, error);
    }
  }

  return {
    valid: true,
    checks: discoveredChecks,
    categoriesFound: [...new Set(discoveredChecks.map(c => c.category))].length,
    totalChecks: discoveredChecks.length
  };
}

module.exports = {
  isScanning,
  abortActiveScan,
  runScan,
  discoverChecks,
  resolveScriptPath,
  registerSSEClient,
  unregisterSSEClient,
  writeExportFiles,
  detectCsc,
  REPORTS_DIR
};


// ============================================================================
// DIAGNOSTIC FUNCTIONS (added for scan diagnostics feature)
// ============================================================================

/**
 * Run a single check and return complete diagnostic information.
 * Used by GET /api/scan/diagnose endpoint.
 */
async function runCheck(suiteRoot, category, checkId, checkName, engine, options = {}) {
  const start = Date.now();

  // Resolve script path
  const resolved = resolveScriptPath(suiteRoot, checkId, engine);

  if (!resolved) {
    return {
      checkId,
      checkName,
      category,
      severity: 'UNKNOWN',
      scriptPath: null,
      stdout: '',
      stderr: '',
      exitCode: -1,
      findings: [],
      error: `Script not found: ${category}/${checkId}/${ENGINE_FILE_MAP[engine]}`,
      durationMs: Date.now() - start,
    };
  }

  const { scriptPath } = resolved;

  // Handle C# engine
  if (scriptPath.endsWith('.cs')) {
    try {
      const exePath = await compileCSharp(scriptPath);
      return await runExecutable(exePath, checkId, checkName, category, start);
    } catch (err) {
      return {
        checkId, checkName, category,
        severity: 'UNKNOWN',
        scriptPath, stdout: '', stderr: err.message,
        exitCode: -1, findings: [],
        error: `C# compilation failed: ${err.message}`,
        durationMs: Date.now() - start,
      };
    }
  }

  // Handle CMD engine
  if (scriptPath.endsWith('.bat')) {
    return await runCmdCheck(scriptPath, checkId, checkName, category, start);
  }

  // Handle PowerShell engines
  const { cmd, args } = buildPsCommand(scriptPath, engine);

  return new Promise((resolve) => {
    const proc = spawn(cmd, args, {
      shell: false,
      timeout: options.timeoutMs || 120000,
    });

    let stdout = '';
    let stderr = '';

    proc.stdout.on('data', (chunk) => { stdout += chunk.toString(); });
    proc.stderr.on('data', (chunk) => { stderr += chunk.toString(); });

    proc.on('close', (exitCode) => {
      const durationMs = Date.now() - start;
      const findings = parseScriptOutput(stdout, checkId, category);
      const error = exitCode !== 0 && findings.length === 0
        ? (stderr.trim() || `PowerShell exited with code ${exitCode}`)
        : null;

      // Log stderr for debugging
      if (stderr.trim()) {
        console.log(`[DIAGNOSE] ${checkId} stderr:`, stderr.trim());
      }

      resolve({
        checkId, checkName, category,
        severity: extractSeverityFromPath(scriptPath),
        scriptPath, stdout, stderr, exitCode,
        findings, error, durationMs,
      });
    });

    proc.on('error', (err) => {
      resolve({
        checkId, checkName, category,
        severity: 'UNKNOWN',
        scriptPath, stdout, stderr,
        exitCode: -1,
        findings: [],
        error: `spawn error: ${err.message}`,
        durationMs: Date.now() - start,
      });
    });
  });
}

async function runCmdCheck(scriptPath, checkId, checkName, category, start) {
  return new Promise((resolve) => {
    const proc = spawn('cmd.exe', ['/c', scriptPath], { shell: false });

    let stdout = '';
    let stderr = '';

    proc.stdout.on('data', (chunk) => { stdout += chunk.toString(); });
    proc.stderr.on('data', (chunk) => { stderr += chunk.toString(); });

    proc.on('close', (exitCode) => {
      const findings = parseScriptOutput(stdout, checkId, category);
      resolve({
        checkId, checkName, category,
        severity: 'INFO',
        scriptPath, stdout, stderr, exitCode,
        findings,
        error: exitCode !== 0 ? stderr : null,
        durationMs: Date.now() - start,
      });
    });

    proc.on('error', (err) => {
      resolve({
        checkId, checkName, category,
        severity: 'UNKNOWN',
        scriptPath, stdout, stderr,
        exitCode: -1, findings: [],
        error: err.message,
        durationMs: Date.now() - start,
      });
    });
  });
}

async function runExecutable(exePath, checkId, checkName, category, start) {
  return new Promise((resolve) => {
    const proc = spawn(exePath, [], { shell: false });

    let stdout = '';
    let stderr = '';

    proc.stdout.on('data', (chunk) => { stdout += chunk.toString(); });
    proc.stderr.on('data', (chunk) => { stderr += chunk.toString(); });

    proc.on('close', (exitCode) => {
      const findings = parseScriptOutput(stdout, checkId, category);
      resolve({
        checkId, checkName, category,
        severity: 'INFO',
        scriptPath: exePath, stdout, stderr, exitCode,
        findings,
        error: exitCode !== 0 ? stderr : null,
        durationMs: Date.now() - start,
      });
    });

    proc.on('error', (err) => {
      resolve({
        checkId, checkName, category,
        severity: 'UNKNOWN',
        scriptPath: exePath, stdout, stderr,
        exitCode: -1, findings: [],
        error: err.message,
        durationMs: Date.now() - start,
      });
    });
  });
}

function extractSeverityFromPath(scriptPath) {
  if (!scriptPath) return 'UNKNOWN';
  try {
    const content = fs.readFileSync(scriptPath, { encoding: 'utf8', flag: 'r' }).slice(0, 500);
    const m = content.match(/# Severity:\s*(\w+)/i);
    if (m) return m[1].toUpperCase();
  } catch (_) { }
  return 'UNKNOWN';
}

function diagnoseProblem(result) {
  if (!result.scriptPath) {
    return 'SCRIPT_NOT_FOUND: The executor could not locate the script file. Check that suiteRoot points to AD-Suite-scripts-main/ and that the category/checkId parameters are correct.';
  }
  if (result.exitCode === -1 && result.error?.includes('spawn')) {
    return 'SPAWN_FAILED: powershell.exe could not be started. Verify PowerShell 5.1+ is installed and accessible.';
  }
  if (result.exitCode !== 0 && result.stderr?.includes('UnauthorizedAccess')) {
    return 'PERMISSION_DENIED: The script could not run due to file permissions or execution policy. Check -ExecutionPolicy Bypass is being passed.';
  }
  if (result.stdout?.length === 0 && result.exitCode === 0) {
    return 'EMPTY_OUTPUT_SUCCESS: Script ran successfully but returned no output. Most likely the machine is not domain-joined, or the LDAP query returned no results (which may be correct — no vulnerable objects found).';
  }
  if (result.findings.length === 0 && result.stdout?.includes('@{')) {
    return 'JSON_PARSE_FAILED: Script ran and produced output in @{Property=Value} format, but ConvertTo-Json was not applied. The invocation wrapper needs to be fixed.';
  }
  if (result.findings.length === 0 && result.exitCode === 0) {
    return 'NO_FINDINGS_CLEAN: Script ran without errors and returned no findings. This is correct behaviour — it means no vulnerable objects exist in the domain for this check.';
  }
  if (result.findings.length > 0) {
    return `SUCCESS: Script ran and returned ${result.findings.length} findings.`;
  }
  return `UNKNOWN: exitCode=${result.exitCode}, stdoutLen=${result.stdout?.length || 0}, stderrLen=${result.stderr?.length || 0}`;
}

module.exports = {
  isScanning,
  abortActiveScan,
  runScan,
  discoverChecks,
  resolveScriptPath,
  registerSSEClient,
  unregisterSSEClient,
  writeExportFiles,
  detectCsc,
  REPORTS_DIR,
  // New diagnostic exports
  runCheck,
  diagnoseProblem,
};
