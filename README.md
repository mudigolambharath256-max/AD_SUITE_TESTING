# AD Security Suite

A comprehensive Active Directory security auditing and monitoring solution with a modern web interface.

## Overview

The AD Security Suite is a complete toolkit for Active Directory security assessment, monitoring, and compliance. It includes hundreds of PowerShell scripts organized by security domain, plus a full-featured web application for managing and executing scans.

## Features

- **30+ Security Categories** covering all aspects of AD security
- **Modern Web Interface** for scan management and reporting
- **Multiple Execution Engines** (PowerShell, ADSI, C#, CMD)
- **Real-time Diagnostics** for troubleshooting scan issues
- **Docker Support** with Windows containers
- **Native Windows Installation** with automated setup scripts
- **JSON Export** for integration with other tools
- **Severity-based Findings** (Critical, High, Medium, Low, Info)

## Security Categories

### Access Control
- Privileged users, groups, and computers (adminCount=1)
- Resource-Based Constrained Delegation (RBCD)
- SID History analysis
- KeyCredentialLink detection
- DNS record creation permissions
- GPO folder rights review
- Domain/Enterprise/Backup/Server/Print Operators monitoring

### Authentication & Kerberos
- Kerberos delegation configurations
- Pre-authentication settings
- Service Principal Names (SPNs)
- Encryption type analysis
- Trust account delegation

### Account Management
- Disabled accounts with active sessions
- Stale accounts detection
- Password policy compliance
- Account expiration monitoring
- Privileged account tracking

### Computer & Server Management
- Domain controller inventory
- Server role analysis
- Computer account health
- Operating system versions
- Last logon tracking

### Group Policy
- GPO inventory and analysis
- Policy application tracking
- Security settings review
- GPO permissions audit

### Certificate Services & PKI
- Certificate authority monitoring
- Certificate template analysis
- Enrollment permissions
- Certificate expiration tracking

### Network Security
- SMB security configurations
- LDAP security settings
- Network service monitoring

### Compliance & Auditing
- Security baseline compliance
- Audit policy review
- Change tracking
- Compliance reporting

### Trust Management
- Domain trust relationships
- Forest trust analysis
- Trust authentication settings

### Azure AD Integration
- Hybrid identity monitoring
- Azure AD Connect health
- Synchronization status

### Advanced Security
- Persistence detection
- Anomaly identification
- Security event correlation

## Quick Start

### Web Application

1. **Prerequisites**
   - Node.js 18+ and npm
   - PowerShell 5.1 or PowerShell 7+
   - Windows Server with AD access

2. **Installation**
   ```powershell
   cd ad-suite-web
   npm install
   cd backend && npm install
   cd ../frontend && npm install
   ```

3. **Start the Application**
   ```powershell
   # Development mode
   npm run dev

   # Production mode
   npm run build
   npm start
   ```

4. **Access the Web Interface**
   - Open browser to `http://localhost:3000`
   - Navigate to "Run Scans" to execute security checks
   - View results in real-time with severity filtering

### Docker Deployment

See [ad-suite-web/INSTALL.md](ad-suite-web/INSTALL.md) for detailed Docker installation instructions.

```powershell
# Quick start with Docker
cd ad-suite-web/docker
docker-compose up -d
```

### Direct Script Execution

Each category folder contains ready-to-run scripts:

```powershell
# Example: Check privileged users
cd Access_Control/ACC-001_Privileged_Users_adminCount1
.\powershell.ps1

# Example: Analyze Kerberos delegation
cd Kerberos_Security/KRB-001_Kerberos_Delegation
.\powershell.ps1
```

## Project Structure

```
AD_suiteXXX/
├── Access_Control/          # Access control and permissions
├── Authentication/          # Authentication mechanisms
├── Account_Management/      # User account management
├── Computer_Management/     # Computer and server management
├── Computers_Servers/       # Server inventory and monitoring
├── Domain_Controllers/      # DC-specific checks
├── Group_Policy/           # GPO analysis
├── Certificate_Services/   # PKI and certificates
├── PKI_Services/           # Additional PKI checks
├── Kerberos_Security/      # Kerberos configurations
├── LDAP_Security/          # LDAP security settings
├── Network_Security/       # Network-level security
├── SMB_Security/           # SMB protocol security
├── Service_Accounts/       # Service account monitoring
├── Security_Accounts/      # Security principal analysis
├── Trust_Management/       # Domain trust relationships
├── Trust_Relationships/    # Trust configuration
├── Azure_AD_Integration/   # Hybrid identity
├── Compliance/             # Compliance checks
├── Advanced_Security/      # Advanced threat detection
├── Persistence_Detection/  # Persistence mechanism detection
├── Privileged_Access/      # Privileged access monitoring
├── Backup_Recovery/        # Backup and recovery
├── Infrastructure/         # Infrastructure monitoring
├── Published_Resources/    # Published resource tracking
├── Domain_Configuration/   # Domain settings
└── ad-suite-web/          # Web application
    ├── frontend/          # React frontend
    ├── backend/           # Node.js backend
    ├── docker/            # Docker configurations
    └── install/           # Installation scripts
```

## Documentation

- [Installation Guide](ad-suite-web/INSTALL.md) - Detailed installation instructions
- [Docker Guide](ad-suite-web/DOCK_WIN.md) - Windows container deployment
- [Scan Diagnostics](ad-suite-web/rem_term.md) - Troubleshooting scan issues
- [Implementation Guide](IMPLEMENTATION_GUIDE.md) - Development guidelines
- [Deployment Checklist](DEPLOYMENT_CHECKLIST.md) - Production deployment

## Script Formats

Each security check includes multiple implementation formats:

- **powershell.ps1** - Native PowerShell implementation
- **adsi.ps1** - ADSI-based queries (no AD module required)
- **csharp.cs** - C# implementation for advanced scenarios
- **cmd.bat** - Command-line batch scripts
- **combined_multiengine.ps1** - Multi-engine fallback support

## Web Application Features

### Scan Management
- Browse all security categories
- Execute scans with real-time progress
- Filter findings by severity
- Export results to JSON

### Diagnostics
- Pre-flight checks before scanning
- Script path validation
- PowerShell execution policy verification
- JSON conversion testing
- Engine-specific diagnostics

### Reporting
- Severity-based finding categorization
- Detailed finding information
- Export capabilities for compliance reporting

## Requirements

### Minimum Requirements
- Windows Server 2012 R2 or later
- PowerShell 5.1 or later
- Active Directory domain membership
- Read access to Active Directory

### Recommended Requirements
- Windows Server 2019 or later
- PowerShell 7.x
- Domain Admin or equivalent permissions (for full audit)
- 4GB RAM minimum
- 10GB free disk space

### For Web Application
- Node.js 18.x or later
- npm 9.x or later
- Modern web browser (Chrome, Edge, Firefox)

### For Docker Deployment
- Docker Desktop with Windows containers enabled
- Windows 10/11 Pro or Windows Server 2019+
- Hyper-V enabled

## Security Considerations

- **Least Privilege**: Run scans with minimum required permissions
- **Audit Logging**: All scan activities are logged
- **Data Protection**: Sensitive findings should be protected
- **Network Security**: Secure the web interface with HTTPS in production
- **Access Control**: Implement authentication for the web interface

## Contributing

This is a security auditing tool. When contributing:

1. Test all scripts in a lab environment first
2. Follow PowerShell best practices
3. Include error handling
4. Document all parameters and outputs
5. Add README.md to new check folders

## License

See [LICENSE](ad-suite-web/LICENSE) file for details.

## Support

For issues, questions, or contributions:
- Review existing documentation in each category folder
- Check the web application diagnostics feature
- Examine script output for detailed error messages

## Acknowledgments

Built for comprehensive Active Directory security assessment and monitoring, incorporating industry best practices and security frameworks.

---

**Note**: This tool is designed for authorized security assessments only. Always obtain proper authorization before running security scans against any Active Directory environment.
