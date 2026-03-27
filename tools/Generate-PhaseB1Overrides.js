/**
 * Builds checks.overrides.phaseB1.json from checks.generated.json + checks.json (curated).
 * Wave B1: Kerberos_Security + Access_Control (71 checks).
 *
 * Usage: node tools/Generate-PhaseB1Overrides.js
 */
const fs = require('fs');
const path = require('path');

const root = path.join(__dirname, '..');
const genPath = path.join(root, 'checks.generated.json');
const curPath = path.join(root, 'checks.json');
const outPath = path.join(root, 'checks.overrides.phaseB1.json');

const gen = JSON.parse(fs.readFileSync(genPath, 'utf8'));
const cur = JSON.parse(fs.readFileSync(curPath, 'utf8'));
const curMap = Object.fromEntries(cur.checks.map((c) => [c.id, c]));
const cats = new Set(['Kerberos_Security', 'Access_Control']);

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
  return 'medium';
}

const genericRefs = [
  'https://learn.microsoft.com/windows-server/identity/ad-ds/plan/security-best-practices/appendix-a--sites',
  'MITRE ATT&CK — Credential Access (T1558)',
];

const out = [];
for (const c of gen.checks) {
  if (!cats.has(c.category)) continue;
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
    o.remediation = `Review and remediate ${c.name} per org baseline: tighten AD attributes, remove unnecessary delegation or weak crypto, and validate with domain owners.`;
    o.references = genericRefs;
  }
  out.push(o);
}

const doc = {
  schemaVersion: 1,
  meta: {
    phase: 'B1',
    waves: ['Kerberos_Security', 'Access_Control'],
    generatedFrom: path.basename(genPath),
    curatedFrom: path.basename(curPath),
  },
  checks: out,
};
fs.writeFileSync(outPath, JSON.stringify(doc, null, 2) + '\n', 'utf8');
console.log('Wrote', outPath, 'with', out.length, 'overrides');
