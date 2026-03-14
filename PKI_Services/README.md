# PKI Services Checks

This folder contains checks related to Public Key Infrastructure (PKI) services integrated with Active Directory.

## Overview

These checks assess Enterprise Certificate Authorities (CAs) that are integrated with Active Directory for certificate-based authentication and encryption services.

## Checks in This Category

### Certificate Authorities (1 check)
- **AD-024**: AD-Integrated Certificate Authorities - Enterprise CA inventory

## Severity Distribution

- **INFO**: 1 check (informational/inventory)

## Usage

Each check folder contains 5 implementation variants:
1. **powershell.ps1** - ActiveDirectory module (requires RSAT)
2. **adsi.ps1** - Native ADSI (no dependencies)
3. **csharp.cs** - Standalone C# code
4. **cmd.bat** - Windows batch with dsquery
5. **combined_multiengine.ps1** - Multi-engine orchestrator

## Quick Start

```powershell
# List all Enterprise CAs
.\AD-024_AD-Integrated_Certificate_Authorities\AD-024_AD-Integrated_Certificate_Authorities\powershell.ps1
```

## Enterprise Certificate Authorities

### What is an Enterprise CA?

**Enterprise CA**:
- Integrated with Active Directory
- Issues certificates based on certificate templates
- Supports auto-enrollment
- Validates certificate requests against AD permissions
- Publishes certificates to AD (user/computer objects)

**Standalone CA** (not detected by this check):
- Not integrated with AD
- Manual certificate request approval
- No auto-enrollment support
- No AD-based permissions

### Information Collected

**AD-024 retrieves**:
- CA name
- DNS hostname
- Certificate templates published
- CA certificate information
- Location in AD (CN=Enrollment Services)

### PKI in Active Directory

**AD Integration Points**:
- **Configuration Partition**: CA objects stored in `CN=Enrollment Services,CN=Public Key Services,CN=Services,CN=Configuration`
- **Certificate Templates**: Stored in `CN=Certificate Templates,CN=Public Key Services`
- **User Certificates**: Published to `userCertificate` attribute
- **Computer Certificates**: Published to computer object attributes

## Use Cases

### PKI Inventory
- Document all Enterprise CAs in environment
- Identify CA hierarchy (Root, Subordinate)
- Track CA certificate expiration
- Support PKI planning and migration

### Security Assessment
- Verify authorized CAs only
- Identify rogue or unauthorized CAs
- Review certificate template permissions
- Audit CA configuration

### Troubleshooting
- Verify CA availability for certificate issuance
- Check CA publication in AD
- Support certificate enrollment issues
- Validate PKI infrastructure

### Compliance
- Document PKI infrastructure for audits
- Verify CA configurations meet requirements
- Track certificate authority inventory
- Support compliance reporting

## Security Considerations

### CA Security Best Practices
1. **Protect Root CA**: Keep offline, air-gapped
2. **Secure Issuing CAs**: Harden servers, restrict access
3. **Template Permissions**: Review and restrict certificate template permissions
4. **Monitor Issuance**: Audit certificate issuance activity
5. **CA Backup**: Regular CA database and key backups

### Common PKI Vulnerabilities
- **ESC1-ESC8**: AD CS privilege escalation techniques
- **Weak Template Permissions**: Allow unauthorized certificate requests
- **Overprivileged Templates**: Templates with dangerous EKUs
- **Unprotected CA Keys**: Insufficient CA private key protection

### Recommended Additional Checks
While AD-024 provides CA inventory, consider additional PKI security checks:
- Certificate template permissions audit
- Dangerous certificate template configurations (ESC1-ESC8)
- CA certificate expiration monitoring
- Certificate revocation list (CRL) availability
- OCSP responder configuration

## Related Checks

### Domain Controllers
- **DC-036**: DCs with Expiring Certificates - Monitors DC certificate expiration

### Security Considerations
- Review certificate template permissions separately
- Audit certificate issuance logs
- Monitor for unauthorized certificate requests
- Implement certificate lifecycle management

## PKI Architecture

### Typical Enterprise PKI Hierarchy
```
Root CA (Offline)
└── Issuing CA (Online, AD-Integrated) ← Detected by AD-024
    ├── User Certificates
    ├── Computer Certificates
    └── Service Certificates
```

### Certificate Templates
Common templates issued by Enterprise CAs:
- **User**: User authentication certificates
- **Computer**: Computer authentication certificates
- **Domain Controller**: DC authentication certificates
- **Web Server**: SSL/TLS certificates
- **Code Signing**: Software signing certificates

## Performance Notes

- **AD-024**: Fast (typically 1-5 Enterprise CAs in environment)
- Queries Configuration partition (replicated to all DCs)
- Minimal performance impact

## Related Categories

- **Domain_Controllers** - DC certificate monitoring (DC-036)
- **Infrastructure** - AD topology and structure
- **Domain_Configuration** - Domain-wide settings

## Total Checks: 1

## Future Enhancements

Consider adding checks for:
- Certificate template security audit (ESC1-ESC8)
- CA certificate expiration monitoring
- CRL/OCSP availability checks
- Certificate enrollment permissions audit
- Dangerous EKU combinations
