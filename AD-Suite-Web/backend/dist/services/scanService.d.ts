export interface ScanSummary {
    id: string;
    name: string;
    filename: string;
    path: string;
    timestamp: number;
    totalFindings: number;
    globalRiskBand: string;
    status: string;
    engine: string;
    severity: {
        critical: number;
        high: number;
        medium: number;
        low: number;
    };
}
export declare class ScanService {
    private static readonly UPLOAD_DIR;
    private static readonly OUT_DIR;
    static listAvailableScans(): Promise<ScanSummary[]>;
    private static getScanSummary;
    static getScanContent(id: string): Promise<any | null>;
}
//# sourceMappingURL=scanService.d.ts.map