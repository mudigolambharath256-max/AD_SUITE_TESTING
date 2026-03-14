# COMPLY-008: Account Lockout Policy Compliance

## 🎯 Overview
**Severity**: MEDIUM  
**Risk Score**: 6/10  
**MITRE ATT&CK**: T1110  
**Category**: Compliance  
**Priority**: P2

## 📋 Description
Checks account lockout policy compliance

## 🔍 LDAP Filter
```ldap
(objectClass=domainDNS)
```

## 🛡️ Security Impact
This check identifies critical security misconfigurations that could be exploited by attackers.

## 🔧 Remediation
Review all findings and implement security best practices according to your organization's policies.

## 📚 References
- MITRE ATT&CK: https://attack.mitre.org/techniques/T1110/

---
**Created**: 2026-02-24  
**Version**: 3.0.0
