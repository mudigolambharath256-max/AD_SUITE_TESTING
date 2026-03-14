# TMGMT-032: Trusts with Weak Encryption

## 🎯 Overview
**Severity**: HIGH  
**Risk Score**: 7/10  
**MITRE ATT&CK**: T1558.003  
**Category**: Trust_Management  
**Priority**: P2

## 📋 Description
Identifies trusts using weak encryption

## 🔍 LDAP Filter
```ldap
(objectClass=trustedDomain)
```

## 🛡️ Blue Team Use Cases
1. **Threat Hunting**: Proactively search for attack indicators
2. **Incident Response**: Quickly identify compromised assets
3. **Risk Assessment**: Quantify security posture
4. **Compliance**: Meet security framework requirements

## 🔧 Remediation
Review all findings and implement least privilege principles.

## 📚 References
- MITRE ATT&CK: https://attack.mitre.org/techniques/T1558.003/

---
**Created**: 2026-02-24  
**Priority**: 2
