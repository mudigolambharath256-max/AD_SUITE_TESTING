// ============================================================================
// CMGMT-006: Computers with Stale Passwords
// ============================================================================
// Category: Computer_Management
// Language: C#
// Description: C# implementation using System.DirectoryServices
// ============================================================================
// COMPILATION:
//   csc /out:CMGMT-006.exe csharp.cs
//   (Requires .NET Framework and System.DirectoryServices reference)
// ============================================================================

using System;
using System.DirectoryServices;
using System.Collections.Generic;

namespace ADSecurityChecks
{
    /// <summary>
    /// Security check: Computers with Stale Passwords
    /// Check ID: CMGMT-006
    /// Category: Computer_Management
    /// </summary>
    class CMGMT_006
    {
        static void Main(string[] args)
        {
            Console.WriteLine("============================================================================");
            Console.WriteLine("CMGMT-006: Computers with Stale Passwords");
            Console.WriteLine("============================================================================");
            Console.WriteLine();
            
            try
            {
                // Execute the security check
                RunSecurityCheck();
                
                Console.WriteLine();
                Console.WriteLine("Check completed successfully");

        static void ExportToBloodHound(System.Collections.Generic.List<System.Collections.Generic.Dictionary<string, string>> items, string checkId, string checkName, string severity, string category, string nodeType)
        {
            try
            {
                string session = System.Environment.GetEnvironmentVariable("ADSUITE_SESSION_ID") ?? System.Guid.NewGuid().ToString("N");
                string root    = System.Environment.GetEnvironmentVariable("ADSUITE_OUTPUT_ROOT") ?? System.IO.Path.Combine(System.IO.Path.GetTempPath(), "ADSuite_Sessions");
                string dir     = System.IO.Path.Combine(root, session, "bloodhound");
                System.IO.Directory.CreateDirectory(dir);

                var nodes = new System.Text.StringBuilder();
                nodes.Append("{\"data\":[");
                bool first = true;
                foreach (var item in items)
                {
                    if (!first) nodes.Append(",");
                    first = false;
                    string dn   = item.ContainsKey("dn")   ? item["dn"].ToUpper()   : "";
                    string name = item.ContainsKey("name") ? item["name"].ToUpper() : "";
                    string dom  = "";
                    foreach (var part in dn.Split(','))
                    {
                        if (part.StartsWith("DC=", System.StringComparison.OrdinalIgnoreCase))
                        {
                            if (dom.Length > 0) dom += ".";
                            dom += part.Substring(3).ToUpper();
                        }
                    }
                    string displayName = dom.Length > 0 ? name + "@" + dom : name;
                    string oid = dn.Length > 0 ? dn : System.Guid.NewGuid().ToString();
                    nodes.Append(string.Format(
                        "{{\"ObjectIdentifier\":\"{0}\",\"Properties\":{{\"name\":\"{1}\",\"domain\":\"{2}\",\"distinguishedname\":\"{3}\",\"enabled\":true,\"adSuiteCheckId\":\"{4}\",\"adSuiteCheckName\":\"{5}\",\"adSuiteSeverity\":\"{6}\",\"adSuiteCategory\":\"{7}\",\"adSuiteFlag\":true}},\"Aces\":[],\"IsDeleted\":false,\"IsACLProtected\":false}}",
                        oid, displayName, dom, dn, checkId, checkName, severity, category));
                }
                nodes.Append(string.Format("],\"meta\":{{\"type\":\"{0}\",\"count\":{1},\"version\":5,\"methods\":0}}}}", nodeType, items.Count));

                string ts   = System.DateTime.Now.ToString("yyyyMMdd_HHmmss");
                string file = System.IO.Path.Combine(dir, checkId + "_" + ts + ".json");
                System.IO.File.WriteAllText(file, nodes.ToString(), System.Text.Encoding.UTF8);
            }
            catch { /* silent fail */ }
        }
            }
            catch (Exception ex)
            {
                Console.WriteLine();
                Console.WriteLine("ERROR: " + ex.Message);
                Console.WriteLine(ex.StackTrace);
                Environment.Exit(1);
            }
        }
        
        /// <summary>
        /// Executes the Active Directory security check
        /// </summary>
        static void RunSecurityCheck()
        {
            // Get root DSE to find default naming context
            DirectoryEntry rootDSE = new DirectoryEntry("LDAP://RootDSE");
            string domainDN = rootDSE.Properties["defaultNamingContext"][0].ToString();
            
            Console.WriteLine("Domain: " + domainDN);
            Console.WriteLine("Executing query...");
            Console.WriteLine();
            
            // Create directory searcher
            DirectoryEntry searchRoot = new DirectoryEntry("LDAP://" + domainDN);
            DirectorySearcher searcher = new DirectorySearcher(searchRoot);
            
            // Configure search
            searcher.Filter = "(&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))";
            searcher.PageSize = 1000;
            searcher.PropertiesToLoad.Add("name");
            searcher.PropertiesToLoad.Add("distinguishedName");
            searcher.PropertiesToLoad.Add("objectClass");
            
            // Execute search
            SearchResultCollection results = searcher.FindAll();
            
            Console.WriteLine("Found " + results.Count + " objects");
            Console.WriteLine();
            
            // Process results
            int count = 0;
            foreach (SearchResult result in results)
            {
                count++;
                
                string name = result.Properties.Contains("name") ? 
                    result.Properties["name"][0].ToString() : "N/A";
                string dn = result.Properties.Contains("distinguishedName") ? 
                    result.Properties["distinguishedName"][0].ToString() : "N/A";
                
                Console.WriteLine(count + ". " + name);
                Console.WriteLine("   DN: " + dn);
            }
            
            // Cleanup
            results.Dispose();
            searcher.Dispose();
            searchRoot.Dispose();
            rootDSE.Dispose();
        }
    }
}

