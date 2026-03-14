# GPO-043: GPO Preferences Passwords

## 🎯 Overview
**Severity**: CRITICAL  
**Risk Score**: 10/10  
**MITRE ATT&CK**: T1552.006  
**Category**: Group_Policy  
**Priority**: P1

## 📋 Description
Detects passwords in GPO preferences

## 🔍 LDAP Filter
```ldap
(objectClass=groupPolicyContainer)
```

## 🛡️ Security Impact
This check identifies critical security misconfigurations that could be exploited by attackers.

## 🔧 Remediation
Review all findings and implement security best practices according to your organization's policies.

## 📚 References
- MITRE ATT&CK: https://attack.mitre.org/techniques/T1552.006/

---
**Created**: 2026-02-24  
**Version**: 3.0.0
