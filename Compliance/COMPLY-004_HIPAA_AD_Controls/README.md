# COMPLY-004: HIPAA AD Controls

## 🎯 Overview
**Severity**: HIGH  
**Risk Score**: 8/10  
**MITRE ATT&CK**: T1078  
**Category**: Compliance  
**Priority**: P1

## 📋 Description
Checks HIPAA AD security controls

## 🔍 LDAP Filter
```ldap
(objectClass=domainDNS)
```

## 🛡️ Security Impact
This check identifies critical security misconfigurations that could be exploited by attackers.

## 🔧 Remediation
Review all findings and implement security best practices according to your organization's policies.

## 📚 References
- MITRE ATT&CK: https://attack.mitre.org/techniques/T1078/

---
**Created**: 2026-02-24  
**Version**: 3.0.0
