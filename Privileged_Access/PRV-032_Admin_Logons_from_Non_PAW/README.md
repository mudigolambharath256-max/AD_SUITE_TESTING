# PRV-032: Admin Logons from Non PAW

## 🎯 Overview
**Severity**: HIGH  
**Risk Score**: 7/10  
**MITRE ATT&CK**: T1078.002  
**Category**: Privileged_Access  
**Priority**: P3

## 📋 Description
Detects privileged logons from regular workstations

## 🔍 LDAP Filter
```ldap
(&(objectCategory=person)(objectClass=user)(adminCount=1))
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
**Priority**: 3
