# CERT-044: Certificate Validity Period Excessive

## 🎯 Overview
**Severity**: MEDIUM  
**Risk Score**: 5/10  
**MITRE ATT&CK**: T1649  
**Category**: Certificate_Services  
**Priority**: P2

## 📋 Description
Templates with excessive validity periods

## 🔍 LDAP Filter
```ldap
(objectClass=pKICertificateTemplate)
```

## 🛡️ Security Impact
This check identifies critical security misconfigurations that could be exploited by attackers.

## 🔧 Remediation
Review all findings and implement security best practices according to your organization's policies.

## 📚 References
- MITRE ATT&CK: https://attack.mitre.org/techniques/T1649/

---
**Created**: 2026-02-24  
**Version**: 3.0.0
