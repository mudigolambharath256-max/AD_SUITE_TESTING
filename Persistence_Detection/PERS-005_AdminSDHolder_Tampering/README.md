# PERS-005: AdminSDHolder Tampering

## 🎯 Overview
**Severity**: CRITICAL  
**Risk Score**: 9/10  
**MITRE ATT&CK**: T1098  
**Category**: Persistence_Detection  
**Priority**: P1

## 📋 Description
Detects AdminSDHolder modifications

## 🔍 LDAP Filter
```ldap
(distinguishedName=CN=AdminSDHolder,CN=System,*)
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
