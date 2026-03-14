// DC-043: DCs Not Configured for Secure Time Sync
// Compile: csc /reference:System.DirectoryServices.dll csharp.cs

using System;
using System.DirectoryServices;
using System.DirectoryServices.ActiveDirectory;

class Program
{
    static void Main()
    {
        try
        {
            Console.WriteLine("DC-043: DCs Not Configured for Secure Time Sync");
            Console.WriteLine(new string('-', 60));
            
            // Get domain
            Domain domain = Domain.GetCurrentDomain();
            string domainDN = "DC=" + domain.Name.Replace(".", ",DC=");
            string pdcEmulator = domain.PdcRoleOwner.Name;
            
            Console.WriteLine("Domain: " + domain.Name);
            Console.WriteLine("PDC Emulator: " + pdcEmulator);
            Console.WriteLine();
            
            // Search for Domain Controllers
            using (DirectorySearcher searcher = new DirectorySearcher())
            {
                searcher.SearchRoot = new DirectoryEntry("LDAP://" + domainDN);
                searcher.Filter = "(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192))";
                searcher.PropertiesToLoad.Add("name");
                searcher.PropertiesToLoad.Add("dNSHostName");
                searcher.PropertiesToLoad.Add("objectSid");
                searcher.PageSize = 1000;
                
                SearchResultCollection results = searcher.FindAll();
                int issueCount = 0;
                
                foreach (SearchResult result in results)
                {
                    string name = result.Properties["name"][0].ToString();
                    string hostname = result.Properties["dNSHostName"][0].ToString();
                    bool isPDC = hostname.Equals(pdcEmulator, StringComparison.OrdinalIgnoreCase);
                    
                    Console.WriteLine("Checking: " + hostname + (isPDC ? " (PDC)" : ""));
                    
                    try
                    {
                        // Note: Full implementation requires WMI/Registry access
                        // This is a simplified version
                        Console.WriteLine("  [INFO] Full check requires remote registry/WMI access");
                        Console.WriteLine("  [INFO] Use PowerShell version for complete functionality");

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
                        Console.WriteLine("  [ERROR] " + ex.Message);
                    }
                }
                
                Console.WriteLine();
                if (issueCount > 0)
                {
                    Console.WriteLine("Found " + issueCount + " Domain Controllers with time sync issues.");
                }
                else
                {
                    Console.WriteLine("No time sync issues detected (limited check).");
                }
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine("Error: " + ex.Message);
        }
    }
}

