// Check: Computers with userPassword Attribute
// Category: Computers & Servers
// Severity: high
// ID: CMP-021
// Requirements: Compile with System.DirectoryServices
// ============================================

// LDAP search (C# DirectorySearcher)
using System;
using System.DirectoryServices;

class Program
{
  static void Main()
  {
    string filter = @"(&(objectCategory=computer)(userPassword=*))";
    string[] props = new string[] { "name", "distinguishedName", "samAccountName", "userPassword" };

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
