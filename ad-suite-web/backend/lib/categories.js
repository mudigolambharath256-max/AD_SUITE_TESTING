const CATEGORIES = [
    { id: "Access_Control", display: "Access Control", prefix: "ACC", checkCount: 45 },
    { id: "Advanced_Security", display: "Advanced Security", prefix: "ADV", checkCount: 10 },
    { id: "Authentication", display: "Authentication", prefix: "AUTH", checkCount: 33 },
    { id: "Azure_AD_Integration", display: "Azure AD Integration", prefix: "AAD", checkCount: 42 },
    { id: "Backup_Recovery", display: "Backup Recovery", prefix: "BCK", checkCount: 8 },
    { id: "Certificate_Services", display: "Certificate Services", prefix: "CERT", checkCount: 53 },
    { id: "Computer_Management", display: "Computer Management", prefix: "CMGMT", checkCount: 50 },
    { id: "Computers_Servers", display: "Computers & Servers", prefix: "CMP", checkCount: 60 },
    { id: "Domain_Configuration", display: "Domain Configuration", prefix: "DCONF", checkCount: 60 },
    { id: "Group_Policy", display: "Group Policy", prefix: "GPO", checkCount: 40 },
    { id: "Infrastructure", display: "Infrastructure", prefix: "INFRA", checkCount: 30 },
    { id: "Kerberos_Security", display: "Kerberos Security", prefix: "KRB", checkCount: 50 },
    { id: "LDAP_Security", display: "LDAP Security", prefix: "LDAP", checkCount: 25 },
    { id: "Miscellaneous", display: "Miscellaneous", prefix: "MISC", checkCount: 137 },
    { id: "Network_Security", display: "Network Security", prefix: "NET", checkCount: 30 },
    { id: "Privileged_Access", display: "Privileged Access", prefix: "PRV", checkCount: 50 },
    { id: "Service_Accounts", display: "Service Accounts", prefix: "SVC", checkCount: 40 },
    { id: "Users_Accounts", display: "Users & Accounts", prefix: "USR", checkCount: 70 },
];

const ENGINES = [
    {
        id: "adsi", label: "ADSI", file: "adsi.ps1", runner: "powershell",
        desc: "Pure .NET DirectorySearcher. No modules required. Fastest."
    },
    {
        id: "powershell", label: "PowerShell", file: "powershell.ps1", runner: "powershell",
        desc: "Requires ActiveDirectory RSAT module (Get-ADObject)."
    },
    {
        id: "csharp", label: "C#", file: "csharp.cs", runner: "csharp",
        desc: "Compiled .NET. Requires csc.exe (Framework) or dotnet SDK."
    },
    {
        id: "cmd", label: "CMD", file: "cmd.bat", runner: "cmd",
        desc: "Legacy CMD fallback. Uses dsquery and net commands."
    },
    {
        id: "combined", label: "Combined", file: "combined_multiengine.ps1", runner: "powershell",
        desc: "Auto-selects best available engine with graceful fallback."
    },
];

module.exports = {
    CATEGORIES,
    ENGINES
};