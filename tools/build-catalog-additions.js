'use strict';
/**
 * Writes checks.catalog-additions.json (plan overlay). Run: node tools/build-catalog-additions.js
 */
const fs = require('fs');
const path = require('path');

const root = path.join(__dirname, '..');
const out = path.join(root, 'checks.catalog-additions.json');

const machineQuota = {
    id: 'ACC-025',
    name: 'Users Can Add Computers to Domain',
    category: 'Access_Control',
    engine: 'ldap',
    searchBase: 'Domain',
    searchScope: 'Subtree',
    ldapFilter: '(objectClass=domain)',
    propertiesToLoad: ['name', 'distinguishedName', 'ms-DS-MachineAccountQuota'],
    ldapFindingCondition: { attribute: 'ms-DS-MachineAccountQuota', operator: 'gt', compare: 0 },
    severity: 'medium',
    description:
        'Domain ms-DS-MachineAccountQuota greater than 0 allows non-admin users to create computer accounts (NTLM relay / machine account abuse). Evaluated from LDAP attribute.',
    remediation: 'Set ms-DS-MachineAccountQuota to 0 unless business-approved.',
    references: ['https://learn.microsoft.com/windows-server/identity/ad-ds/plan/security-best-practices/']
};

const checks = [
    machineQuota,
    {
        ...machineQuota,
        id: 'ADV-008',
        name: 'Machine Account Quota Abuse',
        category: 'Advanced_Security'
    },
    {
        ...machineQuota,
        id: 'DCONF-003',
        name: 'ms-DS-MachineAccountQuota Setting',
        category: 'Domain_Configuration'
    },
    {
        id: 'DCONF-001',
        name: 'Kerberos Encryption Types Domain',
        category: 'Domain_Configuration',
        engine: 'ldap',
        searchBase: 'Domain',
        searchScope: 'Subtree',
        ldapFilter: '(objectClass=domain)',
        propertiesToLoad: ['name', 'distinguishedName', 'msDS-SupportedEncryptionTypes'],
        ldapFindingCondition: { attribute: 'msDS-SupportedEncryptionTypes', operator: 'bitAndNonZero', compare: 4 },
        severity: 'medium',
        description:
            'Finding when RC4 (0x4) remains enabled in msDS-SupportedEncryptionTypes; prefer AES-only Kerberos where supported.',
        remediation: 'Disable RC4 for Kerberos where compatible with legacy apps.',
        references: ['https://learn.microsoft.com/windows-server/security/kerberos/kerberos-encryption-types']
    },
    {
        id: 'DCONF-004',
        name: 'Default Domain Password Policy',
        category: 'Domain_Configuration',
        engine: 'ldap',
        searchBase: 'Domain',
        searchScope: 'Subtree',
        ldapFilter: '(objectClass=domain)',
        propertiesToLoad: [
            'name',
            'distinguishedName',
            'minPwdLength',
            'pwdHistoryLength',
            'lockoutThreshold',
            'maxPwdAge',
            'minPwdAge',
            'pwdProperties'
        ],
        ldapFindingCondition: { attribute: 'minPwdLength', operator: 'lt', compare: 14 },
        severity: 'medium',
        description: 'Default domain policy: finding when minPwdLength is below 14 (adjust threshold in catalog if needed).',
        remediation: 'Harden default domain password policy per organizational baseline.',
        references: ['https://learn.microsoft.com/windows-server/identity/ad-ds/plan/security-best-practices/']
    },
    {
        id: 'DCONF-017',
        name: 'DC Lockout Threshold',
        category: 'Domain_Configuration',
        engine: 'ldap',
        searchBase: 'Domain',
        searchScope: 'Subtree',
        ldapFilter: '(objectClass=domain)',
        propertiesToLoad: ['name', 'distinguishedName', 'lockoutThreshold'],
        ldapFindingCondition: { attribute: 'lockoutThreshold', operator: 'eq', compare: 0 },
        severity: 'high',
        description: 'Account lockout disabled (lockoutThreshold=0) enables brute-force guessing.',
        remediation: 'Enable account lockout with organizational thresholds.',
        references: ['https://learn.microsoft.com/windows-server/identity/ad-ds/plan/security-best-practices/']
    },
    {
        id: 'DCONF-020',
        name: 'Min Password Length',
        category: 'Domain_Configuration',
        engine: 'ldap',
        searchBase: 'Domain',
        searchScope: 'Subtree',
        ldapFilter: '(objectClass=domain)',
        propertiesToLoad: ['name', 'distinguishedName', 'minPwdLength'],
        ldapFindingCondition: { attribute: 'minPwdLength', operator: 'lt', compare: 14 },
        severity: 'medium',
        description: 'Minimum password length below 14 characters.',
        remediation: 'Increase minPwdLength per baseline.',
        references: ['https://learn.microsoft.com/windows-server/identity/ad-ds/plan/security-best-practices/']
    },
    {
        id: 'DCONF-021',
        name: 'Password Complexity',
        category: 'Domain_Configuration',
        engine: 'ldap',
        searchBase: 'Domain',
        searchScope: 'Subtree',
        ldapFilter: '(objectClass=domain)',
        propertiesToLoad: ['name', 'distinguishedName', 'pwdProperties'],
        ldapFindingCondition: { attribute: 'pwdProperties', operator: 'bitAndZero', compare: 1 },
        severity: 'medium',
        description:
            'Finding when DOMAIN_PASSWORD_COMPLEX (bit 1) is not set in pwdProperties.',
        remediation: 'Enable password complexity in default domain policy.',
        references: ['https://learn.microsoft.com/windows-server/identity/ad-ds/plan/security-best-practices/']
    },
    {
        id: 'DCONF-022',
        name: 'Password History',
        category: 'Domain_Configuration',
        engine: 'ldap',
        searchBase: 'Domain',
        searchScope: 'Subtree',
        ldapFilter: '(objectClass=domain)',
        propertiesToLoad: ['name', 'distinguishedName', 'pwdHistoryLength'],
        ldapFindingCondition: { attribute: 'pwdHistoryLength', operator: 'lt', compare: 24 },
        severity: 'medium',
        description: 'Password history length below 24 (common STIG/CIS target).',
        remediation: 'Increase pwdHistoryLength.',
        references: ['https://learn.microsoft.com/windows-server/identity/ad-ds/plan/security-best-practices/']
    },
    {
        id: 'DCONF-023',
        name: 'Max Password Age',
        category: 'Domain_Configuration',
        engine: 'ldap',
        searchBase: 'Domain',
        searchScope: 'Subtree',
        ldapFilter: '(objectClass=domain)',
        propertiesToLoad: ['name', 'distinguishedName', 'maxPwdAge'],
        ldapFindingCondition: { attribute: 'maxPwdAge', operator: 'maxpwdageneverisweak', compare: 0 },
        severity: 'medium',
        description: 'maxPwdAge indicates passwords never expire (weak).',
        remediation: 'Set maximum password age per baseline.',
        references: ['https://learn.microsoft.com/windows-server/identity/ad-ds/plan/security-best-practices/']
    },
    {
        id: 'DCONF-024',
        name: 'Min Password Age',
        category: 'Domain_Configuration',
        engine: 'ldap',
        searchBase: 'Domain',
        searchScope: 'Subtree',
        ldapFilter: '(objectClass=domain)',
        propertiesToLoad: ['name', 'distinguishedName', 'minPwdAge'],
        ldapFindingCondition: { attribute: 'minPwdAge', operator: 'eq', compare: 0 },
        severity: 'low',
        description: 'minPwdAge of 0 allows immediate password changes (rotation abuse).',
        remediation: 'Set minimum password age > 0 where appropriate.',
        references: ['https://learn.microsoft.com/windows-server/identity/ad-ds/plan/security-best-practices/']
    },
    {
        id: 'DCONF-025',
        name: 'Reversible Encryption',
        category: 'Domain_Configuration',
        engine: 'ldap',
        searchBase: 'Domain',
        searchScope: 'Subtree',
        ldapFilter: '(objectClass=domain)',
        propertiesToLoad: ['name', 'distinguishedName', 'pwdProperties'],
        ldapFindingCondition: { attribute: 'pwdProperties', operator: 'bitAndNonZero', compare: 128 },
        severity: 'high',
        description: 'DOMAIN_PASSWORD_REVERSE_ENCRYPTED (0x80) enabled at domain — reversible encryption.',
        remediation: 'Disable reversible encryption in domain policy unless legacy app requires it.',
        references: ['https://learn.microsoft.com/windows-server/identity/ad-ds/plan/security-best-practices/']
    },
    {
        id: 'BCK-003',
        name: 'Tombstone Lifetime Check',
        category: 'Backup_Recovery',
        engine: 'ldap',
        searchBase: 'Configuration',
        searchScope: 'Subtree',
        ldapFilter: '(cn=Directory Service)',
        propertiesToLoad: ['name', 'distinguishedName', 'tombstoneLifetime'],
        ldapFindingCondition: { attribute: 'tombstoneLifetime', operator: 'lt', compare: 90 },
        severity: 'medium',
        description: 'Tombstone lifetime below 90 days may reduce recovery window (organizational tuning).',
        remediation: 'Align tombstoneLifetime with business recovery requirements.',
        references: ['https://learn.microsoft.com/windows-server/identity/ad-ds/plan/active-directory-forest-recovery-introduction']
    },
    {
        id: 'BCK-004',
        name: 'Deleted Object Recovery Capability',
        category: 'Backup_Recovery',
        engine: 'ldap',
        searchBase: 'Configuration',
        searchScope: 'Subtree',
        ldapFilter: '(cn=Directory Service)',
        propertiesToLoad: ['name', 'distinguishedName', 'msDS-DeletedObjectLifetime', 'tombstoneLifetime'],
        ldapFindingCondition: { attribute: 'msDS-DeletedObjectLifetime', operator: 'lt', compare: 180 },
        severity: 'medium',
        description: 'msDS-DeletedObjectLifetime below 180 days (example SLA) — tune compare value for your org.',
        remediation: 'Set deleted object lifetime appropriate to recovery SLAs.',
        references: ['https://learn.microsoft.com/windows-server/identity/ad-ds/get-started/adac/introduction-to-active-directory-administrative-center-enhancements--level-100-']
    },
    {
        id: 'BCK-005',
        name: 'AD Recycle Bin Status',
        category: 'Backup_Recovery',
        engine: 'ldap',
        searchBase: 'Domain',
        searchScope: 'Subtree',
        ldapFilter: '(&(objectClass=msDS-EnabledFeature)(cn=Recycle Bin Feature))',
        propertiesToLoad: ['name', 'distinguishedName', 'msDS-EnabledFeatureFlags'],
        ldapEmptyResultIsFinding: true,
        severity: 'high',
        description: 'AD Recycle Bin optional feature not present — deleted object restore unavailable.',
        remediation: 'Enable AD Recycle Bin in forest (irreversible; plan change window).',
        references: ['https://learn.microsoft.com/windows-server/identity/ad-ds/get-started/adac/introduction-to-active-directory-administrative-center-enhancements--level-100-']
    },
    {
        id: 'COMPLY-008',
        name: 'Account Lockout Policy Compliance',
        category: 'Compliance',
        engine: 'ldap',
        searchBase: 'Domain',
        searchScope: 'Subtree',
        ldapFilter: '(objectClass=domainDNS)',
        propertiesToLoad: ['name', 'distinguishedName', 'lockoutThreshold'],
        ldapFindingCondition: { attribute: 'lockoutThreshold', operator: 'lt', compare: 3 },
        severity: 'medium',
        description: 'Lockout threshold below 3 failed attempts (example STIG-style check).',
        remediation: 'Tune lockoutThreshold per baseline.',
        references: ['CIS / STIG password policy']
    },
    {
        id: 'COMPLY-009',
        name: 'Minimum Password Age Compliance',
        category: 'Compliance',
        engine: 'ldap',
        searchBase: 'Domain',
        searchScope: 'Subtree',
        ldapFilter: '(objectClass=domainDNS)',
        propertiesToLoad: ['name', 'distinguishedName', 'minPwdAge'],
        ldapFindingCondition: { attribute: 'minPwdAge', operator: 'eq', compare: 0 },
        severity: 'medium',
        description: 'minPwdAge 0 allows immediate password changes.',
        remediation: 'Set minimum password age per policy.',
        references: ['CIS / STIG password policy']
    },
    {
        id: 'COMPLY-010',
        name: 'Password History Compliance',
        category: 'Compliance',
        engine: 'ldap',
        searchBase: 'Domain',
        searchScope: 'Subtree',
        ldapFilter: '(objectClass=domainDNS)',
        propertiesToLoad: ['name', 'distinguishedName', 'pwdHistoryLength'],
        ldapFindingCondition: { attribute: 'pwdHistoryLength', operator: 'lt', compare: 24 },
        severity: 'medium',
        description: 'Password history fewer than 24 passwords.',
        remediation: 'Increase pwdHistoryLength.',
        references: ['CIS / STIG password policy']
    },
    {
        id: 'COMPLY-001',
        name: 'STIG Password Policy Compliance',
        category: 'Compliance',
        engine: 'ldap',
        searchBase: 'Domain',
        searchScope: 'Subtree',
        ldapFilter: '(objectClass=domainDNS)',
        propertiesToLoad: ['name', 'distinguishedName'],
        complianceRuleSet: 'STIG_PASSWORD',
        severity: 'medium',
        description: 'Aggregated STIG-oriented password policy violations (see Violations column).',
        remediation: 'Align domain password policy with STIG.',
        references: ['DISA STIG - Active Directory', 'Modules/compliance-profiles.json']
    },
    {
        id: 'COMPLY-002',
        name: 'CIS Benchmark Account Policies',
        category: 'Compliance',
        engine: 'ldap',
        searchBase: 'Domain',
        searchScope: 'Subtree',
        ldapFilter: '(objectClass=domainDNS)',
        propertiesToLoad: ['name', 'distinguishedName'],
        complianceRuleSet: 'CIS_L1_PASSWORD',
        severity: 'medium',
        description: 'CIS Level 1 style password checks (see Violations).',
        remediation: 'Align with CIS Microsoft Windows Server benchmarks.',
        references: ['CIS Benchmarks']
    },
    {
        id: 'COMPLY-003',
        name: 'PCI DSS',
        category: 'Compliance',
        engine: 'ldap',
        searchBase: 'Domain',
        searchScope: 'Subtree',
        ldapFilter: '(objectClass=domainDNS)',
        propertiesToLoad: ['name', 'distinguishedName'],
        complianceRuleSet: 'PCI_PASSWORD',
        severity: 'medium',
        description: 'Example PCI-DSS-oriented password attribute review (see Violations).',
        remediation: 'Align with PCI-DSS v4 password requirements.',
        references: ['PCI SSC']
    },
    {
        id: 'COMPLY-004',
        name: 'HIPAA Controls',
        category: 'Compliance',
        engine: 'ldap',
        searchBase: 'Domain',
        searchScope: 'Subtree',
        ldapFilter: '(objectClass=domainDNS)',
        propertiesToLoad: ['name', 'distinguishedName'],
        complianceRuleSet: 'HIPAA_PASSWORD',
        severity: 'medium',
        description: 'Example HIPAA-oriented password checks (organizational tuning required).',
        remediation: 'Align safeguards with HIPAA security rule and risk analysis.',
        references: ['HIPAA Security Rule']
    },
    {
        id: 'PERS-010',
        name: 'Suspicious Group Modifications',
        category: 'Persistence_Detection',
        engine: 'ldap',
        searchBase: 'Domain',
        searchScope: 'Subtree',
        ldapFilter: '(objectClass=group)',
        propertiesToLoad: ['name', 'distinguishedName', 'whenChanged', 'samAccountName'],
        ldapWhenChangedWithinDays: 7,
        pageSize: 2000,
        severity: 'medium',
        description: 'Groups modified in the last 7 days (narrowed from all groups). Tune ldapWhenChangedWithinDays as needed.',
        remediation: 'Review recent group changes in privileged groups.',
        references: ['MITRE T1098']
    },
    {
        id: 'DCONF-012',
        name: 'Null Session Access (SYSVOL GPO)',
        category: 'Domain_Configuration',
        engine: 'filesystem',
        filesystemKind: 'SysvolGptTmplSecedit',
        gptTmplRules: [
            {
                ruleId: 'RestrictAnonymous_weak',
                matchSubstr: 'Lsa\\RestrictAnonymous',
                findingWhenDwordIn: [0, 1],
                detail: 'RestrictAnonymous below 2 (anonymous access not fully restricted).'
            }
        ],
        severity: 'medium',
        description: 'Reads RestrictAnonymous from SYSVOL SecEdit GptTmpl.inf.',
        remediation: 'Set RestrictAnonymous=2 via security policy.',
        references: ['https://learn.microsoft.com/windows-server/security/credentials-protection-and-management/']
    },
    {
        id: 'DCONF-013',
        name: 'LM Hash Storage (SYSVOL GPO)',
        category: 'Domain_Configuration',
        engine: 'filesystem',
        filesystemKind: 'SysvolGptTmplSecedit',
        gptTmplRules: [
            {
                ruleId: 'NoLMHash_off',
                matchSubstr: 'Lsa\\NoLMHash',
                findingWhenDwordIn: [0],
                detail: 'NoLMHash=0 allows LM hashes to be stored.'
            }
        ],
        severity: 'high',
        description: 'SYSVOL policy for NoLMHash.',
        remediation: 'Enable NoLMHash via GPO.',
        references: ['https://learn.microsoft.com/windows-server/security/credentials-protection-and-management/']
    },
    {
        id: 'COMPLY-011',
        name: 'Reversible Encryption Disabled',
        category: 'Compliance',
        engine: 'ldap',
        searchBase: 'Domain',
        searchScope: 'Subtree',
        ldapFilter: '(objectClass=domainDNS)',
        propertiesToLoad: ['name', 'distinguishedName', 'pwdProperties'],
        ldapFindingCondition: { attribute: 'pwdProperties', operator: 'bitAndNonZero', compare: 128 },
        severity: 'medium',
        description: 'Domain pwdProperties shows reversible encryption enabled (0x80). LDAP-based; not LDAP signing.',
        remediation: 'Disable reversible encryption in domain policy.',
        references: ['CIS / STIG']
    },
    {
        id: 'COMPLY-012',
        name: 'LAN Manager Hash Storage',
        category: 'Compliance',
        engine: 'filesystem',
        filesystemKind: 'SysvolGptTmplSecedit',
        gptTmplRules: [
            {
                ruleId: 'NoLMHash_off',
                matchSubstr: 'Lsa\\NoLMHash',
                findingWhenDwordIn: [0],
                detail: 'NoLMHash not enforced.'
            }
        ],
        severity: 'high',
        description: 'SYSVOL NoLMHash policy.',
        remediation: 'Set NoLMHash via GPO.',
        references: ['CIS']
    },
    {
        id: 'COMPLY-013',
        name: 'Anonymous SID Translation',
        category: 'Compliance',
        engine: 'filesystem',
        filesystemKind: 'SysvolGptTmplSecedit',
        gptTmplRules: [
            {
                ruleId: 'RestrictAnonymousSAM_off',
                matchSubstr: 'Lsa\\RestrictAnonymousSAM',
                findingWhenDwordIn: [0],
                detail: 'RestrictAnonymousSAM disabled.'
            }
        ],
        severity: 'medium',
        description: 'SYSVOL RestrictAnonymousSAM.',
        remediation: 'Enable RestrictAnonymousSAM.',
        references: ['CIS']
    },
    {
        id: 'LDAP-003',
        name: 'Anonymous LDAP Bind Allowed (SYSVOL GPO)',
        category: 'LDAP_Security',
        engine: 'filesystem',
        filesystemKind: 'SysvolGptTmplSecedit',
        gptTmplRules: [
            {
                ruleId: 'LDAPServerIntegrity_weak',
                matchSubstr: 'NTDS\\Parameters\\LDAPServerIntegrity',
                findingWhenDwordIn: [0, 1],
                detail: 'LDAP signing not required by GPO template.'
            }
        ],
        severity: 'high',
        description: 'Same LDAP integrity signal as DCONF-009, driven from GptTmpl.inf.',
        remediation: 'Require LDAP signing on DCs.',
        references: ['https://learn.microsoft.com/windows-server/']
    },
    {
        id: 'DCONF-015',
        name: 'Kerberos ticket lifetime (LDAP placeholder — see ticket policy doc)',
        category: 'Domain_Configuration',
        engine: 'ldap',
        searchBase: 'Domain',
        searchScope: 'Subtree',
        ldapFilter: '(&(objectClass=domain)(name=__AD_SUITE_NO_MATCH_PLACEHOLDER__))',
        propertiesToLoad: ['name', 'distinguishedName'],
        semanticsAuditExclude: true,
        severity: 'info',
        scoreWeight: 0,
        description:
            'Does not measure Kerberos TGT/TGS lifetimes. Those come from Group Policy / registry (e.g. Maximum lifetime for user ticket). Filter intentionally matches no object; see docs/KERBEROS_TICKET_POLICY_LIMITS.md.',
        remediation: 'Configure Kerberos policy via GPO or baseline tools.',
        references: ['docs/KERBEROS_TICKET_POLICY_LIMITS.md']
    },
    {
        id: 'DCONF-016',
        name: 'Kerberos renewal lifetime (LDAP placeholder — see ticket policy doc)',
        category: 'Domain_Configuration',
        engine: 'ldap',
        searchBase: 'Domain',
        searchScope: 'Subtree',
        ldapFilter: '(&(objectClass=domain)(name=__AD_SUITE_NO_MATCH_PLACEHOLDER__))',
        propertiesToLoad: ['name', 'distinguishedName'],
        semanticsAuditExclude: true,
        severity: 'info',
        scoreWeight: 0,
        description:
            'Does not measure renewal lifetime policy. Filter matches no object. See docs/KERBEROS_TICKET_POLICY_LIMITS.md.',
        remediation: 'Use GPO Kerberos policy settings.',
        references: ['docs/KERBEROS_TICKET_POLICY_LIMITS.md']
    },
    {
        id: 'KRB-038',
        name: 'Kerberos ticket lifetime excessive (LDAP placeholder — see ticket policy doc)',
        category: 'Kerberos_Security',
        engine: 'ldap',
        searchBase: 'Domain',
        searchScope: 'Subtree',
        ldapFilter: '(&(objectClass=domain)(name=__AD_SUITE_NO_MATCH_PLACEHOLDER__))',
        propertiesToLoad: ['name', 'distinguishedName'],
        semanticsAuditExclude: true,
        severity: 'info',
        scoreWeight: 0,
        description:
            'Does not assess ticket lifetime from LDAP. Filter matches no object. See docs/KERBEROS_TICKET_POLICY_LIMITS.md.',
        remediation: 'Validate Kerberos policy via GPO and domain security baselines.',
        references: ['docs/KERBEROS_TICKET_POLICY_LIMITS.md']
    }
];

fs.writeFileSync(out, JSON.stringify({ schemaVersion: 1, checks }, null, 4) + '\n', 'utf8');
console.log('Wrote', out, 'checks:', checks.length);
