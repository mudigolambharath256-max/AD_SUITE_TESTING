# PERS-002: Golden Ticket Indicators

## 🎯 Overview
**Severity**: CRITICAL  
**Risk Score**: 10/10  
**MITRE ATT&CK**: T1558.001  
**Category**: Persistence_Detection  
**Priority**: P1

## 📋 Description
Identifies golden ticket attack indicators

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
