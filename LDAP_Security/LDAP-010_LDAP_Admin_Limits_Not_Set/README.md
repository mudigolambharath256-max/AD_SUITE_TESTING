# LDAP-010: LDAP Admin Limits Not Set

## 🎯 Overview
**Severity**: MEDIUM  
**Risk Score**: 5/10  
**MITRE ATT&CK**: T1087.002  
**Category**: LDAP_Security  
**Priority**: P2

## 📋 Description
LDAP admin limits not properly configured

## 🔍 LDAP Filter
```ldap
(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192))
```

## 🛡️ Security Impact
This check identifies critical security misconfigurations that could be exploited by attackers.

## 🔧 Remediation
Review all findings and implement security best practices according to your organization's policies.

## 📚 References
- MITRE ATT&CK: https://attack.mitre.org/techniques/T1087.002/

---
**Created**: 2026-02-24  
**Version**: 3.0.0
