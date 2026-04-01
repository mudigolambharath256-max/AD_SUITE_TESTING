'use strict';
/**
 * Option A: Compare check titles/descriptions (registry-like / machine-policy wording)
 * to actual engine + ldapFilter implementation in checks.unified.json.
 *
 * Usage: node tools/Audit-CheckSemantics.js
 * Writes: docs/check-semantics-audit.json and docs/CHECK_SEMANTICS_AUDIT.md
 */
const fs = require('fs');
const path = require('path');

const root = path.join(__dirname, '..');
const catalogPath = path.join(root, 'checks.unified.json');
const outJson = path.join(root, 'docs', 'check-semantics-audit.json');
const outMd = path.join(root, 'docs', 'CHECK_SEMANTICS_AUDIT.md');

/** Filters that enumerate objects but do not encode the named machine policy in LDAP. */
const FILTER_CLASS = {
    DC_COMPUTERS:
        '(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192))',
    DOMAIN_OBJECT: '(objectClass=domain)',
    NTDS_SETTINGS: '(objectClass=nTDSDSA)',
    ALL_COMPUTERS_NOT_DISABLED: '(&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))'
};

const POLICY_KEYWORDS = [
    { re: /\bSMB\s*signing|SMBv1|SMB\s*Encryption|LanMan/i, tag: 'SMB / LanMan policy' },
    { re: /\bLDAP\s*signing|LDAP\s*Channel|channel\s*binding/i, tag: 'LDAP signing / channel binding' },
    { re: /\bNTLM|LmCompatibility|LM\s*Hash|LM\s*Compatibility/i, tag: 'NTLM / LM policy' },
    { re: /\bOpen\s*Ports?|port\s*scan|firewall/i, tag: 'Network ports / firewall' },
    { re: /\btime\s*sync|NTP|w32tm|Secure\s*Time/i, tag: 'Time / NTP' },
    { re: /\bWMI\b/i, tag: 'WMI' },
    { re: /\bregistry|Remote\s*Registry/i, tag: 'Registry (stated)' },
    { re: /\bRDP\b|Remote\s*Desktop/i, tag: 'RDP' },
    { re: /\bAudit\s*Policy|auditing/i, tag: 'Audit policy' },
    { re: /\bSecurity\s*Updates?|patch|MSRC/i, tag: 'Patching / updates' },
    { re: /\bNull\s*Session/i, tag: 'Null session' },
    { re: /\bDNS\s*Config|insecure\s*DNS/i, tag: 'DNS' },
    { re: /\bshare\s*permission|insecure\s*share/i, tag: 'Share permissions' },
    { re: /\bunsigned\s*drivers/i, tag: 'Drivers policy' },
    { re: /\bKerberos\s*Ticket|Renewal\s*Lifetime/i, tag: 'Kerberos lifetime (GPO/registry)' }
];

function normFilter(f) {
    if (f == null) {
        return '';
    }
    return String(f).replace(/\s+/g, '');
}

function classifyFilter(f) {
    const n = normFilter(f);
    if (n === normFilter(FILTER_CLASS.DC_COMPUTERS)) {
        return 'DC_COMPUTERS';
    }
    if (n === normFilter(FILTER_CLASS.DOMAIN_OBJECT)) {
        return 'DOMAIN_OBJECT';
    }
    if (n === normFilter(FILTER_CLASS.NTDS_SETTINGS)) {
        return 'NTDS_SETTINGS';
    }
    if (n === normFilter(FILTER_CLASS.ALL_COMPUTERS_NOT_DISABLED)) {
        return 'ALL_COMPUTERS_NOT_DISABLED';
    }
    return 'OTHER';
}

function main() {
    if (!fs.existsSync(catalogPath)) {
        console.error('Missing', catalogPath);
        process.exit(1);
    }

    const doc = JSON.parse(fs.readFileSync(catalogPath, 'utf8'));
    const checks = Array.isArray(doc.checks) ? doc.checks : [];

    const byNormalizedFilter = new Map();
    const rows = [];

    for (const c of checks) {
        const engine = (c.engine || 'ldap').toLowerCase();
        const id = String(c.id ?? '');
        const name = String(c.name ?? '');
        const description = String(c.description ?? '');
        const text = `${name}\n${description}`;
        const lf = normFilter(c.ldapFilter);
        const fc = classifyFilter(c.ldapFilter);

        if (!byNormalizedFilter.has(lf)) {
            byNormalizedFilter.set(lf, []);
        }
        byNormalizedFilter.get(lf).push({ id, name, engine });

        const keywordHits = [];
        for (const { re, tag } of POLICY_KEYWORDS) {
            if (re.test(text)) {
                keywordHits.push(tag);
            }
        }

        let mismatch = null;
        if (c.semanticsAuditExclude === true) {
            mismatch = null;
        } else if (
            engine === 'ldap' &&
            fc === 'DOMAIN_OBJECT' &&
            (c.ldapFindingCondition || c.complianceRuleSet)
        ) {
            // Domain row is used with attribute evaluation — filter class alone is not misleading.
            mismatch = null;
        } else if (engine === 'ldap' && keywordHits.length) {
            if (
                fc === 'DC_COMPUTERS' &&
                keywordHits.some((k) =>
                    /SMB|LDAP signing|NTLM|port|Time|WMI|registry|RDP|Audit|patch|DNS|share|driver|Kerberos/i.test(k)
                )
            ) {
                mismatch = 'title_implies_machine_policy_but_filter_is_only_dc_enumeration';
            } else if (
                fc === 'DOMAIN_OBJECT' &&
                keywordHits.some((k) =>
                    /SMB|LDAP signing|NTLM|LM|Null session|Kerberos/i.test(k)
                )
            ) {
                mismatch = 'title_implies_domain_policy_but_filter_is_only_domain_object_listing';
            } else if (fc === 'NTDS_SETTINGS' && keywordHits.some((k) => /LDAP signing|channel binding/i.test(k))) {
                mismatch = 'title_implies_ldap_signing_but_filter_is_only_ntdsdsa_listing';
            } else if (fc === 'ALL_COMPUTERS_NOT_DISABLED' && keywordHits.some((k) => /SMB/i.test(k))) {
                mismatch = 'title_implies_smb_policy_but_filter_is_all_non_disabled_computers';
            }
        }

        rows.push({
            id,
            name,
            engine,
            filterClass: fc,
            ldapFilter: c.ldapFilter || null,
            keywordHits,
            mismatch
        });
    }

    const duplicateFilters = [];
    for (const [nf, list] of byNormalizedFilter) {
        if (list.length > 1 && nf.length > 0) {
            const names = new Set(list.map((x) => x.name));
            duplicateFilters.push({
                normalizedFilter: nf,
                count: list.length,
                distinctNames: names.size,
                checks: list.sort((a, b) => a.id.localeCompare(b.id))
            });
        }
    }
    duplicateFilters.sort((a, b) => b.count - a.count);

    const mismatches = rows.filter((r) => r.mismatch);
    const keywordOnly = rows.filter((r) => r.keywordHits.length && !r.mismatch && r.engine === 'ldap');

    const report = {
        catalogPath: 'checks.unified.json',
        generatedAtUtc: new Date().toISOString(),
        totalChecks: checks.length,
        summary: {
            ldapChecks: rows.filter((r) => r.engine === 'ldap').length,
            rowsWithPolicyKeywords: rows.filter((r) => r.keywordHits.length).length,
            flaggedSemanticMismatches: mismatches.length,
            duplicateFilterGroups: duplicateFilters.length
        },
        mismatches,
        duplicateFilters,
        keywordHitsWithoutAutoFlag: keywordOnly.slice(0, 200)
    };

    fs.mkdirSync(path.dirname(outJson), { recursive: true });
    fs.writeFileSync(outJson, JSON.stringify(report, null, 2) + '\n', 'utf8');

    const md = [];
    md.push('# Check semantics audit (title vs implementation)');
    md.push('');
    md.push('Generated by `node tools/Audit-CheckSemantics.js` from `checks.unified.json`.');
    md.push('');
    md.push('## What this is');
    md.push('');
    md.push(
        'Some check **names** describe **machine policy** (SMB signing, LDAP signing, NTLM, ports, WMI, time sync) that typically lives in **registry**, **GPO INF**, or **network probes** — not in a simple LDAP object listing. This scan flags **likely** mismatches where the catalog still uses a **generic** `ldapFilter` (e.g. all DCs, or `(objectClass=domain)` only) so results **do not prove** the title.'
    );
    md.push('');
    md.push('## Summary');
    md.push('');
    md.push(`| Metric | Value |`);
    md.push(`|--------|-------|`);
    md.push(`| Total checks | ${report.totalChecks} |`);
    md.push(`| LDAP checks | ${report.summary.ldapChecks} |`);
    md.push(`| Checks matching policy keyword heuristics | ${report.summary.rowsWithPolicyKeywords} |`);
    md.push(`| **Flagged semantic mismatches** | **${report.summary.flaggedSemanticMismatches}** |`);
    md.push(`| Distinct \`ldapFilter\` values used by >1 check | ${report.summary.duplicateFilterGroups} |`);
    md.push('');

    md.push('## Flagged checks (review first)');
    md.push('');
    md.push('| Id | Name | Filter class | Issue |');
    md.push('|----|------|--------------|-------|');
    for (const m of mismatches.sort((a, b) => a.id.localeCompare(b.id))) {
        const issue = m.mismatch.replace(/_/g, ' ');
        md.push(`| ${m.id} | ${m.name.replace(/\|/g, '\\|')} | ${m.filterClass} | ${issue} |`);
    }
    md.push('');

    md.push('## Largest duplicate-filter groups');
    md.push('');
    md.push(
        'Multiple different titles sharing the **same** `ldapFilter` often means the scan cannot distinguish them; several are **DC enumeration** (`userAccountControl` server flag 8192).'
    );
    md.push('');
    for (const g of duplicateFilters.slice(0, 15)) {
        md.push(`### ${g.count} checks — filter \`${g.normalizedFilter.slice(0, 120)}${g.normalizedFilter.length > 120 ? '…' : ''}\``);
        md.push('');
        md.push('| Id | Name |');
        md.push('|----|------|');
        for (const x of g.checks.slice(0, 40)) {
            md.push(`| ${x.id} | ${String(x.name).replace(/\|/g, '\\|')} |`);
        }
        if (g.checks.length > 40) {
            md.push(`| … | *${g.checks.length - 40} more* |`);
        }
        md.push('');
    }

    md.push('## Next steps (Option B later)');
    md.push('');
    md.push(
        '- Replace misleading titles with honest ones (“DC inventory”) **or** implement **SYSVOL GPO parsing**, **filesystem** checks, or **documented** non-LDAP probes where appropriate.'
    );
    md.push('');

    fs.writeFileSync(outMd, md.join('\n'), 'utf8');
    console.log('Wrote', outJson);
    console.log('Wrote', outMd);
    console.log('Flagged mismatches:', mismatches.length);
}

main();
