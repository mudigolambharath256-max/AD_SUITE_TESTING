/**
 * Shared logic for Phase B promotion overrides (LDAP-first; excludes CERT/Azure).
 */
const fs = require('fs');
const path = require('path');

const EXCLUDED_PHASE_B_CATEGORIES = new Set(['Certificate_Services', 'Azure_AD_Integration']);

const GENERIC_REFS = [
  'https://learn.microsoft.com/windows-server/identity/ad-ds/plan/security-best-practices/appendix-a--sites',
  'MITRE ATT&CK — Enterprise (Windows)',
];

function guessSeverity(c) {
  const f = (c.ldapFilter || '').toLowerCase();
  const n = (c.name || '').toLowerCase();
  if (f.includes('4194304')) return 'critical';
  if (f.includes('16777216') || f.includes('trustedtoauth')) return 'high';
  if (f.includes('524288') && f.includes('objectcategory=computer') && !f.includes('primarygroupid=516'))
    return 'critical';
  if (f.includes('524288') && f.includes('objectcategory=person')) return 'critical';
  if (f.includes('msds-keycredentiallink')) return 'high';
  if (f.includes('serviceprincipalname') || n.includes('kerberoast')) return 'high';
  if (f.includes('2097152') || n.includes('des-only')) return 'high';
  if (
    f.includes('msds-allowedtodelegateto') ||
    f.includes('allowedtoactonbehalfofotheridentity') ||
    f.includes('delegation')
  )
    return 'high';
  if (f.includes('admincount=1')) return 'high';
  if (f.includes('65536') && f.includes('useraccountcontrol')) return 'high';
  if (f.includes('32') && f.includes('useraccountcontrol') && f.includes('person')) return 'high';
  if (n.includes('password') && (n.includes('never') || n.includes('expir'))) return 'high';
  if (n.includes('pre-auth') || n.includes('preauth')) return 'critical';
  if (n.includes('domain admin') || n.includes('schema admin') || n.includes('enterprise admin'))
    return 'high';
  return 'medium';
}

function buildOverrideForCheck(c, curMap) {
  const ch = curMap[c.id];
  const o = { id: c.id, engine: 'ldap' };
  if (ch) {
    if (ch.severity) o.severity = ch.severity;
    if (ch.description) o.description = ch.description;
    if (ch.remediation) o.remediation = ch.remediation;
    if (ch.references) o.references = ch.references;
    if (ch.scoreWeight !== undefined && ch.scoreWeight !== null) o.scoreWeight = ch.scoreWeight;
    if (ch.excludeSamAccountName) o.excludeSamAccountName = ch.excludeSamAccountName;
  } else {
    o.severity = guessSeverity(c);
    o.description = `Misconfiguration or exposure: ${c.name}. Each returned object matches the LDAP rule; review for business justification and false positives.`;
    o.remediation = `Review and remediate ${c.name} per org baseline: align with tiering, least privilege, and Microsoft AD security guidance; validate with domain owners.`;
    o.references = GENERIC_REFS;
  }
  return o;
}

function generateOverrides(options) {
  const root = options.root;
  const genPath = path.join(root, 'checks.generated.json');
  const curPath = path.join(root, 'checks.json');
  const gen = JSON.parse(fs.readFileSync(genPath, 'utf8'));
  const cur = JSON.parse(fs.readFileSync(curPath, 'utf8'));
  const curMap = Object.fromEntries(cur.checks.map((x) => [x.id, x]));
  const catSet = options.categories;

  const out = [];
  for (const c of gen.checks) {
    if (EXCLUDED_PHASE_B_CATEGORIES.has(c.category)) continue;
    if (catSet && !catSet.has(c.category)) continue;
    out.push(buildOverrideForCheck(c, curMap));
  }

  const doc = {
    schemaVersion: 1,
    meta: {
      generatedFrom: path.basename(genPath),
      curatedFrom: path.basename(curPath),
      excludedCategories: [...EXCLUDED_PHASE_B_CATEGORIES],
      ...options.metaExtra,
    },
    checks: out,
  };
  fs.writeFileSync(options.outPath, JSON.stringify(doc, null, 2) + '\n', 'utf8');
  return out.length;
}

module.exports = {
  EXCLUDED_PHASE_B_CATEGORIES,
  guessSeverity,
  buildOverrideForCheck,
  generateOverrides,
};
