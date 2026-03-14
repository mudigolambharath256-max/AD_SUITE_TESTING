# KRB-044: Kerberos Clock Skew Issues

## 🎯 Overview
**Severity**: MEDIUM  
**Risk Score**: 4/10  
**MITRE ATT&CK**: T1070.006  
**Category**: Kerberos_Security  
**Priority**: P2

## 📋 Description
Identifies systems with time sync issues

## 🔍 LDAP Filter
```ldap
(&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))
```

## 🛡️ Security Impact
This check identifies critical security misconfigurations that could be exploited by attackers.

## 🔧 Remediation
Review all findings and implement security best practices according to your organization's policies.

## 📚 References
- MITRE ATT&CK: https://attack.mitre.org/techniques/T1070.006/

---
**Created**: 2026-02-24  
**Version**: 3.0.0
