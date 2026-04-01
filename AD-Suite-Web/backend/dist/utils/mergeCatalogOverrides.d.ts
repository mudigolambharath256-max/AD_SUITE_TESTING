/**
 * Same merge semantics as Merge-ADSuiteCatalogOverrides in Modules/ADSuite.Adsi.psm1:
 * patch base checks by id; unknown override ids are ignored.
 */
export declare function mergeCatalogOverrides(baseDoc: {
    checks?: unknown[];
}, overridesDoc: {
    checks?: unknown[];
}): {
    checks?: unknown[];
};
//# sourceMappingURL=mergeCatalogOverrides.d.ts.map