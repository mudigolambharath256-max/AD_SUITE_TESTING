/**
 * Primary catalog JSON (checks.json, checks.generated.json, etc.).
 * Mirrors Invoke-ADSuiteScan.ps1 resolution when spawned from repo root.
 */
export declare function resolveChecksJsonPath(rootDir: string): string;
/**
 * Optional overrides (patches by check id). If env unset, uses checks.overrides.json
 * at repo root when present — same default as Invoke-ADSuiteScan.ps1.
 */
export declare function resolveChecksOverridesPath(rootDir: string): string | null;
//# sourceMappingURL=catalogPaths.d.ts.map