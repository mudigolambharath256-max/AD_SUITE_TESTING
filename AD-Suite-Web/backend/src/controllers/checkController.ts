import { Request, Response, NextFunction } from 'express';
import fs from 'fs';
import path from 'path';
import { logger } from '../utils/logger';

export class CheckController {
    private getCatalogPath(): string {
        // Corrected path to reach the root AD_SUITE folder from backend/src/controllers
        // src/controllers -> src -> backend -> AD-Suite-Web -> AD_SUITE
        return path.resolve(__dirname, '../../../../checks.generated.json');
    }

    public getChecks = async (req: Request, res: Response, next: NextFunction) => {
        try {
            const catalogPath = this.getCatalogPath();
            logger.info(`Fetching catalog from: ${catalogPath}`);

            if (!fs.existsSync(catalogPath)) {
                logger.warn(`Catalog not found at ${catalogPath}`);
                return res.status(404).json({
                    error: 'Catalog not found',
                    message: `checks.generated.json not found at expected path: ${catalogPath}`
                });
            }

            const catalogData = fs.readFileSync(catalogPath, 'utf-8');
            const catalog = JSON.parse(catalogData);

            if (!catalog.checks || !Array.isArray(catalog.checks)) {
                return res.status(500).json({
                    error: 'Invalid catalog format',
                    message: 'Catalog does not contain a valid checks array'
                });
            }

            // Extract unique categories
            const categoriesSet = new Set<string>();
            catalog.checks.forEach((check: any) => {
                if (check.category) {
                    categoriesSet.add(check.category);
                }
            });
            const categories = Array.from(categoriesSet).sort();

            // Map checks to a cleaner format
            const checks = catalog.checks.map((check: any) => ({
                id: check.id,
                name: check.name,
                category: check.category,
                severity: check.severity || 'info',
                description: check.description || '',
                engine: check.engine || 'ldap',
                sourcePath: check.sourcePath
            }));

            logger.info(`Returning ${categories.length} categories and ${checks.length} checks`);

            res.json({
                categories,
                checks,
                meta: {
                    totalChecks: checks.length,
                    totalCategories: categories.length,
                    catalogPath: catalogPath
                }
            });
        } catch (error: any) {
            logger.error('Error reading catalog:', error);
            res.status(500).json({
                error: 'Failed to read catalog',
                message: error.message
            });
        }
    }

    public getCheck = async (req: Request, res: Response, next: NextFunction) => {
        try {
            const { id } = req.params;
            const catalogPath = this.getCatalogPath();

            if (!fs.existsSync(catalogPath)) {
                return res.status(404).json({
                    error: 'Catalog not found'
                });
            }

            const catalogData = fs.readFileSync(catalogPath, 'utf-8');
            const catalog = JSON.parse(catalogData);

            const check = catalog.checks.find((c: any) => c.id === id);

            if (!check) {
                return res.status(404).json({
                    error: 'Check not found',
                    message: `No check found with ID: ${id}`
                });
            }

            res.json({ check });
        } catch (error: any) {
            logger.error('Error reading check:', error);
            res.status(500).json({
                error: 'Failed to read check',
                message: error.message
            });
        }
    }
}
