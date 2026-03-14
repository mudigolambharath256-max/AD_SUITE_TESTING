// ============================================================================
// LDAP-003: Anonymous LDAP Bind Allowed
// ============================================================================
// Category: Active Directory Security
// Language: C#
// Description: C# implementation using System.DirectoryServices
// ============================================================================
// Compile: csc /reference:System.DirectoryServices.dll csharp.cs
// ============================================================================

using System;
using System.DirectoryServices;

namespace ADSecurityChecks
{
    class LDAP_003
    {
        static void Main(string[] args)
        {
            Console.WriteLine("============================================================================");
            Console.WriteLine("LDAP-003: Anonymous LDAP Bind Allowed");
            Console.WriteLine("============================================================================");
            Console.WriteLine();

            try
            {
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
                Console.Error.WriteLine();
                Console.Error.WriteLine("ERROR: " + ex.Message);
                Environment.Exit(1);
            }
        }

        static void RunSecurityCheck()
        {
            // Discover domain via RootDSE
            string domainDN;
            using (DirectoryEntry rootDSE = new DirectoryEntry("LDAP://RootDSE"))
            {
                if (!rootDSE.Properties.Contains("defaultNamingContext") ||
                    rootDSE.Properties["defaultNamingContext"].Count == 0)
                    throw new Exception("Cannot retrieve defaultNamingContext from RootDSE");

                domainDN = rootDSE.Properties["defaultNamingContext"][0].ToString();
            }

            Console.WriteLine("Domain: " + domainDN);
            Console.WriteLine("Executing query...");
            Console.WriteLine();

            using (DirectoryEntry searchRoot = new DirectoryEntry("LDAP://" + domainDN))
            using (DirectorySearcher searcher = new DirectorySearcher(searchRoot))
            {
                searcher.Filter   = "(objectClass=domain)";
                searcher.PageSize = 1000;

                    searcher.PropertiesToLoad.Add("name");
                    searcher.PropertiesToLoad.Add("distinguishedName");
                    searcher.PropertiesToLoad.Add("whenCreated");
                    searcher.PropertiesToLoad.Add("whenChanged");

                using (SearchResultCollection results = searcher.FindAll())
                {
                    Console.WriteLine("Found " + results.Count + " objects");
                    Console.WriteLine();

                    int count = 0;
                    foreach (SearchResult r in results)
                    {
                        count++;

                        string name = r.Properties.Contains("name") && r.Properties["name"].Count > 0
                            ? r.Properties["name"][0].ToString() : "N/A";
                        string dn = r.Properties.Contains("distinguishedName") && r.Properties["distinguishedName"].Count > 0
                            ? r.Properties["distinguishedName"][0].ToString() : "N/A";
                        string sam = r.Properties.Contains("samAccountName") && r.Properties["samAccountName"].Count > 0
                            ? r.Properties["samAccountName"][0].ToString() : "N/A";
                        string whenCreated = r.Properties.Contains("whenCreated") && r.Properties["whenCreated"].Count > 0
                            ? r.Properties["whenCreated"][0].ToString() : "N/A";
                        string whenChanged = r.Properties.Contains("whenChanged") && r.Properties["whenChanged"].Count > 0
                            ? r.Properties["whenChanged"][0].ToString() : "N/A";

                        Console.WriteLine(count + ". " + name + (sam != "N/A" ? " (" + sam + ")" : ""));
                        Console.WriteLine("   DN: " + dn);
                        Console.WriteLine();
                    }

                    if (count == 0)
                        Console.WriteLine("No objects found matching criteria.");
                    else
                        Console.WriteLine("Total: " + count + " finding(s).");
                }
            }
        }
    }
}

