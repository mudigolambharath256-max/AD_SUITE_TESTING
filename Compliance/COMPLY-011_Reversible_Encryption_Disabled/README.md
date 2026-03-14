# COMPLY-011: Reversible Encryption Disabled

## 🎯 Overview
**Severity**: HIGH  
**Risk Score**: 8/10  
**MITRE ATT&CK**: T1003  
**Category**: Compliance  
**Priority**: P1

## 📋 Description
Ensures reversible encryption is disabled

## 🔍 LDAP Filter
```ldap
(objectClass=domainDNS)
```

## 🛡️ Security Impact
This check identifies critical security misconfigurations that could be exploited by attackers.

## 🔧 Remediation
Review all findings and implement security best practices according to your organization's policies.

## 📚 References
- MITRE ATT&CK: https://attack.mitre.org/techniques/T1003/

---
**Created**: 2026-02-24  
**Version**: 3.0.0
