# ACC-031: Shortest Path to Domain Admin

## 🎯 Overview
**Severity**: CRITICAL  
**Risk Score**: 10/10  
**MITRE ATT&CK**: T1078.002  
**Category**: Access_Control  
**Priority**: P1

## 📋 Description
Maps all privilege escalation paths from users to Domain Admin

## 🔍 LDAP Filter
```ldap
(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))
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
