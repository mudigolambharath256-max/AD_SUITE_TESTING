# AAD-034: Pass Through Authentication Security

## 🎯 Overview
**Severity**: HIGH  
**Risk Score**: 7/10  
**MITRE ATT&CK**: T1556  
**Category**: Azure_AD_Integration  
**Priority**: P1

## 📋 Description
Validates PTA agent security

## 🔍 LDAP Filter
```ldap
(&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))
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
