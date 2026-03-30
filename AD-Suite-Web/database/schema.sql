-- AD Suite Database Schema

-- Organizations
CREATE TABLE organizations (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    domain VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Users
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    organization_id INTEGER REFERENCES organizations(id) ON DELETE CASCADE,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    name VARCHAR(255) NOT NULL,
    role VARCHAR(50) NOT NULL DEFAULT 'analyst', -- admin, analyst, viewer
    is_active BOOLEAN DEFAULT true,
    last_login TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Scans
CREATE TABLE scans (
    id SERIAL PRIMARY KEY,
    organization_id INTEGER REFERENCES organizations(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    checks_json_path VARCHAR(500),
    overrides_path VARCHAR(500),
    categories TEXT[], -- Array of category names
    status VARCHAR(50) NOT NULL DEFAULT 'pending', -- pending, running, completed, failed, cancelled
    checks_run INTEGER DEFAULT 0,
    with_findings INTEGER DEFAULT 0,
    errors INTEGER DEFAULT 0,
    total_findings INTEGER DEFAULT 0,
    global_score INTEGER,
    risk_band VARCHAR(50), -- Low, Moderate, High, Critical
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    created_by INTEGER REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Scan Results (denormalized for performance)
CREATE TABLE scan_results (
    id SERIAL PRIMARY KEY,
    scan_id INTEGER REFERENCES scans(id) ON DELETE CASCADE,
    check_id VARCHAR(50) NOT NULL,
    check_name VARCHAR(255),
    category VARCHAR(100),
    severity VARCHAR(50),
    result VARCHAR(50), -- Pass, Fail, Error, Skipped
    finding_count INTEGER DEFAULT 0,
    check_score INTEGER DEFAULT 0,
    duration_ms INTEGER,
    error TEXT,
    description TEXT,
    remediation TEXT,
    references TEXT[],
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Findings (individual finding records)
CREATE TABLE findings (
    id SERIAL PRIMARY KEY,
    scan_result_id INTEGER REFERENCES scan_results(id) ON DELETE CASCADE,
    data JSONB NOT NULL, -- Flexible storage for finding properties
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Remediation Tracking
CREATE TABLE remediations (
    id SERIAL PRIMARY KEY,
    scan_result_id INTEGER REFERENCES scan_results(id) ON DELETE CASCADE,
    status VARCHAR(50) NOT NULL DEFAULT 'open', -- open, in_progress, resolved, accepted_risk, false_positive
    assigned_to INTEGER REFERENCES users(id),
    priority VARCHAR(50), -- critical, high, medium, low
    notes TEXT,
    resolved_at TIMESTAMP,
    created_by INTEGER REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Comments
CREATE TABLE comments (
    id SERIAL PRIMARY KEY,
    remediation_id INTEGER REFERENCES remediations(id) ON DELETE CASCADE,
    user_id INTEGER REFERENCES users(id),
    comment TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Scheduled Scans
CREATE TABLE scheduled_scans (
    id SERIAL PRIMARY KEY,
    organization_id INTEGER REFERENCES organizations(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    checks_json_path VARCHAR(500),
    overrides_path VARCHAR(500),
    categories TEXT[],
    cron_expression VARCHAR(100) NOT NULL, -- e.g., '0 2 * * *' for daily at 2 AM
    is_active BOOLEAN DEFAULT true,
    last_run TIMESTAMP,
    next_run TIMESTAMP,
    created_by INTEGER REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Audit Log
CREATE TABLE audit_log (
    id SERIAL PRIMARY KEY,
    organization_id INTEGER REFERENCES organizations(id) ON DELETE CASCADE,
    user_id INTEGER REFERENCES users(id),
    action VARCHAR(100) NOT NULL,
    resource_type VARCHAR(50),
    resource_id INTEGER,
    details JSONB,
    ip_address VARCHAR(45),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for performance
CREATE INDEX idx_users_organization ON users(organization_id);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_scans_organization ON scans(organization_id);
CREATE INDEX idx_scans_status ON scans(status);
CREATE INDEX idx_scans_created_at ON scans(created_at DESC);
CREATE INDEX idx_scan_results_scan ON scan_results(scan_id);
CREATE INDEX idx_scan_results_severity ON scan_results(severity);
CREATE INDEX idx_scan_results_category ON scan_results(category);
CREATE INDEX idx_findings_scan_result ON findings(scan_result_id);
CREATE INDEX idx_findings_data ON findings USING gin(data);
CREATE INDEX idx_remediations_status ON remediations(status);
CREATE INDEX idx_remediations_assigned ON remediations(assigned_to);
CREATE INDEX idx_audit_log_organization ON audit_log(organization_id);
CREATE INDEX idx_audit_log_created_at ON audit_log(created_at DESC);

-- Insert default admin user (password: admin123)
INSERT INTO organizations (name, domain) VALUES ('Default Organization', 'example.com');
INSERT INTO users (organization_id, email, password_hash, name, role) 
VALUES (1, 'admin@example.com', '$2b$10$rKvVPZhJvZ5qZ5qZ5qZ5qOqZ5qZ5qZ5qZ5qZ5qZ5qZ5qZ5qZ5qZ5q', 'Admin User', 'admin');
