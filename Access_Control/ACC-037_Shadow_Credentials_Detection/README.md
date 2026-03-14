# ACC-037: Shadow Credentials Detection

## 🎯 Overview
**Severity**: CRITICAL  
**Risk Score**: 9/10  
**MITRE ATT&CK**: T1556.002  
**Category**: Access_Control  
**Priority**: P1

## 📋 Description
Comprehensive detection of msDS-KeyCredentialLink

## 🔍 LDAP Filter
```ldap
(msDS-KeyCredentialLink=*)
```

## 🛡️ Blue Team Use Cases
1. **Threat Hunting**: Proactively search for attack indicators
2. **Incident Response**: Quickly identify compromised assets
3. **Risk Assessment**: Quantify security posture
4. **Compliance**: Meet security framework requirements

## 🔧 Remediation
Review all findings and implement least privilege principles.

## 📚 References
- MITRE ATT&CK: https://attack.mitre.org/techniques/T1556.002/

---
**Created**: 2026-02-24  
**Priority**: 1
