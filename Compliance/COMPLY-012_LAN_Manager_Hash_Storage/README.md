# COMPLY-012: LAN Manager Hash Storage

## 🎯 Overview
**Severity**: CRITICAL  
**Risk Score**: 9/10  
**MITRE ATT&CK**: T1003.002  
**Category**: Compliance  
**Priority**: P1

## 📋 Description
Checks if LM hashes are stored

## 🔍 LDAP Filter
```ldap
(objectClass=domainDNS)
```

## 🛡️ Security Impact
This check identifies critical security misconfigurations that could be exploited by attackers.

## 🔧 Remediation
Review all findings and implement security best practices according to your organization's policies.

## 📚 References
- MITRE ATT&CK: https://attack.mitre.org/techniques/T1003.002/

---
**Created**: 2026-02-24  
**Version**: 3.0.0
