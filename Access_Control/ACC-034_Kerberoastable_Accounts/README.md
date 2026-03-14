# ACC-034: Kerberoastable Accounts

## 🎯 Overview
**Severity**: HIGH  
**Risk Score**: 8/10  
**MITRE ATT&CK**: T1558.003  
**Category**: Access_Control  
**Priority**: P1

## 📋 Description
Finds accounts with SPNs vulnerable to Kerberoasting

## 🔍 LDAP Filter
```ldap
(&(objectCategory=person)(objectClass=user)(servicePrincipalName=*)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(!(samAccountName=krbtgt)))
```

## 🛡️ Blue Team Use Cases
1. **Threat Hunting**: Proactively search for attack indicators
2. **Incident Response**: Quickly identify compromised assets
3. **Risk Assessment**: Quantify security posture
4. **Compliance**: Meet security framework requirements

## 🔧 Remediation
Review all findings and implement least privilege principles.

## 📚 References
- MITRE ATT&CK: https://attack.mitre.org/techniques/T1558.003/

---
**Created**: 2026-02-24  
**Priority**: 1
