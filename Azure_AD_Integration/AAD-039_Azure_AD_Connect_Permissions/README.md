# AAD-039: Azure AD Connect Permissions

## 🎯 Overview
**Severity**: HIGH  
**Risk Score**: 8/10  
**MITRE ATT&CK**: T1098  
**Category**: Azure_AD_Integration  
**Priority**: P1

## 📋 Description
Validates Azure AD Connect account permissions

## 🔍 LDAP Filter
```ldap
(samAccountName=MSOL_*)
```

## 🛡️ Security Impact
This check identifies critical security misconfigurations that could be exploited by attackers.

## 🔧 Remediation
Review all findings and implement security best practices according to your organization's policies.

## 📚 References
- MITRE ATT&CK: https://attack.mitre.org/techniques/T1098/

---
**Created**: 2026-02-24  
**Version**: 3.0.0
