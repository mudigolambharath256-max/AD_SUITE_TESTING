# BCK-005: AD Recycle Bin Status

## 🎯 Overview
**Severity**: MEDIUM  
**Risk Score**: 6/10  
**MITRE ATT&CK**: T1490  
**Category**: Backup_Recovery  
**Priority**: P2

## 📋 Description
Validates AD Recycle Bin configuration

## 🔍 LDAP Filter
```ldap
(objectClass=domain)
```

## 🛡️ Security Impact
This check identifies critical security misconfigurations that could be exploited by attackers.

## 🔧 Remediation
Review all findings and implement security best practices according to your organization's policies.

## 📚 References
- MITRE ATT&CK: https://attack.mitre.org/techniques/T1490/

---
**Created**: 2026-02-24  
**Version**: 3.0.0
