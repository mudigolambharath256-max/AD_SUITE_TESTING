# AAD-032: Password Hash Sync Status

## 🎯 Overview
**Severity**: MEDIUM  
**Risk Score**: 6/10  
**MITRE ATT&CK**: T1003.006  
**Category**: Azure_AD_Integration  
**Priority**: P3

## 📋 Description
Checks PHS configuration

## 🔍 LDAP Filter
```ldap
(&(objectCategory=person)(objectClass=user)(samAccountName=MSOL_*))
```

## 🛡️ Blue Team Use Cases
1. **Threat Hunting**: Proactively search for attack indicators
2. **Incident Response**: Quickly identify compromised assets
3. **Risk Assessment**: Quantify security posture
4. **Compliance**: Meet security framework requirements

## 🔧 Remediation
Review all findings and implement least privilege principles.

## 📚 References
- MITRE ATT&CK: https://attack.mitre.org/techniques/T1003.006/

---
**Created**: 2026-02-24  
**Priority**: 3
