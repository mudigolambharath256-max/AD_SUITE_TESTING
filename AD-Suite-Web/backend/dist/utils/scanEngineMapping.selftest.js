"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
/**
 * Validates scan engine API → scan.meta.json / -LdapEngine mapping (no network, no AD).
 * Run: npm run test:scan-engine --prefix AD-Suite-Web/backend
 */
const assert_1 = __importDefault(require("assert"));
const scanEngineMapping_1 = require("./scanEngineMapping");
const cases = [
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
    assert_1.default.strictEqual((0, scanEngineMapping_1.normalizeScanEngine)(row.raw), row.scanEngine, `normalize(${JSON.stringify(row.raw)})`);
    assert_1.default.strictEqual((0, scanEngineMapping_1.toPowerShellLdapEngine)(row.scanEngine), row.ldap, `ldap(${row.scanEngine})`);
    const meta = (0, scanEngineMapping_1.scanMetaSidecarFromApi)(row.raw);
    assert_1.default.strictEqual(meta.scanEngine, row.scanEngine);
    assert_1.default.strictEqual(meta.ldapEngine, row.ldap);
    assert_1.default.strictEqual(meta.launchViaCmd, row.cmd, `launchViaCmd for ${JSON.stringify(row.raw)}`);
}
console.log(`scanEngineMapping.selftest: OK (${cases.length} cases)`);
//# sourceMappingURL=scanEngineMapping.selftest.js.map