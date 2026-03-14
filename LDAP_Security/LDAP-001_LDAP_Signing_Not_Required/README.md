# LDAP-001: LDAP Signing Not Required

## 🎯 Overview
**Severity**: CRITICAL  
**Risk Score**: 9/10  
**MITRE ATT&CK**: T1557.001  
**Category**: LDAP_Security  
**Priority**: P1

## 📋 Description
LDAP signing not enforced on domain controllers

## 🔍 LDAP Filter
```ldap
(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192))
```

## 🛡️ Security Impact
This check identifies critical security misconfigurations that could be exploited by attackers.

## 🔧 Remediation
Review all findings and implement security best practices according to your organization's policies.

## 📚 References
- MITRE ATT&CK: https://attack.mitre.org/techniques/T1557.001/

---
**Created**: 2026-02-24  
**Version**: 3.0.0
