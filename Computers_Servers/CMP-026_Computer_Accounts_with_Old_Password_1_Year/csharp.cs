// Check: Computer Accounts with Old Password (1+ Year)
// Category: Computers & Servers
// Severity: medium
// ID: CMP-026
// Requirements: Compile with System.DirectoryServices
// ============================================

// LDAP search (C# DirectorySearcher)
using System;
using System.DirectoryServices;

class Program
{
  static void Main()
  {
    string filter = @"(&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))";
    string[] props = new string[] { "name", "distinguishedName", "samAccountName", "pwdLastSet", "operatingSystem" };

    using (var root = new DirectoryEntry("LDAP://RootDSE"))
    using (var domain = new DirectoryEntry("LDAP://" + root.Properties["defaultNamingContext"].Value))
    using (var searcher = new DirectorySearcher(domain))
    {
      searcher.Filter = filter;
      searcher.PageSize = 1000;
      foreach (var p in props) searcher.PropertiesToLoad.Add(p);

      foreach (SearchResult r in searcher.FindAll())
      {
        var name = r.Properties.Contains("name") && r.Properties["name"].Count > 0 ? r.Properties["name"][0].ToString() : "(no name)";
        Console.WriteLine(name);
      }
    }
  }
}
