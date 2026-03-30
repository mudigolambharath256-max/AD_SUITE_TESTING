import path from 'path';

/** AD_SUITE repository root (parent of AD-Suite-Web). */
export function getRepoRoot(): string {
    return path.resolve(__dirname, '../../../../');
}
