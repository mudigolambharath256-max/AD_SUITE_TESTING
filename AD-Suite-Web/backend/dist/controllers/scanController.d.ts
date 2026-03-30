import { Request, Response } from 'express';
export declare class ScanController {
    getScans: (_req: Request, res: Response) => Promise<void>;
    getScan: (req: Request, res: Response) => Promise<Response<any, Record<string, any>> | undefined>;
    createScan: (_req: Request, res: Response) => void;
    executeScan: (req: Request, res: Response) => Promise<Response<any, Record<string, any>> | undefined>;
    stopScan: (_req: Request, res: Response) => void;
    deleteScan: (req: Request, res: Response) => Promise<Response<any, Record<string, any>> | undefined>;
    getScanResults: (req: Request, res: Response) => Promise<Response<any, Record<string, any>> | undefined>;
    getScanFindings: (req: Request, res: Response) => Promise<Response<any, Record<string, any>> | undefined>;
    exportScan: (req: Request, res: Response) => Promise<Response<any, Record<string, any>> | undefined>;
}
//# sourceMappingURL=scanController.d.ts.map