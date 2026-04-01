import fs from 'fs';
import path from 'path';
import { logger } from './logger';
import { getRepoRoot } from './repoRoot';

export interface AuditEntry {
    timestampUtc: string;
    method: string;
    path: string;
    statusCode: number;
    userId?: number | string;
    email?: string;
    role?: string;
}

function getAuditLogPath(): string {
    const root = path.join(getRepoRoot(), 'AD-Suite-Web', 'backend', 'logs');
    return path.join(root, 'audit.log');
}

export function appendAuditLog(entry: AuditEntry): void {
    try {
        const dir = path.dirname(getAuditLogPath());
        if (!fs.existsSync(dir)) {
            fs.mkdirSync(dir, { recursive: true });
        }
        fs.appendFileSync(getAuditLogPath(), JSON.stringify(entry) + '\n', 'utf8');
    } catch (e) {
        logger.warn(`audit log append failed: ${e}`);
    }
}
