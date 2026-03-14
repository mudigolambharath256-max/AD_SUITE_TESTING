# PERS-003: Silver Ticket Indicators

## 🎯 Overview
**Severity**: HIGH  
**Risk Score**: 9/10  
**MITRE ATT&CK**: T1558.002  
**Category**: Persistence_Detection  
**Priority**: P1

## 📋 Description
Detects silver ticket attack indicators

## 🔍 LDAP Filter
```ldap
(servicePrincipalName=*)
```

## 🛡️ Security Impact
This check identifies critical security misconfigurations that could be exploited by attackers.

## 🔧 Remediation
Review all findings and implement security best practices according to your organization's policies.

## 📚 References
- MITRE ATT&CK: https://attack.mitre.org/techniques/T1558.002/

---
**Created**: 2026-02-24  
**Version**: 3.0.0
