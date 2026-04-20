"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.resolveChecksJsonPath = resolveChecksJsonPath;
exports.resolveChecksOverridesPath = resolveChecksOverridesPath;
const path_1 = __importDefault(require("path"));
const fs_1 = __importDefault(require("fs"));
/**
 * Primary catalog JSON (checks.json, checks.generated.json, etc.).
 * Mirrors Invoke-ADSuiteScan.ps1 resolution when spawned from repo root.
 */
function resolveChecksJsonPath(rootDir) {
    const envPath = process.env.AD_SUITE_CHECKS_JSON || process.env.CHECKS_JSON_PATH;
    if (envPath) {
        if (path_1.default.isAbsolute(envPath)) {
            return envPath;
        }
        return path_1.default.join(rootDir, envPath);
    }
    const unified = path_1.default.join(rootDir, 'checks.unified.json');
    if (fs_1.default.existsSync(unified)) {
        return unified;
    }
    const generated = path_1.default.join(rootDir, 'checks.generated.json');
    if (fs_1.default.existsSync(generated)) {
        return generated;
    }
    return path_1.default.join(rootDir, 'checks.json');
}
/**
 * Optional overrides (patches by check id). If env unset, uses checks.overrides.json
 * at repo root when present — same default as Invoke-ADSuiteScan.ps1.
 */
function resolveChecksOverridesPath(rootDir) {
    const envPath = process.env.AD_SUITE_CHECKS_OVERRIDES || process.env.CHECKS_OVERRIDES_PATH;
    if (envPath) {
        const p = path_1.default.isAbsolute(envPath) ? envPath : path_1.default.join(rootDir, envPath);
        return fs_1.default.existsSync(p) ? p : null;
    }
    const defaultOv = path_1.default.join(rootDir, 'checks.overrides.json');
    return fs_1.default.existsSync(defaultOv) ? defaultOv : null;
}
//# sourceMappingURL=catalogPaths.js.map