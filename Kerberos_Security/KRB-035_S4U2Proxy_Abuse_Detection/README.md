# KRB-035: S4U2Proxy Abuse Detection

## 🎯 Overview
**Severity**: HIGH  
**Risk Score**: 7/10  
**MITRE ATT&CK**: T1134.001  
**Category**: Kerberos_Security  
**Priority**: P1

## 📋 Description
Identifies S4U2Proxy delegation configurations

## 🔍 LDAP Filter
```ldap
(msDS-AllowedToDelegateTo=*)
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
