# CMGMT-032: Computers with Cached Credentials

## 🎯 Overview
**Severity**: MEDIUM  
**Risk Score**: 6/10  
**MITRE ATT&CK**: T1003.005  
**Category**: Computer_Management  
**Priority**: P1

## 📋 Description
Identifies computers storing cached domain credentials

## 🔍 LDAP Filter
```ldap
(&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))
```

## 🛡️ Blue Team Use Cases
1. **Threat Hunting**: Proactively search for attack indicators
2. **Incident Response**: Quickly identify compromised assets
3. **Risk Assessment**: Quantify security posture
4. **Compliance**: Meet security framework requirements

## 🔧 Remediation
Review all findings and implement least privilege principles.

## 📚 References
- MITRE ATT&CK: https://attack.mitre.org/techniques/T1003.005/

---
**Created**: 2026-02-24  
**Priority**: 1
