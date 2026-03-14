# SMB-009: Administrative Shares Exposed

## 🎯 Overview
**Severity**: HIGH  
**Risk Score**: 7/10  
**MITRE ATT&CK**: T1021.002  
**Category**: SMB_Security  
**Priority**: P1

## 📋 Description
Administrative shares (C$, ADMIN$) accessible

## 🔍 LDAP Filter
```ldap
(&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))
```

## 🛡️ Security Impact
This check identifies critical security misconfigurations that could be exploited by attackers.

## 🔧 Remediation
Review all findings and implement security best practices according to your organization's policies.

## 📚 References
- MITRE ATT&CK: https://attack.mitre.org/techniques/T1021.002/

---
**Created**: 2026-02-24  
**Version**: 3.0.0
