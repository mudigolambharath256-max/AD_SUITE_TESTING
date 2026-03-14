// ============================================================
// CHECK: TRST-031_ExtraSIDs_Cross_Forest_Attack_Surface
// CATEGORY: Trust_Relationships
// DESCRIPTION: Detects forest trusts vulnerable to ExtraSIDs attacks
// LDAP FILTER: (&(objectClass=trustedDomain)(trustType=2))
// SEARCH BASE: CN=System,<DomainDN>
// OBJECT CLASS: trustedDomain
// ATTRIBUTES: trustPartner, trustDirection, trustType, trustAttributes, securityIdentifier
// RISK: CRITICAL
// MITRE ATT&CK: T1134.005 (Access Token Manipulation: SID-History Injection)
// ============================================================

using System;
using System.Collections.Generic;
using System.DirectoryServices;
using System.Security.Principal;

class TRST031
{
    static void Main()
    {
        try
        {
            Console.WriteLine("[TRST-031] Checking ExtraSIDs Cross Forest Attack Surface...");
            
            // Get current domain DN
            DirectoryEntry rootDSE = new DirectoryEntry("LDAP://RootDSE");
            string domainDN = rootDSE.Properties["defaultNamingContext"][0].ToString();
            
            // Query forest trusts (trustType=2)
            using (DirectorySearcher searcher = new DirectorySearcher())
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
                searcher.SearchRoot = new DirectoryEntry($"LDAP://CN=System,{domainDN}");
                searcher.Filter = "(&(objectClass=trustedDomain)(trustType=2))";
                searcher.PropertiesToLoad.Add("trustPartner");
                searcher.PropertiesToLoad.Add("trustDirection");
                searcher.PropertiesToLoad.Add("trustType");
                searcher.PropertiesToLoad.Add("trustAttributes");
                searcher.PropertiesToLoad.Add("securityIdentifier");
                searcher.PropertiesToLoad.Add("distinguishedName");
                
                SearchResultCollection results = searcher.FindAll();
                Console.WriteLine($"Found {results.Count} forest trusts to analyze");
                
                foreach (SearchResult result in results)
                {
                    AnalyzeForestTrust(result, domainDN);
                }
                
                results.Dispose();
            }
            
            // Check for accounts with cross-forest SID History
            Console.WriteLine("Checking for accounts with cross-forest SID History...");
            CheckCrossForestSidHistory(domainDN);
            
            rootDSE.Dispose();
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error: {ex.Message}");
            Environment.Exit(1);
        }
    }
    
    static void AnalyzeForestTrust(SearchResult trustResult, string domainDN)
    {
        try
        {
            string trustPartner = trustResult.Properties["trustPartner"][0].ToString();
            int trustDirection = Convert.ToInt32(trustResult.Properties["trustDirection"][0]);
            int trustAttributes = trustResult.Properties["trustAttributes"].Count > 0 ? 
                                Convert.ToInt32(trustResult.Properties["trustAttributes"][0]) : 0;
            string trustDN = trustResult.Properties["distinguishedName"][0].ToString();
            
            List<string> vulnerabilities = new List<string>();
            
            // Check if SID filtering is disabled (TREAT_AS_EXTERNAL bit NOT set)
            // Bit 0x04 (4) = TREAT_AS_EXTERNAL (quarantined = SID filter ON)
            if ((trustAttributes & 4) == 0)
            {
                vulnerabilities.Add("SID filtering disabled - ExtraSIDs attack possible");
            }
            
            // Check for other risky trust attributes
            if ((trustAttributes & 8) != 0)
            {
                vulnerabilities.Add("Uses RC4 encryption (bit 0x08) - downgrade risk");
            }
            
            if ((trustAttributes & 32) == 0)
            {
                vulnerabilities.Add("No selective authentication (bit 0x20) - broader access");
            }
            
            // Check trust direction for inbound component (ExtraSIDs come FROM trusted forest)
            string directionRisk = "";
            switch (trustDirection)
            {
                case 1:
                    directionRisk = $"Inbound trust - can receive ExtraSIDs from {trustPartner}";
                    break;
                case 2:
                    directionRisk = $"Outbound trust - no direct ExtraSIDs risk";
                    break;
                case 3:
                    directionRisk = $"Bidirectional trust - can receive ExtraSIDs from {trustPartner}";
                    break;
                default:
                    directionRisk = $"Unknown direction ({trustDirection})";
                    break;
            }
            
            // Only flag trusts that can receive ExtraSIDs (inbound or bidirectional)
            if (trustDirection == 1 || trustDirection == 3)
            {
                if (vulnerabilities.Count > 0)
                {
                    string severity = (trustAttributes & 4) == 0 ? "CRITICAL" : "HIGH";
                    
                    Console.WriteLine($"[FINDING] {trustPartner}");
                    Console.WriteLine($"  CheckID: TRST-031");
                    Console.WriteLine($"  ObjectDN: {trustDN}");
                    Console.WriteLine($"  FindingDetail: Forest trust vulnerable to ExtraSIDs: {string.Join("; ", vulnerabilities)} | {directionRisk} | trustAttributes=0x{trustAttributes:X}");
                    Console.WriteLine($"  Severity: {severity}");
                    Console.WriteLine($"  Timestamp: {DateTime.UtcNow:yyyy-MM-ddTHH:mm:ss.fffZ}");
                    Console.WriteLine();
                }
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Warning: Could not analyze trust: {ex.Message}");
        }
    }
    
    static void CheckCrossForestSidHistory(string domainDN)
    {
        try
        {
            // Get current domain SID prefix
            DirectoryEntry domainEntry = new DirectoryEntry($"LDAP://{domainDN}");
            byte[] domainSidBytes = (byte[])domainEntry.Properties["objectSid"][0];
            SecurityIdentifier domainSid = new SecurityIdentifier(domainSidBytes, 0);
            string currentDomainSidPrefix = domainSid.AccountDomainSid.Value;
            
            // Query users with SID History
            using (DirectorySearcher searcher = new DirectorySearcher())
            {
                searcher.SearchRoot = new DirectoryEntry($"LDAP://{domainDN}");
                searcher.Filter = "(&(objectClass=user)(sIDHistory=*))";
                searcher.PropertiesToLoad.Add("sAMAccountName");
                searcher.PropertiesToLoad.Add("sIDHistory");
                searcher.PropertiesToLoad.Add("distinguishedName");
                
                SearchResultCollection results = searcher.FindAll();
                
                foreach (SearchResult result in results)
                {
                    string accountName = result.Properties["sAMAccountName"][0].ToString();
                    string accountDN = result.Properties["distinguishedName"][0].ToString();
                    
                    foreach (byte[] sidHistoryBytes in result.Properties["sIDHistory"])
                    {
                        try
                        {
                            SecurityIdentifier historySid = new SecurityIdentifier(sidHistoryBytes, 0);
                            string historySidString = historySid.Value;
                            
                            // Check if SID History belongs to a different forest
                            if (!historySidString.StartsWith(currentDomainSidPrefix))
                            {
                                Console.WriteLine($"[FINDING] {accountName}");
                                Console.WriteLine($"  CheckID: TRST-031");
                                Console.WriteLine($"  ObjectDN: {accountDN}");
                                Console.WriteLine($"  FindingDetail: Account has cross-forest SID History: {historySidString} (potential ExtraSIDs vector)");
                                Console.WriteLine($"  Severity: HIGH");
                                Console.WriteLine($"  Timestamp: {DateTime.UtcNow:yyyy-MM-ddTHH:mm:ss.fffZ}");
                                Console.WriteLine();
                            }
                        }
                        catch (Exception ex)
                        {
                            Console.WriteLine($"Warning: Could not parse SID History for {accountName}: {ex.Message}");
                        }
                    }
                }
                
                results.Dispose();
            }
            
            domainEntry.Dispose();
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Warning: Could not check SID History: {ex.Message}");
        }
    }
}
