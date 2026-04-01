"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.CheckController = void 0;
const logger_1 = require("../utils/logger");
const repoRoot_1 = require("../utils/repoRoot");
const loadChecksCatalog_1 = require("../utils/loadChecksCatalog");
class CheckController {
    constructor() {
        this.getChecks = async (req, res, next) => {
            try {
                const rootDir = (0, repoRoot_1.getRepoRoot)();
                const loaded = (0, loadChecksCatalog_1.loadMergedChecksCatalog)(rootDir);
                if (!loaded.ok) {
                    logger_1.logger.warn(`Catalog load failed: ${loaded.error}`);
                    return res.status(404).json({
                        error: 'Catalog not found',
                        message: loaded.error,
                        checksJsonPath: loaded.checksJsonPath
                    });
                }
                const { document, checksJsonPath, checksOverridesPath } = loaded;
                const allChecks = document.checks ?? [];
                const includeInventory = req.query.includeInventory === '1' || req.query.includeInventory === 'true';
                const pool = includeInventory
                    ? allChecks
                    : allChecks.filter((check) => (0, loadChecksCatalog_1.isRunnableEngine)(check.engine));
                const categoriesSet = new Set();
                pool.forEach((check) => {
                    if (check.category) {
                        categoriesSet.add(String(check.category));
                    }
                });
                const categories = Array.from(categoriesSet).sort();
                const checks = pool.map((check) => ({
                    id: check.id,
                    name: check.name,
                    category: check.category,
                    severity: check.severity || 'info',
                    description: check.description || '',
                    engine: check.engine || 'ldap',
                    sourcePath: check.sourcePath
                }));
                logger_1.logger.info(`Returning ${categories.length} categories and ${checks.length} checks (catalog ${checksJsonPath})`);
                res.json({
                    categories,
                    checks,
                    meta: {
                        totalChecks: checks.length,
                        totalCategories: categories.length,
                        checksJsonPath,
                        checksOverridesPath: checksOverridesPath ?? null,
                        includeInventory
                    }
                });
            }
            catch (error) {
                const message = error instanceof Error ? error.message : 'Unknown error';
                logger_1.logger.error('Error reading catalog:', error);
                res.status(500).json({
                    error: 'Failed to read catalog',
                    message
                });
            }
        };
        this.getCheck = async (req, res, next) => {
            try {
                const { id } = req.params;
                const rootDir = (0, repoRoot_1.getRepoRoot)();
                const loaded = (0, loadChecksCatalog_1.loadMergedChecksCatalog)(rootDir);
                if (!loaded.ok) {
                    return res.status(404).json({
                        error: 'Catalog not found',
                        message: loaded.error
                    });
                }
                const check = loaded.document.checks?.find((c) => String(c.id) === id);
                if (!check) {
                    return res.status(404).json({
                        error: 'Check not found',
                        message: `No check found with ID: ${id}`
                    });
                }
                res.json({ check });
            }
            catch (error) {
                const message = error instanceof Error ? error.message : 'Unknown error';
                logger_1.logger.error('Error reading check:', error);
                res.status(500).json({
                    error: 'Failed to read check',
                    message
                });
            }
        };
    }
}
exports.CheckController = CheckController;
//# sourceMappingURL=checkController.js.map