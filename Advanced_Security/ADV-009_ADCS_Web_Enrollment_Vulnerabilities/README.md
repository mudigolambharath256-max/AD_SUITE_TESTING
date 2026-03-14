# ADV-009: ADCS Web Enrollment Vulnerabilities

## 🎯 Overview
**Severity**: CRITICAL  
**Risk Score**: 9/10  
**MITRE ATT&CK**: T1649  
**Category**: Advanced_Security  
**Priority**: P1

## 📋 Description
Detects ADCS web enrollment vulnerabilities

## 🔍 LDAP Filter
```ldap
(objectClass=pKIEnrollmentService)
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
