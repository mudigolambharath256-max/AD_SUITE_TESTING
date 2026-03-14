// ============================================================
// CHECK: DCONF-007_NTLMv1_Protocol_Allowed
// CATEGORY: Domain_Configuration
// DESCRIPTION: Checks if NTLMv1 authentication is allowed (security risk)
// LDAP FILTER: (&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192))
// SEARCH BASE: Default NC
// OBJECT CLASS: computer
// ATTRIBUTES: name, dNSHostName, distinguishedName
// RISK: HIGH
// MITRE ATT&CK: T1557.001 (LLMNR/NBT-NS Poisoning and SMB Relay)
// ============================================================

using System;
using System.DirectoryServices;
using System.Management;

class DCONF007
{
    static void Main()
    {
        try
        {
            Console.WriteLine("[DCONF-007] Checking NTLMv1 Protocol Configuration...");
            
            // Enumerate domain controllers
            using (DirectorySearcher searcher = new DirectorySearcher())
            {
                searcher.Filter = "(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192))";
                searcher.PropertiesToLoad.Add("name");
                searcher.PropertiesToLoad.Add("dNSHostName");
                searcher.PropertiesToLoad.Add("distinguishedName");
                
                SearchResultCollection results = searcher.FindAll();

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
                Console.WriteLine($"Found {results.Count} domain controllers to check");
                
                foreach (SearchResult result in results)
                {
                    string dcName = result.Properties["dNSHostName"][0].ToString();
                    string dcDN = result.Properties["distinguishedName"][0].ToString();
                    
                    try
                    {
                        // Connect to remote registry via WMI
                        ManagementScope scope = new ManagementScope($"\\\\{dcName}\\root\\default");
                        scope.Connect();
                        
                        ManagementClass registry = new ManagementClass(scope, new ManagementPath("StdRegProv"), null);
                        ManagementBaseObject inParams = registry.GetMethodParameters("GetDWORDValue");
                        inParams["hDefKey"] = 0x80000002; // HKEY_LOCAL_MACHINE
                        inParams["sSubKeyName"] = @"SYSTEM\CurrentControlSet\Control\Lsa";
                        inParams["sValueName"] = "LmCompatibilityLevel";
                        
                        ManagementBaseObject outParams = registry.InvokeMethod("GetDWORDValue", inParams, null);
                        
                        uint lmLevel = 0;
                        if ((uint)outParams["ReturnValue"] == 0)
                        {
                            lmLevel = (uint)outParams["uValue"];
                        }
                        
                        if (lmLevel < 5)
                        {
                            string levelDescription = GetLevelDescription(lmLevel);
                            string severity = lmLevel <= 2 ? "CRITICAL" : (lmLevel <= 4 ? "HIGH" : "MEDIUM");
                            
                            Console.WriteLine($"[FINDING] {dcName}");
                            Console.WriteLine($"  CheckID: DCONF-007");
                            Console.WriteLine($"  ObjectDN: {dcDN}");
                            Console.WriteLine($"  FindingDetail: LmCompatibilityLevel: {lmLevel} - {levelDescription}");
                            Console.WriteLine($"  Severity: {severity}");
                            Console.WriteLine($"  Timestamp: {DateTime.UtcNow:yyyy-MM-ddTHH:mm:ss.fffZ}");
                            Console.WriteLine();
                        }
                    }
                    catch (Exception ex)
                    {
                        Console.WriteLine($"Warning: Could not check {dcName}: {ex.Message}");
                    }
                }
                
                results.Dispose();
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error: {ex.Message}");
            Environment.Exit(1);
        }
    }
    
    static string GetLevelDescription(uint level)
    {
        switch (level)
        {
            case 0: return "Send LM and NTLM responses (CRITICAL)";
            case 1: return "Send LM and NTLM with NTLMv2 session security (HIGH)";
            case 2: return "Send NTLM response only (HIGH)";
            case 3: return "Send NTLMv2 response only (MEDIUM)";
            case 4: return "Send NTLMv2 response only, refuse LM (MEDIUM)";
            default: return $"Unknown level {level}";
        }
    }
}
