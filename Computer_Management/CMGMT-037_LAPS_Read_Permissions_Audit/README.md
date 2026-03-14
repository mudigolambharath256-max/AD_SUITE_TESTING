# CMGMT-037: LAPS Read Permissions Audit

## 🎯 Overview
**Severity**: MEDIUM  
**Risk Score**: 6/10  
**MITRE ATT&CK**: T1003.002  
**Category**: Computer_Management  
**Priority**: P1

## 📋 Description
Audits who can read LAPS passwords

## 🔍 LDAP Filter
```ldap
(&(objectCategory=computer)(ms-Mcs-AdmPwd=*))
```

## 🛡️ Blue Team Use Cases
1. **Threat Hunting**: Proactively search for attack indicators
2. **Incident Response**: Quickly identify compromised assets
3. **Risk Assessment**: Quantify security posture
4. **Compliance**: Meet security framework requirements

## 🔧 Remediation
Review all findings and implement least privilege principles.

## 📚 References
- MITRE ATT&CK: https://attack.mitre.org/techniques/T1003.002/

---
**Created**: 2026-02-24  
**Priority**: 1
