/**
 * Validates scan engine API → scan.meta.json / -LdapEngine mapping (no network, no AD).
 * Run: npm run test:scan-engine --prefix AD-Suite-Web/backend
 */
import assert from 'assert';
import {
    normalizeScanEngine,
    scanMetaSidecarFromApi,
    toPowerShellLdapEngine,
    type ScanEngineApi
} from './scanEngineMapping';

const cases: { raw: unknown; scanEngine: ScanEngineApi; ldap: string; cmd: boolean }[] = [
    { raw: 'adsi', scanEngine: 'adsi', ldap: 'Adsi', cmd: false },
    { raw: 'ADSI', scanEngine: 'adsi', ldap: 'Adsi', cmd: false },
    { raw: 'rsat', scanEngine: 'rsat', ldap: 'Rsat', cmd: false },
    { raw: 'combined', scanEngine: 'combined', ldap: 'Combined', cmd: false },
    { raw: 'csharp', scanEngine: 'csharp', ldap: 'Csharp', cmd: false },
    { raw: 'cmd', scanEngine: 'cmd', ldap: 'Adsi', cmd: true },
    { raw: '', scanEngine: 'adsi', ldap: 'Adsi', cmd: false },
    { raw: 'bogus', scanEngine: 'adsi', ldap: 'Adsi', cmd: false },
    { raw: null, scanEngine: 'adsi', ldap: 'Adsi', cmd: false }
];

for (const row of cases) {
    assert.strictEqual(normalizeScanEngine(row.raw), row.scanEngine, `normalize(${JSON.stringify(row.raw)})`);
    assert.strictEqual(toPowerShellLdapEngine(row.scanEngine), row.ldap, `ldap(${row.scanEngine})`);
    const meta = scanMetaSidecarFromApi(row.raw);
    assert.strictEqual(meta.scanEngine, row.scanEngine);
    assert.strictEqual(meta.ldapEngine, row.ldap);
    assert.strictEqual(meta.launchViaCmd, row.cmd, `launchViaCmd for ${JSON.stringify(row.raw)}`);
}

console.log(`scanEngineMapping.selftest: OK (${cases.length} cases)`);
