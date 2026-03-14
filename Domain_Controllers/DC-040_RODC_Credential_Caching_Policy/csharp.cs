/*
=============================================================================
DC-040: RODC Credential Caching Policy
=============================================================================
Category: Domain Controllers
Severity: HIGH
ID: DC-040
MITRE: T1552.004 (Unsecured Credentials: Private Keys)
=============================================================================
Description: Detects Read-Only Domain Controllers (RODCs) with insecure 
             credential caching policies using C# DirectoryServices.
=============================================================================
LDAP Filter: (&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=67108864))
Search Base: Default NC
Object Class: computer
Attributes: name, distinguishedName, dNSHostName, msDS-NeverRevealGroup, 
            msDS-RevealOnDemandGroup, msDS-RevealedList
=============================================================================
*/

using System;
using System.DirectoryServices;
using System.Collections.Generic;
using System.Linq;

public class DC040_RODCCredentialCachingPolicy
{
    public static void Main()
    {
        try
        {
            Console.WriteLine("=============================================================================");
            Console.WriteLine("DC-040: RODC Credential Caching Policy Check");
            Console.WriteLine("=============================================================================");
            Console.WriteLine();

            // Get forest domains for comprehensive RODC detection
            var forest = System.DirectoryServices.ActiveDirectory.Forest.GetCurrentForest();
            var allResults = new List<RODCResult>();
            
            foreach (var domain in forest.Domains)
            {

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
                Console.WriteLine($"Checking domain: {domain.Name}");
                
                try
                {
                    string domainDN = $"DC={domain.Name.Replace(".", ",DC=")}";
                    string ldapPath = $"LDAP://{domain.Name}/{domainDN}";
                    
                    using (var domainEntry = new DirectoryEntry(ldapPath))
                    using (var searcher = new DirectorySearcher(domainEntry))
                    {
                        // Search for RODCs using UAC bit 67108864 (PARTIAL_SECRETS_ACCOUNT)
                        searcher.Filter = "(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=67108864))";
                        searcher.PageSize = 1000;
                        searcher.PropertiesToLoad.Clear();
                        searcher.PropertiesToLoad.Add("name");
                        searcher.PropertiesToLoad.Add("distinguishedName");
                        searcher.PropertiesToLoad.Add("dNSHostName");
                        searcher.PropertiesToLoad.Add("msDS-NeverRevealGroup");
                        searcher.PropertiesToLoad.Add("msDS-RevealOnDemandGroup");
                        searcher.PropertiesToLoad.Add("msDS-RevealedList");
                        searcher.PropertiesToLoad.Add("userAccountControl");

                        var results = searcher.FindAll();
                        Console.WriteLine($"  Found {results.Count} RODCs in {domain.Name}");
                        
                        if (results.Count == 0)
                        {
                            Console.WriteLine($"  No RODCs found in domain {domain.Name}");
                            continue;
                        }

                        // Define privileged groups that should NEVER be cached on RODCs
                        var privilegedGroups = new string[]
                        {
                            $"CN=Domain Admins,CN=Users,{domainDN}",
                            $"CN=Enterprise Admins,CN=Users,{domainDN}",
                            $"CN=Schema Admins,CN=Users,{domainDN}",
                            $"CN=Administrators,CN=Builtin,{domainDN}",
                            $"CN=Group Policy Creator Owners,CN=Users,{domainDN}",
                            $"CN=Domain Controllers,CN=Users,{domainDN}",
                            $"CN=Denied RODC Password Replication Group,CN=Users,{domainDN}"
                        };

                        foreach (SearchResult result in results)
                        {
                            var rodcResult = AnalyzeRODC(result, privilegedGroups, domain.Name);
                            if (rodcResult != null)
                            {
                                allResults.Add(rodcResult);
                            }
                        }
                    }
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"  Warning: Failed to query domain {domain.Name}: {ex.Message}");
                }
            }

            // Display results
            if (allResults.Count > 0)
            {
                Console.WriteLine();
                Console.WriteLine($"Found {allResults.Count} RODCs with credential caching policy issues across forest:");
                Console.WriteLine();
                Console.WriteLine("RODCName".PadRight(20) + "Domain".PadRight(20) + "Severity".PadRight(10) + "Issues");
                Console.WriteLine(new string('=', 80));
                
                foreach (var result in allResults)
                {
                    Console.WriteLine($"{result.RODCName.PadRight(20)}{result.Domain.PadRight(20)}{result.Severity.PadRight(10)}{result.IssueCount}");
                    Console.WriteLine($"  Issues: {result.Issues}");
                    Console.WriteLine();
                }
                
                var criticalCount = allResults.Count(r => r.Severity == "CRITICAL");
                var highCount = allResults.Count(r => r.Severity == "HIGH");
                Console.WriteLine($"Summary - Critical: {criticalCount}, High: {highCount}");
            }
            else
            {
                Console.WriteLine();
                Console.WriteLine("No findings - All RODCs have proper credential caching policies configured");
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error: C# DirectoryServices query failed: {ex.Message}");
            Environment.Exit(1);
        }
    }

    private static RODCResult AnalyzeRODC(SearchResult result, string[] privilegedGroups, string domainName)
    {
        var props = result.Properties;
        string rodcName = GetProperty(props, "name");
        
        var issues = new List<string>();
        string severity = "HIGH";
        
        // Check msDS-NeverRevealGroup
        var neverRevealGroups = GetMultiValueProperty(props, "msds-neverrevealgroup");
        
        // Check if all privileged groups are in NeverRevealGroup
        var missingPrivilegedGroups = new List<string>();
        foreach (var privGroup in privilegedGroups)
        {
            if (!neverRevealGroups.Contains(privGroup))
            {
                string groupName = privGroup.Substring(3, privGroup.IndexOf(',') - 3);
                missingPrivilegedGroups.Add(groupName);
            }
        }
        
        if (missingPrivilegedGroups.Count > 0)
        {
            issues.Add($"Privileged groups not in NeverRevealGroup: {string.Join(", ", missingPrivilegedGroups)}");
            severity = "CRITICAL";
        }
        
        // Check msDS-RevealedList
        var revealedAccounts = GetMultiValueProperty(props, "msds-revealedlist");
        if (revealedAccounts.Count > 0)
        {
            issues.Add($"Total accounts with cached credentials: {revealedAccounts.Count}");
            // Note: Checking if revealed accounts are privileged would require additional LDAP queries
            // This is simplified for the C# implementation
        }
        
        // Check msDS-RevealOnDemandGroup
        var revealOnDemandGroups = GetMultiValueProperty(props, "msds-revealondemandgroup");
        if (revealOnDemandGroups.Count > 0)
        {
            var privilegedInRevealOnDemand = new List<string>();
            foreach (var privGroup in privilegedGroups)
            {
                if (revealOnDemandGroups.Contains(privGroup))
                {
                    string groupName = privGroup.Substring(3, privGroup.IndexOf(',') - 3);
                    privilegedInRevealOnDemand.Add(groupName);
                }
            }
            
            if (privilegedInRevealOnDemand.Count > 0)
            {
                issues.Add($"Privileged groups in RevealOnDemandGroup: {string.Join(", ", privilegedInRevealOnDemand)}");
                severity = "CRITICAL";
            }
        }
        
        if (issues.Count > 0 || neverRevealGroups.Count == 0)
        {
            if (neverRevealGroups.Count == 0)
            {
                issues.Add("No NeverRevealGroup configured (all accounts may be cacheable)");
                severity = "CRITICAL";
            }
            
            return new RODCResult
            {
                CheckID = "DC-040",
                CheckName = "RODC Credential Caching Policy",
                Domain = domainName,
                ObjectDN = GetProperty(props, "distinguishedName"),
                ObjectName = rodcName,
                RODCName = rodcName,
                Severity = severity,
                Issues = string.Join("; ", issues),
                IssueCount = issues.Count,
                NeverRevealGroupCount = neverRevealGroups.Count,
                RevealOnDemandCount = revealOnDemandGroups.Count,
                RevealedAccountsCount = revealedAccounts.Count,
                Timestamp = DateTime.UtcNow.ToString("yyyy-MM-ddTHH:mm:ss.fffZ"),
                Engine = "CSharp"
            };
        }
        
        return null;
    }
    
    private static string GetProperty(ResultPropertyCollection props, string propertyName)
    {
        return props.Contains(propertyName) && props[propertyName].Count > 0 
            ? props[propertyName][0].ToString() 
            : "N/A";
    }
    
    private static List<string> GetMultiValueProperty(ResultPropertyCollection props, string propertyName)
    {
        var values = new List<string>();
        if (props.Contains(propertyName))
        {
            foreach (var value in props[propertyName])
            {
                values.Add(value.ToString());
            }
        }
        return values;
    }
}

public class RODCResult
{
    public string CheckID { get; set; }
    public string CheckName { get; set; }
    public string Domain { get; set; }
    public string ObjectDN { get; set; }
    public string ObjectName { get; set; }
    public string RODCName { get; set; }
    public string Severity { get; set; }
    public string Issues { get; set; }
    public int IssueCount { get; set; }
    public int NeverRevealGroupCount { get; set; }
    public int RevealOnDemandCount { get; set; }
    public int RevealedAccountsCount { get; set; }
    public string Timestamp { get; set; }
    public string Engine { get; set; }
}
