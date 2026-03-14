# PERS-008: Hidden Accounts in CN Users

## 🎯 Overview
**Severity**: HIGH  
**Risk Score**: 7/10  
**MITRE ATT&CK**: T1136.002  
**Category**: Persistence_Detection  
**Priority**: P1

## 📋 Description
Finds hidden accounts in Users container

## 🔍 LDAP Filter
```ldap
(&(objectCategory=person)(objectClass=user))
```

## 🛡️ Security Impact
This check identifies critical security misconfigurations that could be exploited by attackers.

## 🔧 Remediation
Review all findings and implement security best practices according to your organization's policies.

## 📚 References
- MITRE ATT&CK: https://attack.mitre.org/techniques/T1136.002/

---
**Created**: 2026-02-24  
**Version**: 3.0.0
