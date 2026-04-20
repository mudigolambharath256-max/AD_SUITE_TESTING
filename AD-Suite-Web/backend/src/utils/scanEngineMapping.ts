export type ScanEngineApi = 'adsi' | 'rsat' | 'combined' | 'csharp' | 'cmd';

export function normalizeScanEngine(raw: unknown): ScanEngineApi {
    const s = typeof raw === 'string' ? raw.toLowerCase().trim() : '';
    if (s === 'rsat' || s === 'combined' || s === 'csharp' || s === 'cmd') return s;
    return 'adsi';
}

/** Value for Invoke-ADSuiteScan.ps1 -LdapEngine. CMD launcher still runs checks with ADSI LDAP today. */
export function toPowerShellLdapEngine(api: ScanEngineApi): string {
    if (api === 'cmd') return 'Adsi';
    const map: Record<string, string> = {
        adsi: 'Adsi',
        rsat: 'Rsat',
        combined: 'Combined',
        csharp: 'Csharp'
    };
    return map[api] ?? 'Adsi';
}

/** Fields written to out/scan-<id>/scan.meta.json (must stay aligned with executeScan). */
export function scanMetaSidecarFromApi(scanEngineBody: unknown) {
    const scanEngine = normalizeScanEngine(scanEngineBody);
    const ldapEngine = toPowerShellLdapEngine(scanEngine);
    const launchViaCmd = scanEngine === 'cmd';
    return { scanEngine, ldapEngine, launchViaCmd };
}
