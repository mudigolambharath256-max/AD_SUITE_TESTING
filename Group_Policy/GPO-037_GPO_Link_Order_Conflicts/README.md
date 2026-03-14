# GPO-037: GPO Link Order Conflicts

## 🎯 Overview
**Severity**: MEDIUM  
**Risk Score**: 5/10  
**MITRE ATT&CK**: T1484.001  
**Category**: Group_Policy  
**Priority**: P2

## 📋 Description
Detects GPO link order issues

## 🔍 LDAP Filter
```ldap
(objectClass=organizationalUnit)
```

## 🛡️ Security Impact
This check identifies critical security misconfigurations that could be exploited by attackers.

## 🔧 Remediation
Review all findings and implement security best practices according to your organization's policies.

## 📚 References
- MITRE ATT&CK: https://attack.mitre.org/techniques/T1484.001/

---
**Created**: 2026-02-24  
**Version**: 3.0.0
