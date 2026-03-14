# COMPLY-016: Guest Account Status

## 🎯 Overview
**Severity**: HIGH  
**Risk Score**: 7/10  
**MITRE ATT&CK**: T1078.001  
**Category**: Compliance  
**Priority**: P1

## 📋 Description
Validates Guest account is disabled

## 🔍 LDAP Filter
```ldap
(samAccountName=Guest)
```

## 🛡️ Security Impact
This check identifies critical security misconfigurations that could be exploited by attackers.

## 🔧 Remediation
Review all findings and implement security best practices according to your organization's policies.

## 📚 References
- MITRE ATT&CK: https://attack.mitre.org/techniques/T1078.001/

---
**Created**: 2026-02-24  
**Version**: 3.0.0
