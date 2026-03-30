"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.errorHandler = exports.AppError = void 0;
const logger_1 = require("../utils/logger");
class AppError extends Error {
    constructor(message, statusCode) {
        super(message);
        this.statusCode = statusCode;
        this.isOperational = true;
        Error.captureStackTrace(this, this.constructor);
    }
}
exports.AppError = AppError;
const errorHandler = (err, req, res, next) => {
    if (err instanceof AppError) {
        logger_1.logger.error(`${err.statusCode} - ${err.message} - ${req.originalUrl} - ${req.method}`);
        return res.status(err.statusCode).json({
            status: 'error',
            message: err.message
        });
    }
    logger_1.logger.error(`500 - ${err.message} - ${req.originalUrl} - ${req.method}`, { stack: err.stack });
    res.status(500).json({
        status: 'error',
        message: process.env.NODE_ENV === 'production'
            ? 'Internal server error'
            : err.message
    });
};
exports.errorHandler = errorHandler;
//# sourceMappingURL=errorHandler.js.map