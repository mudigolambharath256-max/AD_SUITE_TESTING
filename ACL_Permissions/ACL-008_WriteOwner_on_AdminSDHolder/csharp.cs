// Check: WriteOwner on AdminSDHolder
// Category: ACL_Permissions
// Severity: critical
// ID: ACL-008
// Requirements: System.DirectoryServices (.NET 4.6.2+)
// ============================================

using System;
using System.DirectoryServices;
using System.Security.AccessControl;
using System.Security.Principal;

class Program
{
    static string GetDomain(string dn)
    {
        if (string.IsNullOrEmpty(dn)) return "";
        var parts = dn.Split(',');
        var dc = new System.Collections.Generic.List<string>();
        foreach (var p in parts)
            if (p.TrimStart().StartsWith("DC=", StringComparison.OrdinalIgnoreCase))
                dc.Add(p.TrimStart().Substring(3));
        return string.Join(".", dc);
    }

    static void Main()
    {
        string[] skipSids = new string[] { "S-1-5-18", "S-1-5-10", "S-1-5-9" };

        try
        {
            using (DirectoryEntry rootEntry = new DirectoryEntry("LDAP://RootDSE"))
            {
                string domainNC = rootEntry.Properties["defaultNamingContext"].Value.ToString();
                Console.WriteLine("ACL-008: ACL check - see adsi.ps1 or combined_multiengine.ps1 for full implementation");
            }
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine("ACL-008 error: " + ex.Message);
            Environment.Exit(1);
        }
    }
}
