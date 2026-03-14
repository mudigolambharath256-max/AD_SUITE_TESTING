# INFRA-032: Wildcard DNS Records

## 🎯 Overview
**Severity**: MEDIUM  
**Risk Score**: 5/10  
**MITRE ATT&CK**: T1584.002  
**Category**: Infrastructure  
**Priority**: P2

## 📋 Description
Identifies wildcard DNS entries

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
- MITRE ATT&CK: https://attack.mitre.org/techniques/T1584.002/

---
**Created**: 2026-02-24  
**Priority**: 2
