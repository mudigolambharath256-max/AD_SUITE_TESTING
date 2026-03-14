# AAD-035: Seamless SSO Configuration

## 🎯 Overview
**Severity**: MEDIUM  
**Risk Score**: 6/10  
**MITRE ATT&CK**: T1556  
**Category**: Azure_AD_Integration  
**Priority**: P2

## 📋 Description
Checks Seamless SSO security settings

## 🔍 LDAP Filter
```ldap
(samAccountName=AZUREADSSOACC$)
```

## 🛡️ Security Impact
This check identifies critical security misconfigurations that could be exploited by attackers.

## 🔧 Remediation
Review all findings and implement security best practices according to your organization's policies.

## 📚 References
- MITRE ATT&CK: https://attack.mitre.org/techniques/T1556/

---
**Created**: 2026-02-24  
**Version**: 3.0.0
