// Check: DCs LDAP Channel Binding Disabled
// Category: Domain Controllers
// Severity: high
// ID: DC-011
// Requirements: Compile with System.DirectoryServices
// ============================================
// Registry: HKLM\SYSTEM\CurrentControlSet\Services\NTDS\Parameters\LdapEnforceChannelBinding

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

                    Console.WriteLine("=== DCs LDAP Channel Binding Disabled ===");
                    Console.WriteLine();

                    int dcCount = 0;
                    int findingCount = 0;

                    foreach (SearchResult r in searcher.FindAll())
                    {
                        dcCount++;
                        string name = Get(r, "name");
                        string dn = Get(r, "distinguishedName");
                        string dnsHostName = Get(r, "dNSHostName");
                        string os = Get(r, "operatingSystem");

                        if (dnsHostName == "(not set)")
                        {
                            Console.WriteLine($"Warning: Skipping DC with no DNS hostname: {name}");
                            continue;
                        }

                        try
                        {
                            // Check LDAP channel binding registry key via remote registry
                            using (RegistryKey remoteKey = RegistryKey.OpenRemoteBaseKey(RegistryHive.LocalMachine, dnsHostName))
                            using (RegistryKey ntdsKey = remoteKey.OpenSubKey(@"SYSTEM\CurrentControlSet\Services\NTDS\Parameters"))
                            {
                                object channelBinding = null;
                                if (ntdsKey != null)
                                {
                                    channelBinding = ntdsKey.GetValue("LdapEnforceChannelBinding");
                                }

                                int bindingValue = -1;
                                if (channelBinding != null)
                                {
                                    int.TryParse(channelBinding.ToString(), out bindingValue);
                                }

                                // Flag if LDAP channel binding is not always enforced (value < 2)
                                if (bindingValue < 2)
                                {
                                    findingCount++;
                                    Console.WriteLine("Name              : " + name);
                                    Console.WriteLine("DistinguishedName : " + dn);
                                    Console.WriteLine("DNSHostName       : " + dnsHostName);
                                    Console.WriteLine("OperatingSystem   : " + os);
                                    Console.WriteLine("ChannelBindingLevel : " + GetBindingLevel(bindingValue));
                                    Console.WriteLine("RegistryValue     : " + (channelBinding?.ToString() ?? "Key Not Found"));
                                    Console.WriteLine("Severity          : HIGH");
                                    Console.WriteLine("MITRE             : T1557");
                                    Console.WriteLine(new string('-', 60));
                                }
                            }
                        }
                        catch (Exception ex)
                        {
                            // Handle remote registry access failures as UNKNOWN (not PASS)
                            findingCount++;
                            Console.WriteLine($"Warning: Unable to check LDAP channel binding on {dnsHostName}: {ex.Message}");
                            Console.WriteLine("Name              : " + name);
                            Console.WriteLine("DistinguishedName : " + dn);
                            Console.WriteLine("DNSHostName       : " + dnsHostName);
                            Console.WriteLine("OperatingSystem   : " + os);
                            Console.WriteLine("ChannelBindingLevel : UNKNOWN - Registry Unavailable");
                            Console.WriteLine("RegistryValue     : Access Denied");
                            Console.WriteLine("Severity          : UNKNOWN");
                            Console.WriteLine("MITRE             : T1557");
                            Console.WriteLine(new string('-', 60));
                        }
                    }

                    Console.WriteLine();
                    Console.WriteLine($"Found {dcCount} Domain Controllers");
                    if (findingCount > 0)
                    {
                        Console.WriteLine($"Summary: Found {findingCount} Domain Controllers with LDAP channel binding issues");
                    }
                    else
                    {
                        Console.WriteLine("No findings - All Domain Controllers have LDAP channel binding properly configured");
                    }
                }
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Active Directory query failed: {ex.Message}");
            Environment.Exit(1);
        }
    }

    static string Get(SearchResult r, string attr)
    {
        return r.Properties.Contains(attr) && r.Properties[attr].Count > 0
            ? r.Properties[attr][0].ToString()
            : "(not set)";
    }

    static string GetBindingLevel(int value)
    {
        switch (value)
        {
            case 0: return "Never";
            case 1: return "When Supported";
            case 2: return "Always";
            default: return "Unknown/Not Set";
        }
    }
}
