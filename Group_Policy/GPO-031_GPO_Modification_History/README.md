# GPO-031: GPO Modification History

## 🎯 Overview
**Severity**: HIGH  
**Risk Score**: 8/10  
**MITRE ATT&CK**: T1484.001  
**Category**: Group_Policy  
**Priority**: P1

## 📋 Description
Tracks recent GPO changes

## 🔍 LDAP Filter
```ldap
(objectClass=groupPolicyContainer)
```

## 🛡️ Blue Team Use Cases
1. **Threat Hunting**: Proactively search for attack indicators
2. **Incident Response**: Quickly identify compromised assets
3. **Risk Assessment**: Quantify security posture
4. **Compliance**: Meet security framework requirements

## 🔧 Remediation
Review all findings and implement least privilege principles.

## 📚 References
- MITRE ATT&CK: https://attack.mitre.org/techniques/T1484.001/

---
**Created**: 2026-02-24  
**Priority**: 1
