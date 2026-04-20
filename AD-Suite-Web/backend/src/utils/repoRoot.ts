import path from 'path';

/**
 * AD_SUITE repository root (parent of AD-Suite-Web), where checks*.json and Invoke-ADSuiteScan.ps1 live.
 * Set AD_SUITE_REPO_ROOT if the backend runs from a layout where __dirname resolution is wrong.
 */
export function getRepoRoot(): string {
    const env = process.env.AD_SUITE_REPO_ROOT?.trim();
    if (env) {
        return path.isAbsolute(env) ? path.normalize(env) : path.resolve(process.cwd(), env);
    }
    return path.resolve(__dirname, '../../../../');
}
