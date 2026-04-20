import path from 'path';
import fs from 'fs';

/**
 * Primary catalog JSON (checks.json, checks.generated.json, etc.).
 * Mirrors Invoke-ADSuiteScan.ps1 resolution when spawned from repo root.
 */
export function resolveChecksJsonPath(rootDir: string): string {
    const envPath = process.env.AD_SUITE_CHECKS_JSON || process.env.CHECKS_JSON_PATH;
    if (envPath) {
        if (path.isAbsolute(envPath)) {
            return envPath;
        }
        return path.join(rootDir, envPath);
    }
    const unified = path.join(rootDir, 'checks.unified.json');
    if (fs.existsSync(unified)) {
        return unified;
    }
    const generated = path.join(rootDir, 'checks.generated.json');
    if (fs.existsSync(generated)) {
        return generated;
    }
    return path.join(rootDir, 'checks.json');
}

/**
 * Optional overrides (patches by check id). If env unset, uses checks.overrides.json
 * at repo root when present — same default as Invoke-ADSuiteScan.ps1.
 */
export function resolveChecksOverridesPath(rootDir: string): string | null {
    const envPath = process.env.AD_SUITE_CHECKS_OVERRIDES || process.env.CHECKS_OVERRIDES_PATH;
    if (envPath) {
        const p = path.isAbsolute(envPath) ? envPath : path.join(rootDir, envPath);
        return fs.existsSync(p) ? p : null;
    }
    const defaultOv = path.join(rootDir, 'checks.overrides.json');
    return fs.existsSync(defaultOv) ? defaultOv : null;
}
