# AAD-042: Azure AD Connect Health Status

## 🎯 Overview
**Severity**: MEDIUM  
**Risk Score**: 5/10  
**MITRE ATT&CK**: T1562.002  
**Category**: Azure_AD_Integration  
**Priority**: P2

## 📋 Description
Checks Azure AD Connect Health monitoring

## 🔍 LDAP Filter
```ldap
(samAccountName=MSOL_*)
```

## 🛡️ Security Impact
This check identifies critical security misconfigurations that could be exploited by attackers.

## 🔧 Remediation
Review all findings and implement security best practices according to your organization's policies.

## 📚 References
- MITRE ATT&CK: https://attack.mitre.org/techniques/T1562.002/

---
**Created**: 2026-02-24  
**Version**: 3.0.0
