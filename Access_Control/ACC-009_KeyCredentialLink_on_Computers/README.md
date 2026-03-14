# ACC-009: KeyCredentialLink on Computers

## Overview
This security check performs analysis for: **KeyCredentialLink on Computers**

**Category**: Access_Control  
**Check ID**: ACC-009  
**Severity**: INFO

## Description
This check queries Active Directory to identify objects related to KeyCredentialLink on Computers. The results can be used for security auditing, compliance verification, and risk assessment.

## Files Included

| File | Description | Method |
|------|-------------|--------|
| `adsi.ps1` | ADSI/DirectorySearcher implementation | No module required |
| `powershell.ps1` | ActiveDirectory module implementation | Requires AD module |
| `combined_multiengine.ps1` | Multi-engine with fallback | Auto-detects best method |
| `cmd.bat` | Batch file wrapper | Windows command line |
| `csharp.cs` | C# implementation | Requires compilation |
| `README.md` | This documentation file | - |

## Usage

### PowerShell (Recommended)
```powershell
# Basic usage
.\powershell.ps1

# With custom search base
.\powershell.ps1 -SearchBase "OU=Users,DC=domain,DC=com"

# Export results to CSV
.\powershell.ps1 -ExportPath "results.csv"
```

### ADSI (No module required)
```powershell
.\adsi.ps1
```

### Multi-Engine (Auto-detect)
```powershell
# Automatically uses best available method
.\combined_multiengine.ps1 -ExportPath "results.csv"
```

### Batch File
```cmd
cmd.bat
```

### C# (Requires compilation)
```cmd
csc /out:ACC-009.exe csharp.cs
ACC-009.exe
```

## Requirements

### PowerShell Scripts
- Windows PowerShell 5.1 or later
- `powershell.ps1` requires ActiveDirectory module
- `adsi.ps1` and `combined_multiengine.ps1` work without AD module

### C# Implementation
- .NET Framework 4.5 or later
- System.DirectoryServices assembly
- C# compiler (csc.exe)

## Output Format
All scripts return objects with the following properties:
- **CheckID**: The check identifier (ACC-009)
- **CheckName**: The check name (KeyCredentialLink on Computers)
- **Name**: Object name
- **DistinguishedName**: Full LDAP path
- **ObjectClass**: AD object class
- **WhenCreated**: Creation timestamp
- **WhenChanged**: Last modification timestamp

## Security Considerations
- Requires appropriate AD permissions to query objects
- Results may contain sensitive information
- Export files should be stored securely
- Review results for compliance with security policies

## Troubleshooting

### "ActiveDirectory module not found"
- Install RSAT (Remote Server Administration Tools)
- Or use `adsi.ps1` which doesn't require the module

### "Access Denied"
- Ensure you have read permissions in Active Directory
- Run as a user with appropriate AD privileges

### "No objects found"
- Verify the search base is correct
- Check LDAP filter syntax
- Ensure objects exist matching the criteria

## Related Checks
This check is part of the **Access_Control** category. Related checks:
- Review other checks in the same category for comprehensive coverage
- Combine results with other security checks for full assessment

## Version History
- **v1.0** - Initial implementation with comprehensive comments

## Support
For issues or questions about this check:
1. Review the troubleshooting section above
2. Check the main project documentation
3. Verify AD permissions and connectivity

---
**Check ID**: ACC-009  
**Category**: Access_Control  
**Last Updated**: 2026-02-24
