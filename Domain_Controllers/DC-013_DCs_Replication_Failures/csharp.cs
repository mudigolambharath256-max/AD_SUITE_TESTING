// Check: DCs Replication Failures
// Category: Domain Controllers
// Severity: critical
// ID: DC-013
// Requirements: Compile with System.DirectoryServices
// ============================================
// Query: nTDSDSA objects in Configuration NC for replication metadata

using System;
using System.DirectoryServices;

class Program
{
    static void Main()
    {
        try
        {
            using (var root = new DirectoryEntry("LDAP://RootDSE"))
            {
                string domainNC = root.Properties["defaultNamingContext"].Value.ToString();
                string configNC = root.Properties["configurationNamingContext"].Value.ToString();
                
                Console.WriteLine("=== Domain Controllers Replication Analysis ===");
                Console.WriteLine();
                
                // First get all Domain Controllers
                using (var dcSearchBase = new DirectoryEntry("LDAP://" + domainNC))
                using (var dcSearcher = new DirectorySearcher(dcSearchBase))
                {
                    dcSearcher.Filter = "(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192))";
                    dcSearcher.PageSize = 1000;
                    dcSearcher.PropertiesToLoad.Add("name");
                    dcSearcher.PropertiesToLoad.Add("distinguishedName");
                    dcSearcher.PropertiesToLoad.Add("dNSHostName");
                    
                    var dcResults = dcSearcher.FindAll();

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
                    Console.WriteLine($"Found {dcResults.Count} Domain Controllers");
                    Console.WriteLine();
                    
                    // Query NTDS Settings objects in Configuration NC
                    using (var configSearchBase = new DirectoryEntry("LDAP://" + configNC))
                    using (var ntdsSearcher = new DirectorySearcher(configSearchBase))
                    {
                        ntdsSearcher.Filter = "(&(objectClass=nTDSDSA)(|(cn=NTDS Settings)(name=NTDS Settings)))";
                        ntdsSearcher.PageSize = 1000;
                        ntdsSearcher.PropertiesToLoad.Add("distinguishedName");
                        ntdsSearcher.PropertiesToLoad.Add("repsFrom");
                        ntdsSearcher.PropertiesToLoad.Add("repsTo");
                        ntdsSearcher.PropertiesToLoad.Add("whenChanged");
                        searcher.PropertiesToLoad.Add("objectSid");
                        
                        var ntdsResults = ntdsSearcher.FindAll();
                        Console.WriteLine($"Found {ntdsResults.Count} NTDS Settings objects");
                        Console.WriteLine();
                        
                        bool foundIssues = false;
                        
                        foreach (SearchResult dc in dcResults)
                        {
                            string dcName = Get(dc, "name");
                            string dcDN = Get(dc, "distinguishedName");
                            string dcDNS = Get(dc, "dNSHostName");
                            
                            // Find corresponding NTDS Settings
                            foreach (SearchResult ntds in ntdsResults)
                            {
                                string ntdsDN = Get(ntds, "distinguishedName");
                                
                                if (ntdsDN.Contains(dcName))
                                {
                                    int repsFromCount = ntds.Properties.Contains("repsFrom") ? ntds.Properties["repsFrom"].Count : 0;
                                    int repsToCount = ntds.Properties.Contains("repsTo") ? ntds.Properties["repsTo"].Count : 0;
                                    string lastChanged = Get(ntds, "whenChanged");
                                    
                                    // Check for potential issues
                                    bool hasIssue = false;
                                    string issueReason = "";
                                    
                                    if (repsFromCount == 0)
                                    {
                                        hasIssue = true;
                                        issueReason += "No inbound replication partners; ";
                                    }
                                    
                                    if (lastChanged != "(not set)")
                                    {
                                        try
                                        {
                                            DateTime lastChangedDate = DateTime.Parse(lastChanged);
                                            double hoursSince = (DateTime.Now - lastChangedDate).TotalHours;
                                            
                                            if (hoursSince > 4)
                                            {
                                                hasIssue = true;
                                                issueReason += $"Last replication > 4 hours ago ({hoursSince:F2} hours); ";
                                            }
                                        }
                                        catch
                                        {
                                            issueReason += "Unable to parse last replication time; ";
                                        }
                                    }
                                    
                                    if (hasIssue)
                                    {
                                        foundIssues = true;
                                        Console.WriteLine("REPLICATION ISSUE DETECTED:");
                                        Console.WriteLine($"  DC Name           : {dcName}");
                                        Console.WriteLine($"  DNS Host Name     : {dcDNS}");
                                        Console.WriteLine($"  Distinguished Name: {dcDN}");
                                        Console.WriteLine($"  NTDS Settings DN  : {ntdsDN}");
                                        Console.WriteLine($"  Inbound Partners  : {repsFromCount}");
                                        Console.WriteLine($"  Outbound Partners : {repsToCount}");
                                        Console.WriteLine($"  Last Changed      : {lastChanged}");
                                        Console.WriteLine($"  Issue Reason      : {issueReason.TrimEnd(' ', ';')}");
                                        Console.WriteLine(new string('-', 80));
                                    }
                                }
                            }
                        }
                        
                        if (!foundIssues)
                        {
                            Console.WriteLine("No replication failures detected");
                        }
                    }
                }
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error querying replication status: {ex.Message}");
            Environment.Exit(1);
        }
    }
    
    static string Get(SearchResult r, string attr)
    {
        return r.Properties.Contains(attr) && r.Properties[attr].Count > 0
            ? r.Properties[attr][0].ToString()
            : "(not set)";
    }
}
