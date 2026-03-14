# PERS-011: ACL Backdoors

## 🎯 Overview
**Severity**: HIGH  
**Risk Score**: 8/10  
**MITRE ATT&CK**: T1222.001  
**Category**: Persistence_Detection  
**Priority**: P1

## 📋 Description
Detects ACL-based persistence mechanisms

## 🔍 LDAP Filter
```ldap
(|(objectClass=user)(objectClass=group)(objectClass=computer))
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
