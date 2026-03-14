# ADV-008: Machine Account Quota Abuse

## 🎯 Overview
**Severity**: HIGH  
**Risk Score**: 7/10  
**MITRE ATT&CK**: T1136.002  
**Category**: Advanced_Security  
**Priority**: P1

## 📋 Description
Checks machine account quota settings

## 🔍 LDAP Filter
```ldap
(objectClass=domainDNS)
```

## 🛡️ Security Impact
This check identifies critical security misconfigurations that could be exploited by attackers.

## 🔧 Remediation
Review all findings and implement security best practices according to your organization's policies.

## 📚 References
- MITRE ATT&CK: https://attack.mitre.org/techniques/T1136.002/

---
**Created**: 2026-02-24  
**Version**: 3.0.0
