"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.normalizeScanEngine = normalizeScanEngine;
exports.toPowerShellLdapEngine = toPowerShellLdapEngine;
exports.scanMetaSidecarFromApi = scanMetaSidecarFromApi;
function normalizeScanEngine(raw) {
    const s = typeof raw === 'string' ? raw.toLowerCase().trim() : '';
    if (s === 'rsat' || s === 'combined' || s === 'csharp' || s === 'cmd')
        return s;
    return 'adsi';
}
/** Value for Invoke-ADSuiteScan.ps1 -LdapEngine. CMD launcher still runs checks with ADSI LDAP today. */
function toPowerShellLdapEngine(api) {
    if (api === 'cmd')
        return 'Adsi';
    const map = {
        adsi: 'Adsi',
        rsat: 'Rsat',
        combined: 'Combined',
        csharp: 'Csharp'
    };
    return map[api] ?? 'Adsi';
}
/** Fields written to out/scan-<id>/scan.meta.json (must stay aligned with executeScan). */
function scanMetaSidecarFromApi(scanEngineBody) {
    const scanEngine = normalizeScanEngine(scanEngineBody);
    const ldapEngine = toPowerShellLdapEngine(scanEngine);
    const launchViaCmd = scanEngine === 'cmd';
    return { scanEngine, ldapEngine, launchViaCmd };
}
//# sourceMappingURL=scanEngineMapping.js.map