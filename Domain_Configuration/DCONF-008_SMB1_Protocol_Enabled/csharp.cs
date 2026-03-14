// ============================================================
// CHECK: DCONF-008_SMB1_Protocol_Enabled
// CATEGORY: Domain_Configuration
// DESCRIPTION: Checks if SMB1 protocol is enabled (critical security risk)
// LDAP FILTER: (&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192))
// SEARCH BASE: Default NC
// OBJECT CLASS: computer
// ATTRIBUTES: name, dNSHostName, distinguishedName
// RISK: CRITICAL
// MITRE ATT&CK: T1021.002 (Remote Services: SMB/Windows Admin Shares)
// ============================================================

using System;
using System.Collections.Generic;
using System.DirectoryServices;
using System.Management;

class DCONF008
{
    static void Main()
    {
        try
        {
            Console.WriteLine("[DCONF-008] Checking SMB1 Protocol Configuration...");
            
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
                        List<string> smb1Issues = CheckSMB1Settings(dcName);
                        
                        if (smb1Issues.Count > 0)
                        {
                            Console.WriteLine($"[FINDING] {dcName}");
                            Console.WriteLine($"  CheckID: DCONF-008");
                            Console.WriteLine($"  ObjectDN: {dcDN}");
                            Console.WriteLine($"  FindingDetail: SMB1 enabled: {string.Join("; ", smb1Issues)}");
                            Console.WriteLine($"  Severity: CRITICAL");
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
    
    static List<string> CheckSMB1Settings(string dcName)
    {
        List<string> issues = new List<string>();
        
        try
        {
            // Connect to remote registry via WMI
            ManagementScope scope = new ManagementScope($"\\\\{dcName}\\root\\default");
            scope.Connect();
            
            ManagementClass registry = new ManagementClass(scope, new ManagementPath("StdRegProv"), null);
            
            // Check SMB1 server setting
            ManagementBaseObject serverParams = registry.GetMethodParameters("GetDWORDValue");
            serverParams["hDefKey"] = 0x80000002; // HKEY_LOCAL_MACHINE
            serverParams["sSubKeyName"] = @"SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters";
            serverParams["sValueName"] = "SMB1";
            
            ManagementBaseObject serverResult = registry.InvokeMethod("GetDWORDValue", serverParams, null);
            
            if ((uint)serverResult["ReturnValue"] == 0)
            {
                uint smb1Value = (uint)serverResult["uValue"];
                if (smb1Value != 0)
                {
                    issues.Add($"SMB1 Server enabled (SMB1={smb1Value})");
                }
            }
            else
            {
                // If registry value doesn't exist, SMB1 may be enabled by default
                issues.Add("SMB1 Server setting not found (may be enabled by default)");
            }
            
            // Check SMB1 client via mrxsmb10 service
            ManagementBaseObject clientParams = registry.GetMethodParameters("GetDWORDValue");
            clientParams["hDefKey"] = 0x80000002; // HKEY_LOCAL_MACHINE
            clientParams["sSubKeyName"] = @"SYSTEM\CurrentControlSet\Services\mrxsmb10";
            clientParams["sValueName"] = "Start";
            
            ManagementBaseObject clientResult = registry.InvokeMethod("GetDWORDValue", clientParams, null);
            
            if ((uint)clientResult["ReturnValue"] == 0)
            {
                uint startValue = (uint)clientResult["uValue"];
                if (startValue != 4) // 4 = Disabled
                {
                    issues.Add($"SMB1 Client enabled (mrxsmb10 Start={startValue})");
                }
            }
        }
        catch (Exception ex)
        {
            issues.Add($"Error checking SMB1 status: {ex.Message}");
        }
        
        return issues;
    }
}
