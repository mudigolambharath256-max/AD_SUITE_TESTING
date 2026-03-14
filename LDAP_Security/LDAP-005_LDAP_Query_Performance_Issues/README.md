# LDAP-005: LDAP Query Performance Issues

## 🎯 Overview
**Severity**: LOW  
**Risk Score**: 3/10  
**MITRE ATT&CK**: T1498.001  
**Category**: LDAP_Security  
**Priority**: P3

## 📋 Description
Detects inefficient LDAP queries

## 🔍 LDAP Filter
```ldap
(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192))
```

## 🛡️ Security Impact
This check identifies critical security misconfigurations that could be exploited by attackers.

## 🔧 Remediation
Review all findings and implement security best practices according to your organization's policies.

## 📚 References
- MITRE ATT&CK: https://attack.mitre.org/techniques/T1498.001/

---
**Created**: 2026-02-24  
**Version**: 3.0.0
