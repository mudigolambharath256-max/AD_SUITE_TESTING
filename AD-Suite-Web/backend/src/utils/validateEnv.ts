import { logger } from './logger';

/** Fail fast in production when auth cannot be configured safely. */
export function validateEnv(): void {
    if (process.env.NODE_ENV !== 'production') {
        return;
    }
    const secret = process.env.JWT_SECRET;
    if (!secret || secret.length < 32) {
        throw new Error(
            'JWT_SECRET must be set and at least 32 characters when NODE_ENV=production'
        );
    }
    logger.info('Environment validation passed (production)');
}
