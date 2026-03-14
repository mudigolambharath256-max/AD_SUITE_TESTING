// Check: FSMO Role Holders
// Category: Domain Controllers
// Severity: info
// ID: DC-007
// Requirements: Compile with System.DirectoryServices
// ============================================
using System;
using System.DirectoryServices;

class DC_DC_029
{
  static void Main()
  {
    using (var root = new DirectoryEntry("LDAP://RootDSE"))
    {
      string domainNC = root.Properties["defaultNamingContext"].Value.ToString();

      // PDC Emulator + RIDManagerReference from domain root
      using (var searchRoot = new DirectoryEntry("LDAP://" + domainNC))
      using (var searcher = new DirectorySearcher(searchRoot))
      {
        searcher.Filter = "(objectClass=domainDNS)";
        searcher.PageSize = 1000;

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
        foreach (var p in new string[] { "name", "distinguishedName", "fSMORoleOwner", "rIDManagerReference" })
          searcher.PropertiesToLoad.Add(p);

        // Infrastructure Master from CN=Infrastructure
        string infraOwner = "(not set)";
        try {
          using (var infraEntry = new DirectoryEntry("LDAP://CN=Infrastructure," + domainNC))
          {
            infraEntry.RefreshCache(new string[] { "fSMORoleOwner" });
            if (infraEntry.Properties["fSMORoleOwner"].Count > 0)
              infraOwner = infraEntry.Properties["fSMORoleOwner"][0].ToString();
          }
        } catch { }

        foreach (SearchResult r in searcher.FindAll())
        {
          var name = r.Properties.Contains("name") && r.Properties["name"].Count > 0 ? r.Properties["name"][0].ToString() : "";
          var distinguishedName = r.Properties.Contains("distinguishedName") && r.Properties["distinguishedName"].Count > 0 ? r.Properties["distinguishedName"][0].ToString() : "";
          var fSMORoleOwner = r.Properties.Contains("fSMORoleOwner") && r.Properties["fSMORoleOwner"].Count > 0 ? r.Properties["fSMORoleOwner"][0].ToString() : "";
          var rIDManagerReference = r.Properties.Contains("rIDManagerReference") && r.Properties["rIDManagerReference"].Count > 0 ? r.Properties["rIDManagerReference"][0].ToString() : "";
          Console.WriteLine("---");
          Console.WriteLine("Name: " + name);
          Console.WriteLine("DistinguishedName: " + distinguishedName);
          Console.WriteLine("FSMORoleOwner: " + fSMORoleOwner);
          Console.WriteLine("RIDManagerReference: " + rIDManagerReference);
          Console.WriteLine("InfrastructureMaster: " + infraOwner);
        }
      }
    }
  }
}
