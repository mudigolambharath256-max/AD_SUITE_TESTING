import { Request, Response, NextFunction } from 'express';
export declare class CheckController {
    getChecks: (req: Request, res: Response, next: NextFunction) => Promise<Response<any, Record<string, any>> | undefined>;
    getCheck: (req: Request, res: Response, next: NextFunction) => Promise<Response<any, Record<string, any>> | undefined>;
}
//# sourceMappingURL=checkController.d.ts.map