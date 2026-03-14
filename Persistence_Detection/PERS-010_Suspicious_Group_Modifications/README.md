# PERS-010: Suspicious Group Modifications

## 🎯 Overview
**Severity**: HIGH  
**Risk Score**: 7/10  
**MITRE ATT&CK**: T1098  
**Category**: Persistence_Detection  
**Priority**: P1

## 📋 Description
Tracks suspicious group membership changes

## 🔍 LDAP Filter
```ldap
(objectClass=group)
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
