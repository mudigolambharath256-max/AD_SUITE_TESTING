export type ScanEngineApi = 'adsi' | 'rsat' | 'combined' | 'csharp' | 'cmd';
export declare function normalizeScanEngine(raw: unknown): ScanEngineApi;
/** Value for Invoke-ADSuiteScan.ps1 -LdapEngine. CMD launcher still runs checks with ADSI LDAP today. */
export declare function toPowerShellLdapEngine(api: ScanEngineApi): string;
/** Fields written to out/scan-<id>/scan.meta.json (must stay aligned with executeScan). */
export declare function scanMetaSidecarFromApi(scanEngineBody: unknown): {
    scanEngine: ScanEngineApi;
    ldapEngine: string;
    launchViaCmd: boolean;
};
//# sourceMappingURL=scanEngineMapping.d.ts.map