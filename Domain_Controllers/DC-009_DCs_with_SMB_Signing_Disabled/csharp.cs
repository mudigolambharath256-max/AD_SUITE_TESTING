// Check: DCs with SMB Signing Disabled
// Category: Domain Controllers
// Severity: critical
// ID: DC-009
// Requirements: Compile with System.DirectoryServices
// ============================================
// Registry: HKLM\SYSTEM\CurrentControlSet\Services\LanManServer\Parameters\requireSecuritySignature

using System;
using System.DirectoryServices;
using Microsoft.Win32;

class Program
{
    static void Main()
    {
        string filter = @"(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192))";

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
        string[] props = new string[] { "name", "distinguishedName", "dNSHostName", "operatingSystem", "userAccountControl" };

        try
        {
            using (var root = new DirectoryEntry("LDAP://RootDSE"))
            {
                string domainNC = root.Properties["defaultNamingContext"].Value.ToString();
                using (var searchBase = new DirectoryEntry("LDAP://" + domainNC))
                using (var searcher = new DirectorySearcher(searchBase))
                {
                    searcher.Filter = filter;
                    searcher.PageSize = 1000;
                    foreach (var p in props) searcher.PropertiesToLoad.Add(p);

                    var results = searcher.FindAll();
                    Console.WriteLine($"Found {results.Count} Domain Controllers");
                    Console.WriteLine();

                    Console.WriteLine("Name,DNSHostName,SMBSigningStatus,RegistryValue,Severity,MITRE");
                    Console.WriteLine(new string('-', 80));

                    foreach (SearchResult r in results)
                    {
                        string name = Get(r, "name");
                        string dnsHostName = Get(r, "dNSHostName");
                        string operatingSystem = Get(r, "operatingSystem");

                        if (dnsHostName == "(not set)")
                        {
                            Console.WriteLine($"WARNING: Skipping DC with no DNS hostname: {name}");
                            continue;
                        }

                        try
                        {
                            // Check SMB signing registry key via remote registry
                            using (var regKey = RegistryKey.OpenRemoteBaseKey(RegistryHive.LocalMachine, dnsHostName))
                            {
                                using (var subKey = regKey.OpenSubKey(@"SYSTEM\CurrentControlSet\Services\LanManServer\Parameters"))
                                {
                                    if (subKey != null)
                                    {
                                        object smbSigningValue = subKey.GetValue("requireSecuritySignature");
                                        
                                        if (smbSigningValue != null)
                                        {
                                            int smbSigningRequired = Convert.ToInt32(smbSigningValue);
                                            
                                            // Flag if SMB signing is not required (value != 1)
                                            if (smbSigningRequired != 1)
                                            {
                                                string status = smbSigningRequired == 0 ? "Disabled" : "Unknown/Not Set";
                                                Console.WriteLine($"{name},{dnsHostName},{status},{smbSigningRequired},CRITICAL,T1557.001");
                                            }
                                        }
                                        else
                                        {
                                            Console.WriteLine($"{name},{dnsHostName},Unknown/Not Set,Key Not Found,CRITICAL,T1557.001");
                                        }
                                    }
                                    else
                                    {
                                        Console.WriteLine($"{name},{dnsHostName},Unknown/Not Set,Registry Path Not Found,CRITICAL,T1557.001");
                                    }
                                }
                            }
                        }
                        catch (Exception ex)
                        {
                            // Handle remote registry access failures as UNKNOWN (not PASS)
                            Console.WriteLine($"{name},{dnsHostName},UNKNOWN - Registry Unavailable,Access Denied,UNKNOWN,T1557.001");
                            Console.WriteLine($"WARNING: Unable to check SMB signing on {dnsHostName}: {ex.Message}");
                        }
                    }

                    Console.WriteLine();
                    Console.WriteLine("=== Check Complete ===");
                    Console.WriteLine("NOTE: DCs with SMB signing disabled are vulnerable to SMB relay attacks (MITRE T1557.001)");
                }
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"ERROR: Active Directory query failed: {ex.Message}");
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
