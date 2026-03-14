# GPO-045: GPO Registry Settings Dangerous

## 🎯 Overview
**Severity**: HIGH  
**Risk Score**: 7/10  
**MITRE ATT&CK**: T1112  
**Category**: Group_Policy  
**Priority**: P1

## 📋 Description
Dangerous registry settings in GPOs

## 🔍 LDAP Filter
```ldap
(objectClass=groupPolicyContainer)
```

## 🛡️ Security Impact
This check identifies critical security misconfigurations that could be exploited by attackers.

## 🔧 Remediation
Review all findings and implement security best practices according to your organization's policies.

## 📚 References
- MITRE ATT&CK: https://attack.mitre.org/techniques/T1112/

---
**Created**: 2026-02-24  
**Version**: 3.0.0
