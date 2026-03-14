# GPO-044: GPO Scheduled Tasks Security

## 🎯 Overview
**Severity**: HIGH  
**Risk Score**: 7/10  
**MITRE ATT&CK**: T1053.005  
**Category**: Group_Policy  
**Priority**: P1

## 📋 Description
Validates scheduled tasks in GPOs

## 🔍 LDAP Filter
```ldap
(objectClass=groupPolicyContainer)
```

## 🛡️ Security Impact
This check identifies critical security misconfigurations that could be exploited by attackers.

## 🔧 Remediation
Review all findings and implement security best practices according to your organization's policies.

## 📚 References
- MITRE ATT&CK: https://attack.mitre.org/techniques/T1053.005/

---
**Created**: 2026-02-24  
**Version**: 3.0.0
