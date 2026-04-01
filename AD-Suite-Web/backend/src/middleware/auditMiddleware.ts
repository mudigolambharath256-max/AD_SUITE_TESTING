import { Response, NextFunction } from 'express';
import { AuthRequest } from './auth';
import { appendAuditLog } from '../utils/auditLog';

/** Logs mutating HTTP calls after response completes (requires authenticate upstream). */
export function auditMutations(req: AuthRequest, res: Response, next: NextFunction): void {
    const method = req.method.toUpperCase();
    if (!['POST', 'PUT', 'DELETE', 'PATCH'].includes(method)) {
        next();
        return;
    }
    res.on('finish', () => {
        appendAuditLog({
            timestampUtc: new Date().toISOString(),
            method,
            path: req.originalUrl || req.path,
            statusCode: res.statusCode,
            userId: req.user?.id,
            email: req.user?.email,
            role: req.user?.role
        });
    });
    next();
}
