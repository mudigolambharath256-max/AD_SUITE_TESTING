# ACC-038: Constrained Delegation Targets

## 🎯 Overview
**Severity**: HIGH  
**Risk Score**: 7/10  
**MITRE ATT&CK**: T1134.001  
**Category**: Access_Control  
**Priority**: P1

## 📋 Description
Maps constrained delegation relationships

## 🔍 LDAP Filter
```ldap
(msDS-AllowedToDelegateTo=*)
```

## 🛡️ Blue Team Use Cases
1. **Threat Hunting**: Proactively search for attack indicators
2. **Incident Response**: Quickly identify compromised assets
3. **Risk Assessment**: Quantify security posture
4. **Compliance**: Meet security framework requirements

## 🔧 Remediation
Review all findings and implement least privilege principles.

## 📚 References
- MITRE ATT&CK: https://attack.mitre.org/techniques/T1134.001/

---
**Created**: 2026-02-24  
**Priority**: 1
