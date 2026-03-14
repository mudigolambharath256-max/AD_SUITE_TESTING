# KRB-036: Kerberos AES Not Enforced

## 🎯 Overview
**Severity**: MEDIUM  
**Risk Score**: 6/10  
**MITRE ATT&CK**: T1558  
**Category**: Kerberos_Security  
**Priority**: P2

## 📋 Description
Accounts not enforcing AES encryption

## 🔍 LDAP Filter
```ldap
(&(objectCategory=person)(objectClass=user))
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
