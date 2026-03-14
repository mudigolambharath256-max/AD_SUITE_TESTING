# KRB-034: S4U2Self Abuse Detection

## 🎯 Overview
**Severity**: HIGH  
**Risk Score**: 7/10  
**MITRE ATT&CK**: T1134.001  
**Category**: Kerberos_Security  
**Priority**: P1

## 📋 Description
Detects potential S4U2Self delegation abuse

## 🔍 LDAP Filter
```ldap
(userAccountControl:1.2.840.113556.1.4.803:=16777216)
```

## 🛡️ Security Impact
This check identifies critical security misconfigurations that could be exploited by attackers.

## 🔧 Remediation
Review all findings and implement security best practices according to your organization's policies.

## 📚 References
- MITRE ATT&CK: https://attack.mitre.org/techniques/T1134.001/

---
**Created**: 2026-02-24  
**Version**: 3.0.0
