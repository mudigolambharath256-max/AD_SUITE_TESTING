// Check: Azure AD Integration Check 42
// Category: Azure AD Integration
// Severity: medium
// ID: AAD-042
// Requirements: System.DirectoryServices (.NET 4.6.2+ or .NET 6+)
// ============================================

using System;
using System.DirectoryServices;

class Program
{
    static string GetProp(SearchResult r, string attr)
    {
        return r.Properties.Contains(attr) && r.Properties[attr].Count > 0
            ? r.Properties[attr][0].ToString()
            : "";
    }

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
        string filter = @"(&(objectClass=user)(|(samAccountName=MSOL_*)(samAccountName=AAD_*)))";
        string[] props = new string[] { "name","distinguishedName","samAccountName" };

        try
        {
            using (DirectoryEntry rootEntry = new DirectoryEntry("LDAP://RootDSE"))
            {
                string targetNC = rootEntry.Properties["defaultNamingContext"].Value.ToString();

                using (DirectoryEntry searchEntry = new DirectoryEntry("LDAP://" + targetNC))
                using (DirectorySearcher searcher = new DirectorySearcher(searchEntry))
                {
                    searcher.Filter   = filter;
                    searcher.PageSize = 1000;
                    foreach (string p in props) searcher.PropertiesToLoad.Add(p);

                    using (SearchResultCollection results = searcher.FindAll())
                    {
                        Console.WriteLine("AAD-042: found " + results.Count + " objects");
                        // Fix R07: 5-field output header
                        Console.WriteLine("Name\tDistinguishedName\tSamAccountName\tDomain\tEngine");
                        foreach (SearchResult r in results)
                        {
                            string nm  = GetProp(r, "sAMAccountName");
                            if (string.IsNullOrEmpty(nm)) nm = GetProp(r, "name");
                            string dn  = GetProp(r, "distinguishedName");
                            string sam = GetProp(r, "sAMAccountName");
                            string dom = GetDomain(dn);
                            Console.WriteLine(nm + "\t" + dn + "\t" + sam + "\t" + dom + "\tCSharp");
                        }
                    }
                }
            }
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine("AAD-042 error: " + ex.Message);
            Environment.Exit(1);
        }
    }
}
