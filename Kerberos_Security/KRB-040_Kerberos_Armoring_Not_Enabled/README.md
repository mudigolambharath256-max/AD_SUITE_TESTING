# KRB-040: Kerberos Armoring Not Enabled

## 🎯 Overview
**Severity**: MEDIUM  
**Risk Score**: 6/10  
**MITRE ATT&CK**: T1558  
**Category**: Kerberos_Security  
**Priority**: P2

## 📋 Description
Detects systems without Kerberos armoring (FAST)

## 🔍 LDAP Filter
```ldap
(&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))
```

## 🛡️ Security Impact
This check identifies critical security misconfigurations that could be exploited by attackers.

## 🔧 Remediation
Review all findings and implement security best practices according to your organization's policies.

## 📚 References
- MITRE ATT&CK: https://attack.mitre.org/techniques/T1558/

---
**Created**: 2026-02-24  
**Version**: 3.0.0
