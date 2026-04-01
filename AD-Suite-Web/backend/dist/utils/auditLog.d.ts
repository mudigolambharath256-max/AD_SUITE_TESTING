export interface AuditEntry {
    timestampUtc: string;
    method: string;
    path: string;
    statusCode: number;
    userId?: number | string;
    email?: string;
    role?: string;
}
export declare function appendAuditLog(entry: AuditEntry): void;
//# sourceMappingURL=auditLog.d.ts.map