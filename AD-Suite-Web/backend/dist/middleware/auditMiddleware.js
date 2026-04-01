"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.auditMutations = auditMutations;
const auditLog_1 = require("../utils/auditLog");
/** Logs mutating HTTP calls after response completes (requires authenticate upstream). */
function auditMutations(req, res, next) {
    const method = req.method.toUpperCase();
    if (!['POST', 'PUT', 'DELETE', 'PATCH'].includes(method)) {
        next();
        return;
    }
    res.on('finish', () => {
        (0, auditLog_1.appendAuditLog)({
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
//# sourceMappingURL=auditMiddleware.js.map