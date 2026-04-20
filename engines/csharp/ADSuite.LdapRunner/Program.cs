// AD Suite — C# LDAP runner (DirectorySearcher). Catalog: same ldapFilter/searchBase/propertiesToLoad as ADSI checks.
// Build: dotnet build -c Release
// Run:   ADSuite.LdapRunner.exe <checks.json> <CheckId> [DC_hostname]
// Windows recommended. Advanced catalog fields (complianceRuleSet, ldapFindingCondition, …) are not implemented — use PowerShell.

using System.DirectoryServices;
using System.Text.Json;

if (args.Length < 2)
{
    Console.Error.WriteLine("Usage: ADSuite.LdapRunner <checks.json|unified> <CheckId> [server]");
    return 1;
}

var catalogPath = Path.GetFullPath(args[0]);
var checkId = args[1];
var server = args.Length > 2 ? args[2] : null;

if (!File.Exists(catalogPath))
{
    Console.Error.WriteLine($"File not found: {catalogPath}");
    return 1;
}

using var doc = JsonDocument.Parse(File.ReadAllText(catalogPath));
var root = doc.RootElement;
if (!root.TryGetProperty("checks", out var checksEl))
{
    Console.Error.WriteLine("Catalog missing 'checks' array.");
    return 1;
}

JsonElement? checkEl = null;
foreach (var c in checksEl.EnumerateArray())
{
    if (c.TryGetProperty("id", out var id) && string.Equals(id.GetString(), checkId, StringComparison.OrdinalIgnoreCase))
    {
        checkEl = c;
        break;
    }
}

if (checkEl is null)
{
    Console.Error.WriteLine($"Unknown CheckId: {checkId}");
    return 1;
}

var cdef = checkEl.Value;
var engine = cdef.TryGetProperty("engine", out var eng) ? eng.GetString()?.ToLowerInvariant() : "ldap";
if (engine != "ldap")
{
    Console.Error.WriteLine($"Check uses engine '{engine}'; C# runner supports ldap only.");
    return 2;
}

if (!cdef.TryGetProperty("ldapFilter", out var filterEl) || !cdef.TryGetProperty("searchBase", out var baseKindEl))
{
    Console.Error.WriteLine("Check missing ldapFilter or searchBase.");
    return 1;
}

var ldapFilter = filterEl.GetString() ?? "";
var searchBaseKind = baseKindEl.GetString() ?? "Domain";

var rootDsePath = string.IsNullOrEmpty(server) ? "LDAP://RootDSE" : $"LDAP://{server}/RootDSE";
using var rootDse = new DirectoryEntry(rootDsePath);

string? baseDn = searchBaseKind switch
{
    "Domain" => rootDse.Properties["defaultNamingContext"].Count > 0 ? rootDse.Properties["defaultNamingContext"][0]?.ToString() : null,
    "Configuration" => rootDse.Properties["configurationNamingContext"].Count > 0 ? rootDse.Properties["configurationNamingContext"][0]?.ToString() : null,
    "Schema" => rootDse.Properties["schemaNamingContext"].Count > 0 ? rootDse.Properties["schemaNamingContext"][0]?.ToString() : null,
    "SchemaContainer" => rootDse.Properties["configurationNamingContext"].Count > 0
        ? $"CN=Schema,{rootDse.Properties["configurationNamingContext"][0]}"
        : null,
    "Custom" => cdef.TryGetProperty("searchBaseDn", out var sbd) ? sbd.GetString() : null,
    _ => null
};

if (string.IsNullOrEmpty(baseDn))
{
    Console.Error.WriteLine("Could not resolve search base DN.");
    return 1;
}

var scope = SearchScope.Subtree;
if (cdef.TryGetProperty("searchScope", out var sc))
{
    var ss = sc.GetString();
    if (!string.IsNullOrEmpty(ss) && Enum.TryParse<SearchScope>(ss, true, out var parsed))
        scope = parsed;
}

var props = new HashSet<string>(StringComparer.OrdinalIgnoreCase) { "distinguishedName" };
if (cdef.TryGetProperty("propertiesToLoad", out var ptl))
{
    foreach (var p in ptl.EnumerateArray())
    {
        var s = p.GetString();
        if (!string.IsNullOrEmpty(s)) props.Add(s);
    }
}

var searchRootPath = string.IsNullOrEmpty(server) ? $"LDAP://{baseDn}" : $"LDAP://{server}/{baseDn}";
using var searchRoot = new DirectoryEntry(searchRootPath);
using var searcher = new DirectorySearcher(searchRoot)
{
    Filter = ldapFilter,
    SearchScope = scope,
    PageSize = 1000
};
foreach (var p in props)
    searcher.PropertiesToLoad.Add(p);

List<Dictionary<string, object?>> rows;
try
{
    using var results = searcher.FindAll();
    rows = new List<Dictionary<string, object?>>();
    foreach (SearchResult sr in results)
    {
        var row = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
        if (cdef.TryGetProperty("outputProperties", out var opmap))
        {
            foreach (var prop in opmap.EnumerateObject())
            {
                var col = prop.Name;
                var attr = prop.Value.GetString() ?? col;
                row[col] = FirstProp(sr, attr);
            }
        }
        else
        {
            foreach (var p in props)
                row[p] = FirstProp(sr, p);
        }

        row["CheckId"] = checkId;
        row["CheckName"] = cdef.TryGetProperty("name", out var nm) ? nm.GetString() : checkId;
        rows.Add(row);
    }
}
catch (Exception ex)
{
    Console.Error.WriteLine($"LDAP query failed: {ex.Message}");
    return 1;
}

var findingCount = rows.Count;
var resultWord = findingCount == 0 ? "Pass" : "Fail";
Console.WriteLine(JsonSerializer.Serialize(new { checkId, findingCount, result = resultWord, engine = "csharp" }));

foreach (var row in rows)
    Console.WriteLine(JsonSerializer.Serialize(row));

return 0;

static object? FirstProp(SearchResult sr, string attr)
{
    var key = attr.ToLowerInvariant();
    if (!sr.Properties.Contains(key) || sr.Properties[key].Count == 0)
        return "N/A";
    var v = sr.Properties[key][0];
    return v is byte[] b ? Convert.ToBase64String(b) : v;
}
