const express = require('express');
const router = express.Router();
const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');
const { v4: uuidv4 } = require('uuid');

const SCRIPT_PATH = path.join(__dirname, '..', 'scripts', 'Parse-ADExplorerSnapshot.ps1');
const UPLOADS_DIR = path.join(__dirname, '..', '..', 'uploads', 'adexplorer');

fs.mkdirSync(UPLOADS_DIR, { recursive: true });

// ── Session state + SSE ────────────────────────────────────────────────────
const sessions = new Map();     // sessionId → { status, lines, outputDir, summary, outputFiles }
const sseClients = new Map();   // sessionId → res

function broadcastSSE(sessionId, event) {
    const client = sseClients.get(sessionId);
    if (client && !client.writableEnded) {
        client.write(`data: ${JSON.stringify(event)}\n\n`);
    }
}

// ── POST /api/integrations/adexplorer/convert ──────────────────────────────
// Body: { snapshotPath: string, convertExePath?: string }
// Starts the PS conversion. Returns sessionId.
// Progress streamed via GET /api/integrations/adexplorer/stream/:sessionId
router.post('/convert', (req, res) => {
    const { snapshotPath, convertExePath } = req.body;

    if (!snapshotPath || !fs.existsSync(snapshotPath)) {
        return res.status(400).json({ error: 'Snapshot file not found: ' + snapshotPath });
    }

    const sessionId = uuidv4();
    const outputDir = path.join(UPLOADS_DIR, sessionId);
    fs.mkdirSync(outputDir, { recursive: true });

    // Store session state
    sessions.set(sessionId, { status: 'running', lines: [], outputDir });

    // Build PS command
    const psArgs = [
        '-ExecutionPolicy', 'Bypass',
        '-NonInteractive',
        '-NoProfile',
        '-File', SCRIPT_PATH,
        '-SnapshotPath', snapshotPath,
        '-OutputDir', outputDir,
    ];
    if (convertExePath) psArgs.push('-ConvertExePath', convertExePath);

    const proc = spawn('powershell.exe', psArgs, { shell: false, encoding: 'utf8' });

    proc.stdout.on('data', (chunk) => {
        const lines = chunk.toString().split('\n').filter(l => l.trim());
        lines.forEach(l => {
            sessions.get(sessionId)?.lines.push({ type: 'out', text: l.trim() });
            broadcastSSE(sessionId, { type: 'log', line: l.trim() });
        });
    });

    proc.stderr.on('data', (chunk) => {
        const lines = chunk.toString().split('\n').filter(l => l.trim());
        lines.forEach(l => {
            sessions.get(sessionId)?.lines.push({ type: 'err', text: l.trim() });
            broadcastSSE(sessionId, { type: 'log', line: '[WARN] ' + l.trim() });
        });
    });

    proc.on('close', (code) => {
        const session = sessions.get(sessionId);
        if (!session) return;

        // Parse the SUMMARY line from stdout
        const summaryLine = session.lines.find(l => l.text.startsWith('SUMMARY:'));
        const summaryText = summaryLine?.text?.replace('SUMMARY:', '') || '';

        // Collect output files
        const files = fs.existsSync(outputDir)
            ? fs.readdirSync(outputDir).filter(f => f.endsWith('.json'))
            : [];

        session.status = code === 0 ? 'complete' : 'error';
        session.summary = summaryText;
        session.outputFiles = files;

        broadcastSSE(sessionId, {
            type: 'complete',
            code,
            summary: summaryText,
            outputFiles: files,
            sessionId,
            graphAvailable: files.includes('graph.json'),
        });
    });

    proc.on('error', (err) => {
        const session = sessions.get(sessionId);
        if (session) session.status = 'error';
        broadcastSSE(sessionId, { type: 'error', message: err.message });
    });

    res.json({ sessionId });
});

// ── GET /api/integrations/adexplorer/stream/:sessionId ─────────────────────
router.get('/stream/:sessionId', (req, res) => {
    const { sessionId } = req.params;
    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');
    res.setHeader('X-Accel-Buffering', 'no');
    res.flushHeaders();

    const session = sessions.get(sessionId);
    if (!session) {
        res.write(`data: ${JSON.stringify({ type: 'error', message: 'Session not found' })}\n\n`);
        return res.end();
    }

    // Replay existing log lines (if client reconnects)
    session.lines.forEach(l => {
        res.write(`data: ${JSON.stringify({ type: 'log', line: l.text })}\n\n`);
    });

    if (session.status !== 'running') {
        res.write(`data: ${JSON.stringify({ type: 'complete', summary: session.summary, outputFiles: session.outputFiles, sessionId, graphAvailable: session.outputFiles?.includes('graph.json') })}\n\n`);
        return res.end();
    }

    sseClients.set(sessionId, res);
    req.on('close', () => sseClients.delete(sessionId));
});

// ── GET /api/integrations/adexplorer/graph/:sessionId ─────────────────────
router.get('/graph/:sessionId', (req, res) => {
    const { sessionId } = req.params;
    const session = sessions.get(sessionId);
    if (!session) return res.status(404).json({ error: 'Session not found' });

    const graphFile = path.join(session.outputDir, 'graph.json');
    if (!fs.existsSync(graphFile)) return res.status(404).json({ error: 'graph.json not generated yet' });

    res.setHeader('Content-Type', 'application/json');
    fs.createReadStream(graphFile).pipe(res);
});

// ── GET /api/integrations/adexplorer/files/:sessionId ─────────────────────
// List available JSON files in a session's output directory
router.get('/files/:sessionId', (req, res) => {
    const { sessionId } = req.params;
    const session = sessions.get(sessionId);
    if (!session) return res.status(404).json({ error: 'Session not found' });

    const files = fs.existsSync(session.outputDir)
        ? fs.readdirSync(session.outputDir).filter(f => f.endsWith('.json') || f.endsWith('.tar.gz'))
        : [];
    res.json({ files, outputDir: session.outputDir });
});

// ── GET /api/integrations/adexplorer/download/:sessionId/:filename ─────────
router.get('/download/:sessionId/:filename', (req, res) => {
    const { sessionId, filename } = req.params;
    const session = sessions.get(sessionId);
    if (!session) return res.status(404).json({ error: 'Session not found' });

    // Prevent path traversal
    const safe = path.basename(filename);
    const filePath = path.join(session.outputDir, safe);
    if (!fs.existsSync(filePath)) return res.status(404).json({ error: 'File not found' });

    res.setHeader('Content-Disposition', `attachment; filename="${safe}"`);
    fs.createReadStream(filePath).pipe(res);
});

module.exports = router;
