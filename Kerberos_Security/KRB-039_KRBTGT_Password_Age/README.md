# KRB-039: KRBTGT Password Age

## 🎯 Overview
**Severity**: HIGH  
**Risk Score**: 8/10  
**MITRE ATT&CK**: T1558.001  
**Category**: Kerberos_Security  
**Priority**: P1

## 📋 Description
Checks KRBTGT account password age (should be <180 days)

## 🔍 LDAP Filter
```ldap
(samAccountName=krbtgt)
```

## 🛡️ Security Impact
This check identifies critical security misconfigurations that could be exploited by attackers.

## 🔧 Remediation
Review all findings and implement security best practices according to your organization's policies.

## 📚 References
- MITRE ATT&CK: https://attack.mitre.org/techniques/T1558.001/

---
**Created**: 2026-02-24  
**Version**: 3.0.0
