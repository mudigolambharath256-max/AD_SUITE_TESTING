# PERS-007: Malicious SPN Additions

## 🎯 Overview
**Severity**: HIGH  
**Risk Score**: 8/10  
**MITRE ATT&CK**: T1098  
**Category**: Persistence_Detection  
**Priority**: P1

## 📋 Description
Detects suspicious SPN additions

## 🔍 LDAP Filter
```ldap
(servicePrincipalName=*)
```

## 🛡️ Security Impact
This check identifies critical security misconfigurations that could be exploited by attackers.

## 🔧 Remediation
Review all findings and implement security best practices according to your organization's policies.

## 📚 References
- MITRE ATT&CK: https://attack.mitre.org/techniques/T1098/

---
**Created**: 2026-02-24  
**Version**: 3.0.0
