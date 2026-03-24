// Check: DCSync Rights DS-Replication-Get-Changes-All
// Category: ACL_Permissions
// Severity: critical
// ID: ACL-005
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
        Guid dcsyncAllGuid = new Guid("1131f6ad-9c07-11d1-f79f-00c04fc2dcd2");
        Guid dcsyncGuid = new Guid("1131f6aa-9c07-11d1-f79f-00c04fc2dcd2");

        try
        {
            using (DirectoryEntry rootEntry = new DirectoryEntry("LDAP://RootDSE"))
            {
                string domainNC = rootEntry.Properties["defaultNamingContext"].Value.ToString();
                string targetDN = domainNC;

                using (DirectoryEntry targetEntry = new DirectoryEntry("LDAP://" + targetDN))
                {
                    ActiveDirectorySecurity acl = targetEntry.ObjectSecurity;
                    AuthorizationRuleCollection rules = acl.GetAccessRules(true, true, typeof(SecurityIdentifier));

                    Console.WriteLine("ACL-005: scanning ACL on " + targetDN);
                    Console.WriteLine("Name\tDistinguishedName\tSamAccountName\tDomain\tEngine\tRights\tTargetObject\tTrusteeSID");

                    int count = 0;
                    foreach (ActiveDirectoryAccessRule rule in rules)
                    {
                        if (rule.AccessControlType != AccessControlType.Allow) continue;
                        if ((rule.ActiveDirectoryRights & ActiveDirectoryRights.ExtendedRight) == 0) continue;
                        
                        string rightsDesc = "";
                        if (rule.ObjectType == dcsyncAllGuid)
                            rightsDesc = "DS-Replication-Get-Changes-All (DCSync)";
                        else if (rule.ObjectType == dcsyncGuid)
                            rightsDesc = "DS-Replication-Get-Changes (DCSync)";
                        else
                            continue;

                        string sid = rule.IdentityReference.Value;
                        bool skip = false;
                        foreach (var s in skipSids) if (sid == s) { skip = true; break; }
                        if (skip) continue;

                        string name = sid;
                        try { name = new SecurityIdentifier(sid).Translate(typeof(NTAccount)).Value; } catch { }

                        string dom = GetDomain(targetDN);
                        Console.WriteLine(name + "\t" + targetDN.ToUpper() + "\t" + name + "\t" + dom + "\tCSharp\t" + rightsDesc + "\t" + targetDN + "\t" + sid);
                        count++;
                    }
                    Console.WriteLine("ACL-005: found " + count + " trustees");
                }
            }
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine("ACL-005 error: " + ex.Message);
            Environment.Exit(1);
        }
    }
}
