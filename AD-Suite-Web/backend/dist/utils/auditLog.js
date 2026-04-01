"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.appendAuditLog = appendAuditLog;
const fs_1 = __importDefault(require("fs"));
const path_1 = __importDefault(require("path"));
const logger_1 = require("./logger");
const repoRoot_1 = require("./repoRoot");
function getAuditLogPath() {
    const root = path_1.default.join((0, repoRoot_1.getRepoRoot)(), 'AD-Suite-Web', 'backend', 'logs');
    return path_1.default.join(root, 'audit.log');
}
function appendAuditLog(entry) {
    try {
        const dir = path_1.default.dirname(getAuditLogPath());
        if (!fs_1.default.existsSync(dir)) {
            fs_1.default.mkdirSync(dir, { recursive: true });
        }
        fs_1.default.appendFileSync(getAuditLogPath(), JSON.stringify(entry) + '\n', 'utf8');
    }
    catch (e) {
        logger_1.logger.warn(`audit log append failed: ${e}`);
    }
}
//# sourceMappingURL=auditLog.js.map