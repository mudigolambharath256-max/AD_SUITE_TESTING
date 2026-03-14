# SVC-031: Service Accounts with Interactive Logon

## 🎯 Overview
**Severity**: MEDIUM  
**Risk Score**: 6/10  
**MITRE ATT&CK**: T1078.002  
**Category**: Service_Accounts  
**Priority**: P1

## 📋 Description
Finds service accounts used for interactive logon

## 🔍 LDAP Filter
```ldap
(&(objectCategory=person)(objectClass=user)(servicePrincipalName=*))
```

## 🛡️ Blue Team Use Cases
1. **Threat Hunting**: Proactively search for attack indicators
2. **Incident Response**: Quickly identify compromised assets
3. **Risk Assessment**: Quantify security posture
4. **Compliance**: Meet security framework requirements

## 🔧 Remediation
Review all findings and implement least privilege principles.

## 📚 References
- MITRE ATT&CK: https://attack.mitre.org/techniques/T1078.002/

---
**Created**: 2026-02-24  
**Priority**: 1
