# NET-005: Broadcast Multicast Issues

## 🎯 Overview
**Severity**: LOW  
**Risk Score**: 4/10  
**MITRE ATT&CK**: T1498.001  
**Category**: Network_Security  
**Priority**: P3

## 📋 Description
Identifies broadcast/multicast problems

## 🔍 LDAP Filter
```ldap
(&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))
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
