# KRB-045: Protected Users Group Not Used

## 🎯 Overview
**Severity**: HIGH  
**Risk Score**: 7/10  
**MITRE ATT&CK**: T1078.002  
**Category**: Kerberos_Security  
**Priority**: P1

## 📋 Description
Privileged accounts not in Protected Users group

## 🔍 LDAP Filter
```ldap
(&(objectCategory=person)(objectClass=user)(adminCount=1))
```

## 🛡️ Security Impact
This check identifies critical security misconfigurations that could be exploited by attackers.

## 🔧 Remediation
Review all findings and implement security best practices according to your organization's policies.

## 📚 References
- MITRE ATT&CK: https://attack.mitre.org/techniques/T1078.002/

---
**Created**: 2026-02-24  
**Version**: 3.0.0
