# COMPLY-019: Security Log Size Compliance

## 🎯 Overview
**Severity**: MEDIUM  
**Risk Score**: 6/10  
**MITRE ATT&CK**: T1562.002  
**Category**: Compliance  
**Priority**: P2

## 📋 Description
Checks security log size configuration

## 🔍 LDAP Filter
```ldap
(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192))
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
