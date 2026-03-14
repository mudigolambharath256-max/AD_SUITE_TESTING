# LDAP-003: Anonymous LDAP Bind Allowed

## 🎯 Overview
**Severity**: CRITICAL  
**Risk Score**: 10/10  
**MITRE ATT&CK**: T1087.002  
**Category**: LDAP_Security  
**Priority**: P1

## 📋 Description
Anonymous LDAP binds permitted

## 🔍 LDAP Filter
```ldap
(objectClass=domain)
```

## 🛡️ Security Impact
This check identifies critical security misconfigurations that could be exploited by attackers.

## 🔧 Remediation
Review all findings and implement security best practices according to your organization's policies.

## 📚 References
- MITRE ATT&CK: https://attack.mitre.org/techniques/T1087.002/

---
**Created**: 2026-02-24  
**Version**: 3.0.0
