import { Request, Response, NextFunction } from 'express';
import { logger } from '../utils/logger';
import { getRepoRoot } from '../utils/repoRoot';
import { loadMergedChecksCatalog, isRunnableEngine } from '../utils/loadChecksCatalog';

export class CheckController {
    public getChecks = async (req: Request, res: Response, next: NextFunction) => {
        try {
            const rootDir = getRepoRoot();
            const loaded = loadMergedChecksCatalog(rootDir);

            if (!loaded.ok) {
                logger.warn(`Catalog load failed: ${loaded.error}`);
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
                : allChecks.filter((check) => isRunnableEngine(check.engine));

            const categoriesSet = new Set<string>();
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

            logger.info(
                `Returning ${categories.length} categories and ${checks.length} checks (catalog ${checksJsonPath})`
            );

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
        } catch (error: unknown) {
            const message = error instanceof Error ? error.message : 'Unknown error';
            logger.error('Error reading catalog:', error);
            res.status(500).json({
                error: 'Failed to read catalog',
                message
            });
        }
    }

    public getCheck = async (req: Request, res: Response, next: NextFunction) => {
        try {
            const { id } = req.params;
            const rootDir = getRepoRoot();
            const loaded = loadMergedChecksCatalog(rootDir);

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
        } catch (error: unknown) {
            const message = error instanceof Error ? error.message : 'Unknown error';
            logger.error('Error reading check:', error);
            res.status(500).json({
                error: 'Failed to read check',
                message
            });
        }
    }
}
