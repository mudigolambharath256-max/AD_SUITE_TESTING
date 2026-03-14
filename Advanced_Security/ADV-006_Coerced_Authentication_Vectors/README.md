# ADV-006: Coerced Authentication Vectors

## 🎯 Overview
**Severity**: HIGH  
**Risk Score**: 8/10  
**MITRE ATT&CK**: T1187  
**Category**: Advanced_Security  
**Priority**: P1

## 📋 Description
Identifies coerced authentication attack vectors

## 🔍 LDAP Filter
```ldap
(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192))
```

## 🛡️ Security Impact
This check identifies critical security misconfigurations that could be exploited by attackers.

## 🔧 Remediation
Review all findings and implement security best practices according to your organization's policies.

## 📚 References
- MITRE ATT&CK: https://attack.mitre.org/techniques/T1187/

---
**Created**: 2026-02-24  
**Version**: 3.0.0
