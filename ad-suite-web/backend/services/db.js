const Database = require('better-sqlite3');
const path = require('path');
const fs = require('fs');

class DatabaseService {
  constructor() {
    const dbPath = path.join(__dirname, '../data/ad-suite.db');
    const dataDir = path.dirname(dbPath);

    if (!fs.existsSync(dataDir)) {
      fs.mkdirSync(dataDir, { recursive: true });
    }

    this.db = new Database(dbPath);
    this.init();
  }

  init() {
    // Create tables
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS scans (
        id            TEXT PRIMARY KEY,
        timestamp     INTEGER NOT NULL,
        engine        TEXT NOT NULL,
        suite_root    TEXT NOT NULL,
        check_ids     TEXT NOT NULL,
        check_count   INTEGER NOT NULL,
        finding_count INTEGER DEFAULT 0,
        duration_ms   INTEGER DEFAULT 0,
        status        TEXT DEFAULT 'running'
      );

      CREATE TABLE IF NOT EXISTS findings (
        id                 TEXT PRIMARY KEY,
        scan_id            TEXT NOT NULL REFERENCES scans(id),
        check_id           TEXT NOT NULL,
        check_name         TEXT,
        category           TEXT,
        severity           TEXT,
        risk_score         INTEGER,
        mitre              TEXT,
        name               TEXT,
        distinguished_name TEXT,
        details_json       TEXT,
        created_at         INTEGER NOT NULL
      );

      CREATE TABLE IF NOT EXISTS schedules (
        id           TEXT PRIMARY KEY,
        name         TEXT NOT NULL,
        check_ids    TEXT NOT NULL,
        engine       TEXT NOT NULL,
        cron         TEXT NOT NULL,
        auto_export  TEXT,
        auto_push    TEXT,
        enabled      INTEGER DEFAULT 1,
        last_run     INTEGER,
        next_run     INTEGER,
        created_at   INTEGER NOT NULL
      );

      CREATE TABLE IF NOT EXISTS settings (
        key   TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );

      CREATE INDEX IF NOT EXISTS idx_findings_scan_id ON findings(scan_id);
      CREATE INDEX IF NOT EXISTS idx_findings_severity ON findings(severity);
      CREATE INDEX IF NOT EXISTS idx_findings_category ON findings(category);
      CREATE INDEX IF NOT EXISTS idx_scans_timestamp ON scans(timestamp);
    `);

    // Migration for existing DBs that don't have the new columns
    const columns = this.db.prepare("PRAGMA table_info(scans)").all().map(c => c.name);
    if (!columns.includes('domain')) {
      this.db.exec("ALTER TABLE scans ADD COLUMN domain TEXT DEFAULT ''");
    }
    if (!columns.includes('server_ip')) {
      this.db.exec("ALTER TABLE scans ADD COLUMN server_ip TEXT DEFAULT ''");
    }
  }

  // Scan operations
  createScan(scan) {
    const stmt = this.db.prepare(`
        INSERT INTO scans (id, timestamp, engine, suite_root, domain, server_ip, check_ids, check_count, status)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      `);
    return stmt.run(
      scan.id, scan.timestamp, scan.engine, scan.suiteRoot,
      scan.domain || '', scan.serverIp || '',
      JSON.stringify(scan.checkIds), scan.checkCount, scan.status
    );
  }

  updateScanStatus(scanId, status, findingCount = null, durationMs = null) {
    let query = 'UPDATE scans SET status = ?';
    const params = [status];

    if (findingCount !== null) {
      query += ', finding_count = ?';
      params.push(findingCount);
    }

    if (durationMs !== null) {
      query += ', duration_ms = ?';
      params.push(durationMs);
    }

    query += ' WHERE id = ?';
    params.push(scanId);

    const stmt = this.db.prepare(query);
    return stmt.run(...params);
  }

  finalizeScan(scanId, findingCount, durationMs, status) {
    const stmt = this.db.prepare(`
      UPDATE scans SET finding_count = ?, duration_ms = ?, status = ? WHERE id = ?
    `);
    return stmt.run(findingCount, durationMs, status, scanId);
  }

  insertFinding(finding) {
    const stmt = this.db.prepare(`
      INSERT INTO findings (
        id, scan_id, check_id, check_name, category, severity, 
        risk_score, mitre, name, distinguished_name, details_json, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `);
    return stmt.run(
      finding.id, finding.scanId, finding.checkId, finding.checkName,
      finding.category, finding.severity, finding.riskScore, finding.mitre,
      finding.name, finding.distinguishedName, finding.detailsJson,
      finding.createdAt || Date.now()
    );
  }

  getScanFindings(scanId, offset = 0, limit = 1000) {
    const stmt = this.db.prepare(`
      SELECT * FROM findings 
      WHERE scan_id = ? 
      ORDER BY severity DESC, created_at ASC 
      LIMIT ? OFFSET ?
    `);
    return stmt.all(scanId, limit, offset);
  }

  getSeveritySummaryForScan(scanId) {
    const stmt = this.db.prepare(`
      SELECT severity, COUNT(*) as count 
      FROM findings 
      WHERE scan_id = ? 
      GROUP BY severity
    `);
    const rows = stmt.all(scanId);
    const out = { CRITICAL: 0, HIGH: 0, MEDIUM: 0, LOW: 0, INFO: 0 };
    rows.forEach(r => { out[r.severity] = r.count; });
    return out;
  }

  getLatestCompletedScanId() {
    const stmt = this.db.prepare(`
      SELECT id FROM scans 
      WHERE status = 'completed' 
      ORDER BY timestamp DESC 
      LIMIT 1
    `);
    const row = stmt.get();
    return row?.id || null;
  }

  updateScheduleLastRun(id, timestamp) {
    const stmt = this.db.prepare('UPDATE schedules SET last_run = ? WHERE id = ?');
    return stmt.run(timestamp, id);
  }

  getSchedule(id) {
    const stmt = this.db.prepare('SELECT * FROM schedules WHERE id = ?');
    return stmt.get(id);
  }

  getScan(scanId) {
    const stmt = this.db.prepare('SELECT * FROM scans WHERE id = ?');
    return stmt.get(scanId);
  }

  getRecentScans(limit = 20) {
    const stmt = this.db.prepare(`
      SELECT * FROM scans 
      ORDER BY timestamp DESC 
      LIMIT ?
    `);
    return stmt.all(limit);
  }

  // Findings operations
  createFinding(finding) {
    const stmt = this.db.prepare(`
      INSERT INTO findings (
        id, scan_id, check_id, check_name, category, severity, 
        risk_score, mitre, name, distinguished_name, details_json, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `);
    return stmt.run(
      finding.id, finding.scanId, finding.checkId, finding.checkName,
      finding.category, finding.severity, finding.riskScore, finding.mitre,
      finding.name, finding.distinguishedName, finding.detailsJson,
      finding.createdAt
    );
  }

  getFindings(scanId, page = 1, limit = 50, filters = {}) {
    let query = 'SELECT * FROM findings WHERE scan_id = ?';
    const params = [scanId];

    if (filters.severity && filters.severity.length > 0) {
      query += ` AND severity IN (${filters.severity.map(() => '?').join(',')})`;
      params.push(...filters.severity);
    }

    if (filters.category && filters.category.length > 0) {
      query += ` AND category IN (${filters.category.map(() => '?').join(',')})`;
      params.push(...filters.category);
    }

    if (filters.search) {
      query += ' AND (check_name LIKE ? OR name LIKE ? OR distinguished_name LIKE ?)';
      const searchTerm = `%${filters.search}%`;
      params.push(searchTerm, searchTerm, searchTerm);
    }

    query += ' ORDER BY created_at DESC LIMIT ? OFFSET ?';
    params.push(limit, (page - 1) * limit);

    const stmt = this.db.prepare(query);
    return stmt.all(...params);
  }

  getFindingCount(scanId, filters = {}) {
    let query = 'SELECT COUNT(*) as count FROM findings WHERE scan_id = ?';
    const params = [scanId];

    if (filters.severity && filters.severity.length > 0) {
      query += ` AND severity IN (${filters.severity.map(() => '?').join(',')})`;
      params.push(...filters.severity);
    }

    if (filters.category && filters.category.length > 0) {
      query += ` AND category IN (${filters.category.map(() => '?').join(',')})`;
      params.push(...filters.category);
    }

    if (filters.search) {
      query += ' AND (check_name LIKE ? OR name LIKE ? OR distinguished_name LIKE ?)';
      const searchTerm = `%${filters.search}%`;
      params.push(searchTerm, searchTerm, searchTerm);
    }

    const stmt = this.db.prepare(query);
    return stmt.get(...params).count;
  }

  // Dashboard operations
  getSeveritySummary() {
    const stmt = this.db.prepare(`
      SELECT severity, COUNT(*) as count
      FROM findings f
      JOIN scans s ON f.scan_id = s.id
      WHERE s.timestamp = (SELECT MAX(timestamp) FROM scans)
      GROUP BY severity
    `);
    return stmt.all();
  }

  getCategorySummary() {
    const stmt = this.db.prepare(`
      SELECT category, COUNT(*) as count
      FROM findings f
      JOIN scans s ON f.scan_id = s.id
      WHERE s.timestamp = (SELECT MAX(timestamp) FROM scans)
      GROUP BY category
    `);
    return stmt.all();
  }

  // Settings operations
  getSetting(key) {
    const stmt = this.db.prepare('SELECT value FROM settings WHERE key = ?');
    const result = stmt.get(key);
    return result ? result.value : null;
  }

  setSetting(key, value) {
    const stmt = this.db.prepare(`
      INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)
    `);
    return stmt.run(key, value);
  }

  // Schedule operations
  createSchedule(schedule) {
    const stmt = this.db.prepare(`
      INSERT INTO schedules (
        id, name, check_ids, engine, cron, auto_export, auto_push,
        enabled, last_run, next_run, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `);
    return stmt.run(
      schedule.id, schedule.name, JSON.stringify(schedule.checkIds),
      schedule.engine, schedule.cron, schedule.autoExport,
      schedule.autoPush, schedule.enabled, schedule.lastRun,
      schedule.nextRun, schedule.createdAt
    );
  }

  getSchedules() {
    const stmt = this.db.prepare('SELECT * FROM schedules ORDER BY created_at DESC');
    return stmt.all();
  }

  updateSchedule(id, updates) {
    const fields = Object.keys(updates).map(key => `${key} = ?`).join(', ');
    const values = Object.values(updates);

    const stmt = this.db.prepare(`
      UPDATE schedules SET ${fields} WHERE id = ?
    `);
    return stmt.run(...values, id);
  }

  deleteSchedule(id) {
    const stmt = this.db.prepare('DELETE FROM schedules WHERE id = ?');
    return stmt.run(id);
  }

  // Utility methods
  getDbSize() {
    const stats = fs.statSync(this.db.name);
    return stats.size;
  }

  close() {
    this.db.close();
  }

  getDbPath() {
    return path.join(__dirname, '../data/ad-suite.db');
  }

  clearHistory() {
    this.db.prepare('DELETE FROM findings').run();
    this.db.prepare('DELETE FROM scans').run();
  }

  resetDatabase() {
    this.db.prepare('DELETE FROM findings').run();
    this.db.prepare('DELETE FROM scans').run();
    this.db.prepare('DELETE FROM schedules').run();
    this.db.prepare('DELETE FROM settings').run();
  }

}

module.exports = new DatabaseService();
