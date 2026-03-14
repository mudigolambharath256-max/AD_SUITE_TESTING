# LDAP-006: LDAP Referral Chasing Issues

## 🎯 Overview
**Severity**: LOW  
**Risk Score**: 3/10  
**MITRE ATT&CK**: T1071.002  
**Category**: LDAP_Security  
**Priority**: P3

## 📋 Description
LDAP referral configuration problems

## 🔍 LDAP Filter
```ldap
(objectClass=domain)
```

## 🛡️ Security Impact
This check identifies critical security misconfigurations that could be exploited by attackers.

## 🔧 Remediation
Review all findings and implement security best practices according to your organization's policies.

## 📚 References
- MITRE ATT&CK: https://attack.mitre.org/techniques/T1071.002/

---
**Created**: 2026-02-24  
**Version**: 3.0.0
