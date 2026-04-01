/** Engines Invoke-ADSuiteScan.ps1 runs (inventory/documentation and unimplemented registry excluded). */
export declare const RUNNABLE_SCAN_ENGINES: Set<string>;
export type LoadedCatalog = {
    ok: true;
    document: {
        checks?: Record<string, unknown>[];
        defaults?: unknown;
        schemaVersion?: unknown;
    };
    checksJsonPath: string;
    checksOverridesPath: string | null;
} | {
    ok: false;
    error: string;
    checksJsonPath: string;
    checksOverridesPath: string | null;
};
export declare function loadMergedChecksCatalog(rootDir: string): LoadedCatalog;
export declare function isRunnableEngine(engine: unknown): boolean;
//# sourceMappingURL=loadChecksCatalog.d.ts.map