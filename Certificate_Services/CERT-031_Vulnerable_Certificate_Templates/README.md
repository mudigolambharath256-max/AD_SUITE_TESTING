# CERT-031: Vulnerable Certificate Templates

## 🎯 Overview
**Severity**: CRITICAL  
**Risk Score**: 9/10  
**MITRE ATT&CK**: T1649  
**Category**: Certificate_Services  
**Priority**: P1

## 📋 Description
Identifies certificate templates vulnerable to ESC1-ESC8

## 🔍 LDAP Filter
```ldap
(objectClass=pKICertificateTemplate)
```

## 🛡️ Blue Team Use Cases
1. **Threat Hunting**: Proactively search for attack indicators
2. **Incident Response**: Quickly identify compromised assets
3. **Risk Assessment**: Quantify security posture
4. **Compliance**: Meet security framework requirements

## 🔧 Remediation
Review all findings and implement least privilege principles.

## 📚 References
- MITRE ATT&CK: https://attack.mitre.org/techniques/T1649/

---
**Created**: 2026-02-24  
**Priority**: 1
