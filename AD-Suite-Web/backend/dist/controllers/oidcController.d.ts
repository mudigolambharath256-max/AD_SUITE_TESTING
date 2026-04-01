import { Request, Response, NextFunction } from 'express';
export declare class OidcController {
    startLogin: (req: Request, res: Response, next: NextFunction) => Promise<void>;
    callback: (req: Request, res: Response, next: NextFunction) => Promise<void>;
    status: (_req: Request, res: Response) => void;
}
//# sourceMappingURL=oidcController.d.ts.map