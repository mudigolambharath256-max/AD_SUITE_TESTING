# NET-006: DNS Scavenging Configuration

## 🎯 Overview
**Severity**: MEDIUM  
**Risk Score**: 5/10  
**MITRE ATT&CK**: T1584.002  
**Category**: Network_Security  
**Priority**: P2

## 📋 Description
Validates DNS scavenging settings

## 🔍 LDAP Filter
```ldap
(objectClass=dnsZone)
```

## 🛡️ Security Impact
This check identifies critical security misconfigurations that could be exploited by attackers.

## 🔧 Remediation
Review all findings and implement security best practices according to your organization's policies.

## 📚 References
- MITRE ATT&CK: https://attack.mitre.org/techniques/T1584.002/

---
**Created**: 2026-02-24  
**Version**: 3.0.0
