"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.RUNNABLE_SCAN_ENGINES = void 0;
exports.loadMergedChecksCatalog = loadMergedChecksCatalog;
exports.isRunnableEngine = isRunnableEngine;
const fs_1 = __importDefault(require("fs"));
const mergeCatalogOverrides_1 = require("./mergeCatalogOverrides");
const catalogPaths_1 = require("./catalogPaths");
/** Engines Invoke-ADSuiteScan.ps1 runs (inventory/documentation and unimplemented registry excluded). */
exports.RUNNABLE_SCAN_ENGINES = new Set(['ldap', 'filesystem', 'adcs', 'acl']);
function loadMergedChecksCatalog(rootDir) {
    const checksJsonPath = (0, catalogPaths_1.resolveChecksJsonPath)(rootDir);
    const checksOverridesPath = (0, catalogPaths_1.resolveChecksOverridesPath)(rootDir);
    if (!fs_1.default.existsSync(checksJsonPath)) {
        return {
            ok: false,
            error: `Checks catalog not found: ${checksJsonPath}`,
            checksJsonPath,
            checksOverridesPath
        };
    }
    const raw = fs_1.default.readFileSync(checksJsonPath, 'utf-8');
    const doc = JSON.parse(raw.replace(/^\uFEFF/, ''));
    if (!doc.checks || !Array.isArray(doc.checks)) {
        return {
            ok: false,
            error: 'Catalog has no checks array',
            checksJsonPath,
            checksOverridesPath
        };
    }
    if (checksOverridesPath) {
        const ovRaw = fs_1.default.readFileSync(checksOverridesPath, 'utf-8');
        const ovDoc = JSON.parse(ovRaw.replace(/^\uFEFF/, ''));
        (0, mergeCatalogOverrides_1.mergeCatalogOverrides)(doc, ovDoc);
    }
    return {
        ok: true,
        document: doc,
        checksJsonPath,
        checksOverridesPath
    };
}
function isRunnableEngine(engine) {
    const e = (engine == null ? 'ldap' : String(engine)).toLowerCase();
    return exports.RUNNABLE_SCAN_ENGINES.has(e);
}
//# sourceMappingURL=loadChecksCatalog.js.map