using System;
using System.DirectoryServices;
using System.Security.Cryptography.X509Certificates;

// Check: DCs with Expiring Certificates
// Category: Domain Controllers
// Severity: high
// ID: DC-012
// Requirements: None
// ============================================

class Program
{
    static void Main()
    {
        string filter = @"(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192)(userCertificate=*))";

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
        string[] props = new string[] { "name", "distinguishedName", "dNSHostName", "operatingSystem", "userCertificate" };

        using (var root = new DirectoryEntry("LDAP://RootDSE"))
        {
            string domainNC = root.Properties["defaultNamingContext"].Value.ToString();
            using (var searchBase = new DirectoryEntry("LDAP://" + domainNC))
            using (var searcher = new DirectorySearcher(searchBase))
            {
                searcher.Filter = filter;
                searcher.PageSize = 1000;
                foreach (var p in props) searcher.PropertiesToLoad.Add(p);

                foreach (SearchResult r in searcher.FindAll())
                {
                    string dcName = Get(r, "name");
                    string dnsHostName = Get(r, "dNSHostName");
                    
                    if (r.Properties.Contains("userCertificate"))
                    {
                        foreach (byte[] certBytes in r.Properties["userCertificate"])
                        {
                            try
                            {
                                var cert = new X509Certificate2(certBytes);
                                var daysUntilExpiration = (cert.NotAfter - DateTime.Now).Days;
                                
                                if (daysUntilExpiration <= 60)
                                {
                                    string status = daysUntilExpiration < 0 ? "EXPIRED" : 
                                                   daysUntilExpiration <= 30 ? "CRITICAL" : "WARNING";
                                    
                                    Console.WriteLine("DC Name           : " + dcName);
                                    Console.WriteLine("DNS Host Name     : " + dnsHostName);
                                    Console.WriteLine("Certificate Subject: " + cert.Subject);
                                    Console.WriteLine("Not After         : " + cert.NotAfter);
                                    Console.WriteLine("Days Until Expiry : " + daysUntilExpiration);
                                    Console.WriteLine("Status            : " + status);
                                    Console.WriteLine("Thumbprint        : " + cert.Thumbprint);
                                    Console.WriteLine(new string('-', 60));
                                }
                                
                                cert.Dispose();
                            }
                            catch (Exception ex)
                            {
                                Console.WriteLine("Certificate parse error for " + dcName + ": " + ex.Message);
                            }
                        }
                    }
                }
            }
        }
    }

    static string Get(SearchResult r, string attr)
    {
        return r.Properties.Contains(attr) && r.Properties[attr].Count > 0
            ? r.Properties[attr][0].ToString()
            : "(not set)";
    }
}
