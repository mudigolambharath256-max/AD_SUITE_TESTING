/**
 * Vulnerability-style metadata for Phase B (non-curated). Not inventory text.
 */
const REF = {
  gen: [
    'https://learn.microsoft.com/windows-server/identity/ad-ds/plan/security-best-practices/appendix-a--sites',
    'MITRE ATT&CK — Enterprise (Windows)',
  ],
  kerb: [
    'https://learn.microsoft.com/windows-server/security/kerberos/kerberos-authentication-overview',
    'MITRE T1558 (Steal or Forge Kerberos Tickets)',
  ],
  ad: [
    'https://learn.microsoft.com/windows-server/identity/ad-ds/plan/security-best-practices/appendix-b--privileged-accounts-and-groups-in-active-directory',
    'MITRE T1078 (Valid Accounts)',
  ],
  trust: [
    'https://learn.microsoft.com/windows-server/identity/ad-ds/manage-security-best-practices/understanding-trust-relationships',
    'MITRE T1482',
  ],
  gpo: ['Group Policy (Microsoft Docs)', 'MITRE T1484.001 (Group Policy Modification)'],
  pki: ['AD CS / templates (LDAP view)', 'Microsoft PKI / AD CS hardening'],
  pwd: ['Password policy (Microsoft Docs)', 'MITRE T1110'],
  ldap: ['LDAP signing (Microsoft Docs)', 'MITRE T1040'],
  smb: ['SMB security (Microsoft Docs)', 'MITRE T1021.002'],
  compliance: ['CIS Microsoft Windows benchmarks', 'Organizational security baseline'],
  backup: ['Backup and restore (Microsoft Docs)', 'MITRE T1490'],
  persistence: ['MITRE T1098 (Account Manipulation)', 'Microsoft AD persistence'],
  infra: ['Windows Server security baseline', 'https://learn.microsoft.com/windows-server/'],
  laps: [
    'https://learn.microsoft.com/windows-server/security/credentials-protection-and-management/laps-scenarios',
    'MITRE T1552.006',
  ],
};

function getSyntheticMetadata(c) {
  const f = (c.ldapFilter || '').toLowerCase();
  const n = (c.name || '').toLowerCase();
  const cat = c.category || '';
  const nm = c.name || c.id;
  const desc = (d) =>
    d +
    ' Risk: each object returned is a security-relevant finding until remediated or formally accepted.';

  if (f.includes('4194304'))
    return {
      description: desc(
        'AS-REP roasting: Kerberos pre-authentication disabled — offline cracking of account passwords without a TGT.'
      ),
      remediation:
        'Enable pre-authentication on accounts; use strong passwords; avoid DONT_REQ_PREAUTH except rare documented exceptions.',
      references: REF.kerb,
    };
  if (f.includes('msds-keycredentiallink'))
    return {
      description: desc(
        'Shadow credentials: msDS-KeyCredentialLink can allow takeover without knowing the current password (WHfB / NTLM-less abuse).'
      ),
      remediation:
        'Restrict who can write KeyCredentialLink; audit keys on Tier0; remove unauthorized key credentials.',
      references: REF.ad,
    };
  if (f.includes('serviceprincipalname') && f.includes('objectclass=user'))
    return {
      description: desc(
        'Kerberoasting: user accounts with SPNs — ticket hashes can be cracked offline.'
      ),
      remediation: 'Remove user SPNs where possible; use gMSA; enforce strong passwords for SPN owners.',
      references: REF.kerb,
    };
  if (f.includes('524288') && f.includes('objectcategory=computer') && !f.includes('primarygroupid=516'))
    return {
      description: desc(
        'Unconstrained delegation on a non-DC computer — TGT theft and lateral movement to any service.'
      ),
      remediation:
        'Remove TRUSTED_FOR_DELEGATION from member servers; use constrained or RBCD; isolate Tier0-adjacent hosts.',
      references: REF.kerb,
    };
  if (f.includes('524288') && f.includes('objectcategory=person'))
    return {
      description: desc('Unconstrained delegation on a user — impersonation and credential theft across services.'),
      remediation: 'Remove unconstrained delegation from user accounts unless strictly required.',
      references: REF.kerb,
    };
  if (f.includes('16777216') || f.includes('trustedtoauth'))
    return {
      description: desc(
        'Protocol transition / S4U (TRUSTED_TO_AUTH_FOR_DELEGATION) — constrained delegation abuse (S4U2Self/S4U2Proxy).'
      ),
      remediation: 'Restrict msDS-AllowedToDelegateTo; remove unnecessary protocol transition; audit delegation.',
      references: REF.kerb,
    };
  if (f.includes('msds-allowedtodelegateto'))
    return {
      description: desc(
        'Constrained delegation: service may impersonate users to specific SPNs — path to privilege escalation.'
      ),
      remediation: 'Minimize SPN targets; remove stale delegation; prefer RBCD for resource servers.',
      references: REF.kerb,
    };
  if (f.includes('msds-allowedtoactonbehalfofotheridentity'))
    return {
      description: desc(
        'Resource-based constrained delegation (RBCD) — misconfiguration can allow impersonation to the resource.'
      ),
      remediation: 'Clear RBCD where not needed; scope principals; monitor changes to the attribute.',
      references: REF.kerb,
    };
  if (f.includes('2097152') || (f.includes('msds-supportedencryptiontypes') && f.includes(':=3)')))
    return {
      description: desc(
        'Weak Kerberos encryption (DES / DES-capable) — tickets are easier to crack.'
      ),
      remediation: 'Disable DES for Kerberos domain-wide; clear USE_DES_KEY_ONLY on accounts; upgrade legacy apps.',
      references: REF.kerb,
    };
  if (f.includes('admincount=1'))
    return {
      description: desc(
        'adminCount=1 (adminSDHolder-protected object) — persistence of elevated ACLs or legacy protected state.'
      ),
      remediation: 'Validate protection is intended; remove inappropriate adminCount; align with tiering model.',
      references: REF.ad,
    };
  if (f.includes('sidhistory'))
    return {
      description: desc(
        'SID History populated — migration artifact or malicious SID injection for privilege persistence.'
      ),
      remediation: 'Remove stale sIDHistory; investigate unexpected values; restrict writes to sIDHistory.',
      references: REF.ad,
    };
  if (f.includes('trusteddomain') || f.includes('trustpartner') || f.includes('crossref'))
    return {
      description: desc(`Trust or naming-context exposure: ${nm} — review for weak or unnecessary trust paths.`),
      remediation: 'Validate trust type and SID filtering; remove stale trusts; monitor changes.',
      references: REF.trust,
    };
  if (
    f.includes('grouppolicycontainer') ||
    f.includes('gplink') ||
    (cat === 'Group_Policy' && f.includes('grouppolicy'))
  )
    return {
      description: desc(`Group Policy: ${nm} — GPO or link may weaken security or enable persistence.`),
      remediation: 'Review GPO scope and SYSVOL ACLs; enforce change control; remove weak policies.',
      references: REF.gpo,
    };
  if (
    f.includes('samaccountname=domain admins') ||
    f.includes('samaccountname=enterprise admins') ||
    f.includes('samaccountname=schema admins')
  )
    return {
      description: desc(`Tier0 group: ${nm} — privileged membership must be minimal and monitored.`),
      remediation: 'Reduce membership; use PIM; alert on group changes.',
      references: REF.ad,
    };
  if (
    f.includes('samaccountname=') &&
    (f.includes('operators') || f.includes('admins') || f.includes('dnsadmins'))
  )
    return {
      description: desc(`Elevated built-in group: ${nm} — review members for privilege escalation paths.`),
      remediation: 'Least privilege; document exceptions; monitor membership.',
      references: REF.ad,
    };
  if (f.includes('psocreate') || f.includes('msds-pso') || f.includes('passwordpolicy'))
    return {
      description: desc(`Password policy: ${nm} — weak or misaligned settings increase credential risk.`),
      remediation: 'Align lockout and complexity; use PSOs for tiered accounts.',
      references: REF.pwd,
    };
  if (f.includes('pwdlastset') && f.includes('0'))
    return {
      description: desc(
        'Password-not-set or must-change patterns — stale or takeover-prone accounts.'
      ),
      remediation: 'Reset or disable unused accounts; enforce secure onboarding.',
      references: REF.pwd,
    };
  if (f.includes('65536') && f.includes('useraccountcontrol'))
    return {
      description: desc(
        'Password never expires — long-lived passwords increase reuse and offline cracking risk.'
      ),
      remediation: 'Remove on sensitive accounts; enforce rotation; use PSO exceptions sparingly.',
      references: REF.pwd,
    };
  if (f.includes('32') && f.includes('useraccountcontrol') && f.includes('person'))
    return {
      description: desc('PASSWD_NOT_REQD — account may allow blank or weak password.'),
      remediation: 'Require passwords; clear PASSWD_NOT_REQD.',
      references: REF.pwd,
    };
  if (n.includes('laps'))
    return {
      description: desc(`LAPS: ${nm} — local admin password hygiene and deployment coverage.`),
      remediation: 'Deploy LAPS broadly; remove duplicate local admins.',
      references: REF.laps,
    };
  if (n.includes('rodc') || f.includes('msds-rodcpolicy'))
    return {
      description: desc(`RODC: ${nm} — credential caching and replication security.`),
      remediation: 'Limit cached secrets; validate RODC allowed lists.',
      references: REF.kerb,
    };
  if (
    cat === 'PKI_Services' ||
    f.includes('pki') ||
    f.includes('certificatetemplate') ||
    f.includes('ntsecuritydescriptor')
  )
    return {
      description: desc(
        `PKI (LDAP): ${nm} — template or ACL data may enable certificate-based abuse; review with PKI owners.`
      ),
      remediation: 'Review enrollment and template ACLs; disable weak or unused templates.',
      references: REF.pki,
    };
  if (cat === 'SMB_Security' || n.includes('smb'))
    return {
      description: desc(`SMB: ${nm} — signing, encryption, or share exposure risk.`),
      remediation: 'Enforce SMB signing; disable SMBv1; restrict shares.',
      references: REF.smb,
    };
  if (cat === 'Network_Security' || n.includes('firewall') || n.includes('port'))
    return {
      description: desc(`Network: ${nm} — unnecessary exposure or weak segmentation.`),
      remediation: 'Segment; restrict ports; validate DC firewall rules.',
      references: REF.gen,
    };
  if (cat === 'LDAP_Security' || n.includes('ldap') || n.includes('simple bind'))
    return {
      description: desc(`LDAP: ${nm} — unsigned or cleartext LDAP risk.`),
      remediation: 'Require LDAP signing and TLS; disable simple bind.',
      references: REF.ldap,
    };
  if (cat === 'Compliance')
    return {
      description: desc(`Compliance: ${nm} — control drift or baseline gap.`),
      remediation: 'Remediate to baseline; document waivers.',
      references: REF.compliance,
    };
  if (cat === 'Persistence_Detection' || n.includes('persistence'))
    return {
      description: desc(`Persistence: ${nm} — risky admin practice or attacker persistence indicator.`),
      remediation: 'Investigate; remove unauthorized persistence.',
      references: REF.persistence,
    };
  if (cat === 'Backup_Recovery' || n.includes('backup'))
    return {
      description: desc(`Backup: ${nm} — recovery or backup-credential exposure risk.`),
      remediation: 'Protect backup paths and operators; test restores.',
      references: REF.backup,
    };
  if (cat === 'Published_Resources' || n.includes('dfs') || n.includes('share'))
    return {
      description: desc(`Published resource: ${nm} — excessive permissions or data exposure.`),
      remediation: 'Tighten ACLs; remove anonymous access.',
      references: REF.gen,
    };
  if (cat === 'Infrastructure' || n.includes('time') || n.includes('ntp') || n.includes('dns'))
    return {
      description: desc(`Infrastructure: ${nm} — DNS, time, or core service misconfiguration.`),
      remediation: 'Sync time; secure DNS; validate SRV records.',
      references: REF.infra,
    };
  if (cat === 'Service_Accounts' || n.includes('service account'))
    return {
      description: desc(`Service account: ${nm} — interactive or over-privileged service logon risk.`),
      remediation: 'Prefer gMSA; deny interactive logon; least privilege.',
      references: REF.ad,
    };
  if (cat === 'Users_Accounts')
    return {
      description: desc(`User accounts: ${nm} — dormant accounts, weak settings, or excessive rights.`),
      remediation: 'Disable unused users; MFA for admins; least privilege.',
      references: REF.ad,
    };
  if (cat === 'Authentication')
    return {
      description: desc(`Authentication: ${nm} — weak policies or legacy authentication mechanisms.`),
      remediation: 'Strong authentication; disable legacy protocols where possible.',
      references: REF.pwd,
    };
  if (cat === 'Computer_Management' || cat === 'Computers_Servers')
    return {
      description: desc(`Computer/server: ${nm} — patching, local admin, or tiering issues.`),
      remediation: 'Security baselines; reduce local admin sprawl; tier separation.',
      references: REF.gen,
    };
  if (cat === 'Domain_Controllers' || cat === 'Domain_Configuration')
    return {
      description: desc(`Domain or forest configuration: ${nm} — domain-wide security impact.`),
      remediation: 'AD security baseline; protect Tier0; validate FSMO and functional levels.',
      references: REF.ad,
    };
  if (cat === 'Trust_Management' || cat === 'Trust_Relationships')
    return {
      description: desc(`Trust: ${nm} — cross-forest or external trust abuse risk.`),
      remediation: 'Selective authentication; SID filtering; remove stale trusts.',
      references: REF.trust,
    };
  if (cat === 'Security_Accounts' || cat === 'Privileged_Access')
    return {
      description: desc(`Privileged access: ${nm} — standing privilege or stale access.`),
      remediation: 'PIM; JIT; PAWS; minimal standing admin.',
      references: REF.ad,
    };
  if (cat === 'Advanced_Security')
    return {
      description: desc(`Advanced control: ${nm} — policy or detection gap.`),
      remediation: 'Align with baselines and threat intelligence.',
      references: REF.gen,
    };
  if (cat === 'Access_Control')
    return {
      description: desc(`Access control: ${nm} — ACL or delegation misconfiguration.`),
      remediation: 'Least privilege; review ACLs and OU delegation.',
      references: REF.ad,
    };
  if (cat === 'Kerberos_Security')
    return {
      description: desc(`Kerberos: ${nm} — ticket, encryption, or delegation weakness.`),
      remediation: 'Kerberos hardening; delegation review.',
      references: REF.kerb,
    };

  return {
    description: desc(
      `Security finding: ${nm} — LDAP rule matches objects that may indicate misconfiguration or abuse.`
    ),
    remediation: `Validate ${nm}: remediate unnecessary exposure or document accepted risk with owners.`,
    references: REF.gen,
  };
}

module.exports = { getSyntheticMetadata, REF };
