import fs from 'fs';
import { mergeCatalogOverrides } from './mergeCatalogOverrides';
import { resolveChecksJsonPath, resolveChecksOverridesPath } from './catalogPaths';

/** Engines Invoke-ADSuiteScan.ps1 runs (inventory/documentation and unimplemented registry excluded). */
export const RUNNABLE_SCAN_ENGINES = new Set(['ldap', 'filesystem', 'adcs', 'acl']);

export type LoadedCatalog =
    | {
          ok: true;
          document: { checks?: Record<string, unknown>[]; defaults?: unknown; schemaVersion?: unknown };
          checksJsonPath: string;
          checksOverridesPath: string | null;
      }
    | {
          ok: false;
          error: string;
          checksJsonPath: string;
          checksOverridesPath: string | null;
      };

export function loadMergedChecksCatalog(rootDir: string): LoadedCatalog {
    const checksJsonPath = resolveChecksJsonPath(rootDir);
    const checksOverridesPath = resolveChecksOverridesPath(rootDir);

    if (!fs.existsSync(checksJsonPath)) {
        return {
            ok: false,
            error: `Checks catalog not found: ${checksJsonPath}`,
            checksJsonPath,
            checksOverridesPath
        };
    }

    const raw = fs.readFileSync(checksJsonPath, 'utf-8');
    const doc = JSON.parse(raw.replace(/^\uFEFF/, '')) as {
        checks?: Record<string, unknown>[];
        defaults?: unknown;
        schemaVersion?: unknown;
    };

    if (!doc.checks || !Array.isArray(doc.checks)) {
        return {
            ok: false,
            error: 'Catalog has no checks array',
            checksJsonPath,
            checksOverridesPath
        };
    }

    if (checksOverridesPath) {
        const ovRaw = fs.readFileSync(checksOverridesPath, 'utf-8');
        const ovDoc = JSON.parse(ovRaw.replace(/^\uFEFF/, '')) as { checks?: unknown[] };
        mergeCatalogOverrides(doc, ovDoc);
    }

    return {
        ok: true,
        document: doc,
        checksJsonPath,
        checksOverridesPath
    };
}

export function isRunnableEngine(engine: unknown): boolean {
    const e = (engine == null ? 'ldap' : String(engine)).toLowerCase();
    return RUNNABLE_SCAN_ENGINES.has(e);
}
