# KRB-043: Duplicate SPNs

## 🎯 Overview
**Severity**: MEDIUM  
**Risk Score**: 5/10  
**MITRE ATT&CK**: T1558.003  
**Category**: Kerberos_Security  
**Priority**: P2

## 📋 Description
Detects duplicate SPNs causing Kerberos failures

## 🔍 LDAP Filter
```ldap
(servicePrincipalName=*)
```

## 🛡️ Security Impact
This check identifies critical security misconfigurations that could be exploited by attackers.

## 🔧 Remediation
Review all findings and implement security best practices according to your organization's policies.

## 📚 References
- MITRE ATT&CK: https://attack.mitre.org/techniques/T1558.003/

---
**Created**: 2026-02-24  
**Version**: 3.0.0
