# SMB-001: SMBv1 Enabled

## 🎯 Overview
**Severity**: CRITICAL  
**Risk Score**: 10/10  
**MITRE ATT&CK**: T1021.002  
**Category**: SMB_Security  
**Priority**: P1

## 📋 Description
SMBv1 protocol enabled (critical vulnerability)

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
