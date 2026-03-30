"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.CheckController = void 0;
const fs_1 = __importDefault(require("fs"));
const path_1 = __importDefault(require("path"));
const logger_1 = require("../utils/logger");
class CheckController {
    constructor() {
        this.getChecks = async (req, res, next) => {
            try {
                const catalogPath = this.getCatalogPath();
                logger_1.logger.info(`Fetching catalog from: ${catalogPath}`);
                if (!fs_1.default.existsSync(catalogPath)) {
                    logger_1.logger.warn(`Catalog not found at ${catalogPath}`);
                    return res.status(404).json({
                        error: 'Catalog not found',
                        message: `checks.generated.json not found at expected path: ${catalogPath}`
                    });
                }
                const catalogData = fs_1.default.readFileSync(catalogPath, 'utf-8');
                const catalog = JSON.parse(catalogData);
                if (!catalog.checks || !Array.isArray(catalog.checks)) {
                    return res.status(500).json({
                        error: 'Invalid catalog format',
                        message: 'Catalog does not contain a valid checks array'
                    });
                }
                // Extract unique categories
                const categoriesSet = new Set();
                catalog.checks.forEach((check) => {
                    if (check.category) {
                        categoriesSet.add(check.category);
                    }
                });
                const categories = Array.from(categoriesSet).sort();
                // Map checks to a cleaner format
                const checks = catalog.checks.map((check) => ({
                    id: check.id,
                    name: check.name,
                    category: check.category,
                    severity: check.severity || 'info',
                    description: check.description || '',
                    engine: check.engine || 'ldap',
                    sourcePath: check.sourcePath
                }));
                logger_1.logger.info(`Returning ${categories.length} categories and ${checks.length} checks`);
                res.json({
                    categories,
                    checks,
                    meta: {
                        totalChecks: checks.length,
                        totalCategories: categories.length,
                        catalogPath: catalogPath
                    }
                });
            }
            catch (error) {
                logger_1.logger.error('Error reading catalog:', error);
                res.status(500).json({
                    error: 'Failed to read catalog',
                    message: error.message
                });
            }
        };
        this.getCheck = async (req, res, next) => {
            try {
                const { id } = req.params;
                const catalogPath = this.getCatalogPath();
                if (!fs_1.default.existsSync(catalogPath)) {
                    return res.status(404).json({
                        error: 'Catalog not found'
                    });
                }
                const catalogData = fs_1.default.readFileSync(catalogPath, 'utf-8');
                const catalog = JSON.parse(catalogData);
                const check = catalog.checks.find((c) => c.id === id);
                if (!check) {
                    return res.status(404).json({
                        error: 'Check not found',
                        message: `No check found with ID: ${id}`
                    });
                }
                res.json({ check });
            }
            catch (error) {
                logger_1.logger.error('Error reading check:', error);
                res.status(500).json({
                    error: 'Failed to read check',
                    message: error.message
                });
            }
        };
    }
    getCatalogPath() {
        // Corrected path to reach the root AD_SUITE folder from backend/src/controllers
        // src/controllers -> src -> backend -> AD-Suite-Web -> AD_SUITE
        return path_1.default.resolve(__dirname, '../../../../checks.generated.json');
    }
}
exports.CheckController = CheckController;
//# sourceMappingURL=checkController.js.map