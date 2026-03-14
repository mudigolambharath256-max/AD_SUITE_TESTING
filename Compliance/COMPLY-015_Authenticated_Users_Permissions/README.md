# COMPLY-015: Authenticated Users Permissions

## 🎯 Overview
**Severity**: MEDIUM  
**Risk Score**: 6/10  
**MITRE ATT&CK**: T1222.001  
**Category**: Compliance  
**Priority**: P2

## 📋 Description
Checks Authenticated Users permissions

## 🔍 LDAP Filter
```ldap
(objectClass=*)
```

## 🛡️ Security Impact
This check identifies critical security misconfigurations that could be exploited by attackers.

## 🔧 Remediation
Review all findings and implement security best practices according to your organization's policies.

## 📚 References
- MITRE ATT&CK: https://attack.mitre.org/techniques/T1222.001/

---
**Created**: 2026-02-24  
**Version**: 3.0.0
