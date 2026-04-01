import { Response, NextFunction } from 'express';
import { AuthRequest } from './auth';
/** Logs mutating HTTP calls after response completes (requires authenticate upstream). */
export declare function auditMutations(req: AuthRequest, res: Response, next: NextFunction): void;
//# sourceMappingURL=auditMiddleware.d.ts.map