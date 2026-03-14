# INFRA-031: DNS Records Pointing to External IPs

## 🎯 Overview
**Severity**: MEDIUM  
**Risk Score**: 6/10  
**MITRE ATT&CK**: T1071.004  
**Category**: Infrastructure  
**Priority**: P2

## 📋 Description
Finds DNS records with external destinations

## 🔍 LDAP Filter
```ldap
(objectClass=dnsNode)
```

## 🛡️ Blue Team Use Cases
1. **Threat Hunting**: Proactively search for attack indicators
2. **Incident Response**: Quickly identify compromised assets
3. **Risk Assessment**: Quantify security posture
4. **Compliance**: Meet security framework requirements

## 🔧 Remediation
Review all findings and implement least privilege principles.

## 📚 References
- MITRE ATT&CK: https://attack.mitre.org/techniques/T1071.004/

---
**Created**: 2026-02-24  
**Priority**: 2
