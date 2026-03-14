# KRB-031: Bronze Bit Attack Vulnerable Accounts

## 🎯 Overview
**Severity**: HIGH  
**Risk Score**: 8/10  
**MITRE ATT&CK**: T1558.003  
**Category**: Kerberos_Security  
**Priority**: P1

## 📋 Description
Detects accounts vulnerable to Bronze Bit attack (CVE-2020-17049)

## 🔍 LDAP Filter
```ldap
(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))
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
