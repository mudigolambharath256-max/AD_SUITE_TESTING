"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.validateEnv = validateEnv;
const logger_1 = require("./logger");
/** Fail fast in production when auth cannot be configured safely. */
function validateEnv() {
    if (process.env.NODE_ENV !== 'production') {
        return;
    }
    const secret = process.env.JWT_SECRET;
    if (!secret || secret.length < 32) {
        throw new Error('JWT_SECRET must be set and at least 32 characters when NODE_ENV=production');
    }
    logger_1.logger.info('Environment validation passed (production)');
}
//# sourceMappingURL=validateEnv.js.map