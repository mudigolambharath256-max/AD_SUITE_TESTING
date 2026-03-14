# USR-035: Accounts with Suspicious Naming Patterns

## 🎯 Overview
**Severity**: MEDIUM  
**Risk Score**: 5/10  
**MITRE ATT&CK**: T1136.002  
**Category**: Users_and_Accounts  
**Priority**: P2

## 📋 Description
Identifies accounts with suspicious names

## 🔍 LDAP Filter
```ldap
(&(objectCategory=person)(objectClass=user))
```

## 🛡️ Blue Team Use Cases
1. **Threat Hunting**: Proactively search for attack indicators
2. **Incident Response**: Quickly identify compromised assets
3. **Risk Assessment**: Quantify security posture
4. **Compliance**: Meet security framework requirements

## 🔧 Remediation
Review all findings and implement least privilege principles.

## 📚 References
- MITRE ATT&CK: https://attack.mitre.org/techniques/T1136.002/

---
**Created**: 2026-02-24  
**Priority**: 2
