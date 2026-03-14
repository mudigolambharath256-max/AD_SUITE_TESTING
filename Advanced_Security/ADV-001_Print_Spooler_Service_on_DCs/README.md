# ADV-001: Print Spooler Service on DCs

## 🎯 Overview
**Severity**: CRITICAL  
**Risk Score**: 10/10  
**MITRE ATT&CK**: T1068  
**Category**: Advanced_Security  
**Priority**: P1

## 📋 Description
Detects Print Spooler running on DCs (PrintNightmare)

## 🔍 LDAP Filter
```ldap
(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192))
```

## 🛡️ Security Impact
This check identifies critical security misconfigurations that could be exploited by attackers.

## 🔧 Remediation
Review all findings and implement security best practices according to your organization's policies.

## 📚 References
- MITRE ATT&CK: https://attack.mitre.org/techniques/T1068/

---
**Created**: 2026-02-24  
**Version**: 3.0.0
