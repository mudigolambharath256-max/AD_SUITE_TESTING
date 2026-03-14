# KRB-032: Kerberos Encryption Downgrade Risk

## 🎯 Overview
**Severity**: HIGH  
**Risk Score**: 7/10  
**MITRE ATT&CK**: T1558  
**Category**: Kerberos_Security  
**Priority**: P1

## 📋 Description
Identifies accounts allowing weak Kerberos encryption (DES, RC4)

## 🔍 LDAP Filter
```ldap
(&(objectCategory=person)(objectClass=user)(msDS-SupportedEncryptionTypes=*))
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
