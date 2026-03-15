# KIRO AGENT PROMPT — Script Syntax Fix Pass
## Project: AD Security Suite — Fix All Syntax Errors Found in Test Run
## Source: Automated test results dated 2026-03-14 (56.75% success rate)
## Target: Raise adsi.ps1 success rate from ~33% to 100%

---

## TEST RESULTS SUMMARY (what you are fixing)

```
Total scripts tested : 2,275
Successful           : 1,291 (56.75%)
Syntax errors        : 515   (adsi.ps1 primary victim)
Other errors         : 469   (CMD timeouts + CMD filter errors)

PowerShell engine    : ~100% passing — DO NOT TOUCH
ADSI engine          : ~33% passing  — PRIMARY FIX TARGET
CMD engine           : ~70% timeout (acceptable), ~4% ERROR — fix CMD errors only
Combined/C#          : not separately tested
```

---

## ABSOLUTE RULES

1. **Read every affected file before editing it.** Never patch blindly.
2. **Do NOT touch PowerShell.ps1 files** — they are all passing.
3. **Do NOT add new features.** Fix syntax only — restore to working state.
4. **Preserve all existing logic.** Only fix broken syntax, nothing else.
5. **After fixing, verify with `$null = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$null, [ref]$errors)` in PowerShell** — parse must return zero errors.
6. Work category by category. Within each category, fix all checks before moving on.

---

## ROOT CAUSE ANALYSIS

There are **9 distinct error patterns**. Each has a specific fix.
Before touching any file, read it and identify which pattern it has.

---

## ERROR PATTERN REFERENCE

### PATTERN A — Broken PropertiesToLoad, simple script (try block after)
```
Symptoms:
  Line 44: Missing closing ')' in expression.
  Line 47: Unexpected token 'try' in expression or statement.

Affected: ACC-002,003,004,006,007,009,011,014,015,017,020,021,025,026,
          030,031,034,037,038,039,043,044,045
          CMGMT-003 through CMGMT-027 (most)
          AD-005

Root cause: The objectSid addition to PropertiesToLoad put a newline before
the closing ) making the array span two lines. Line 44 is the broken
PropertiesToLoad. The try { block on line 47 is unexpected because PS
is still trying to parse the unclosed array from line 44.

The broken state (what's currently in the file):
  @('name', 'distinguishedName', 'cn', 'member', 'objectSid'
  ) | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }

OR: the ) was doubled:
  @('name', 'distinguishedName', 'cn', 'member', 'objectSid')) | ForEach-Object...

OR: a trailing comma before ):
  @('name', 'distinguishedName', 'cn', 'member', 'objectSid',) | ForEach-Object...

The correct state:
  @('name', 'distinguishedName', 'cn', 'member', 'objectSid') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
```

**Fix:** Find the PropertiesToLoad line. Ensure it reads exactly:
```powershell
@('<attr1>', '<attr2>', ..., 'objectSid') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
```
All on one line. Single `)` before `|`. No trailing comma. No newline inside.

---

### PATTERN B — Broken PropertiesToLoad, Write-Host on next token line
```
Symptoms:
  Line 30: Missing closing ')' in expression.
  Line 32: Unexpected token 'Write-Host' in expression or statement.

Affected: KRB-031 to KRB-045, SMB-001 to SMB-012, LDAP-001,002,004-015,
          NET-002 to NET-010, PERS-001 to PERS-012, BCK-001,002,006,008,
          ADV-001 to ADV-007, AAD-033 to AAD-042, COMPLY-005,006,007,016,018,019,020

Root cause: Same as Pattern A — PropertiesToLoad closing ) broken.
Different line numbers because these scripts have Write-Host immediately
after the PropertiesToLoad line instead of a try block.

Same fix as Pattern A: repair the PropertiesToLoad line to be on one line
with proper ) before |.
```

---

### PATTERN C — Broken PropertiesToLoad + $results variable unexpected
```
Symptoms:
  Line 29: Missing closing ')' in expression.
  Line 31: Unexpected token '$results' in expression or statement.

Affected: AUTH-031, AUTH-032, AUTH-033, ACC-031 (some), PRV-031, PRV-032,
          USR-033, USR-034, USR-035, SVC-031

Root cause: PropertiesToLoad broken (same as A/B) PLUS $results variable
was inserted by Phase 1 fix. The $results line appears as 'unexpected token'
because the parser is still inside the broken array from the line above.

Fix:
  Step 1: Fix the PropertiesToLoad line (same as Pattern A)
  Step 2: Verify $results = $searcher.FindAll() is on its own line
  Step 3: Verify $results | ForEach-Object { is on the next line
```

---

### PATTERN D — TWO broken PropertiesToLoad lines + BH export string error
```
Symptoms:
  Line 20 OR 29: Missing closing ')' in expression.
  Line 22 OR 31: Unexpected token '$results' in expression or statement.
  Line 134 OR 144: Missing closing ')' in expression.
  Line 136 OR 146: Unexpected token '$results' in expression or statement.
  Line 173+ (varies): Unexpected token 'AD' in expression or statement.
  Line 173+ (varies): The string is missing the terminator: ".
  Line 114/124: Missing closing '}' in statement block or type definition.
  Line 186+: The Try statement is missing its Catch or Finally block.

Affected: Most AUTH-*, AAD-*, COMP-*, KRB-001 to KRB-030, USR-001 to USR-035,
          PRV-015 to PRV-032, SVC-001 to SVC-030, TRST-001,007,018-023,025,030,
          ACC-002,006,007,009,011 etc.

Root cause: These scripts have TWO separate searcher blocks (e.g., one for
users and one for a related lookup). BOTH PropertiesToLoad lines were broken
by the objectSid addition. Then the BloodHound export block appended at the
end has a string that is not properly terminated — specifically a double-quoted
string that contains "AD" (as in "Active Directory") where the opening or
closing double-quote is missing or was consumed by adjacent content.

Fix:
  Step 1: Read the full file
  Step 2: Find EVERY PropertiesToLoad line and fix each one (same as A)
  Step 3: Find the BloodHound export block (look for # BH export or
          $bhSession or $bhDir markers)
  Step 4: Locate the string with "AD" — this is typically in adSuiteCheckName
          or adSuiteCategory properties, OR in a Write-Host line within
          the export block. Fix the string terminator (see BH Export Fix below)
```

---

### PATTERN E — Only BH export block string error (PropertiesToLoad OK)
```
Symptoms:
  Line 161 (or 165, 167, 173, 176, 191): Unexpected token 'AD' in expression.
  Line 161+: The string is missing the terminator: ".
  Line 108 or 114: Missing closing '}' in statement block.
  Line 16: Missing closing '}' in statement block.
  Line 164/168/176: The Try statement is missing its Catch or Finally block.

Affected: AUTH-001,002,003,004,007,009,010,011,012,013,014,015,017,019,020,
          CERT-001 to CERT-030, GPO-001 to GPO-030, AAD-008,012,020,023,024,
          KRB-002,004,009,010,013,014,017,018,020,026,029,030,
          PRV-001 to PRV-016, PRV-021 to PRV-028,
          TRST-001,004,007,018,019,021,022,023,025,030
          USR-001 to USR-032

Root cause: The PropertiesToLoad line is actually OK in these scripts.
The ONLY issue is the BloodHound export block at the end of the file has
a string terminator problem. The block contains a double-quoted string that
includes the word "Active" or "AD" and is not properly closed.

All the "Missing closing '}'" and "Try missing Catch" errors are CASCADE
errors caused by the single string terminator failure — once PowerShell
loses track of string context, all subsequent braces and keywords look wrong.

Fix: ONLY the BH export block needs fixing. See BH Export Fix below.
```

---

### PATTERN F — TMGMT scripts, extra } at line 46
```
Symptoms:
  Line 46: Unexpected token '}' in expression or statement.

Affected: TMGMT-001 through TMGMT-030

Root cause: The TMGMT scripts are short (~40 lines of main logic).
An extra closing } was inserted at line 46, either:
  a) The BH export block's closing } was placed inside the main ForEach block
  b) A stray } from a partial BH export insertion
  c) The Phase 1 FindAll variable fix introduced a mis-matched brace

Fix:
  Step 1: Read the file
  Step 2: Identify which } at line 46 is spurious (does not match an open {)
  Step 3: Remove the extra }
  Step 4: Verify brace matching: every { has exactly one matching }
  Step 5: If BH export block exists, ensure it starts AFTER the closing }
          of the main ForEach block
```

---

### PATTERN G — TRST scripts, multi-catch + BH export string
```
Symptoms:
  Line 22: The Try statement is missing its Catch or Finally block.
  Line 132: The Try statement is missing its Catch or Finally block.
  Line 165: Unexpected token 'AD' in expression or statement.
  Line 165: The string is missing the terminator: ".
  Line 152: Catch block must be the last catch block.

Affected: TRST-005 to TRST-017, TRST-020, TRST-024, TRST-026 to TRST-029,
          TRST-031 (partially)

Root cause: These trust scripts have a multi-catch try statement structure:
  try { ... } catch [ExceptionType] { ... } catch { ... }
The "Catch block must be the last catch block" error means a typed catch
follows an untyped catch — these were reversed. PLUS the BH export block
has the same string terminator issue as Pattern E.

Fix:
  Step 1: Find try-catch blocks where untyped catch { precedes typed catch
  Step 2: Reorder so typed catches come BEFORE the untyped catch:
    WRONG: } catch { ... } catch [ADException] { ... }
    RIGHT: } catch [ADException] { ... } catch { ... }
  Step 3: Fix the BH export block string issue (same as Pattern E)
```

---

### PATTERN H — Complex DC scripts, `nSummary string issue
```
Symptoms:
  Line 213+: Unexpected token '`nSummary:' in expression or statement.
  Line 218+: The string is missing the terminator: ".
  Multiple missing } and missing Catch

Affected: DC-001, DC-002, DC-009 to DC-036 (most), DC-040

Root cause: DC checks have complex multi-hundred-line scripts with
Write-Host blocks using `` `n `` newline escape characters. The script contains
something like:
  Write-Host "`nSummary: ..."
The BH export block was appended but a double-quoted string from the
Write-Host block was not properly terminated, causing the parser to
consume all subsequent content as part of the string — including the
BH export block's closing markers.

This is a more complex version of Pattern E.

Fix:
  Step 1: Read the file completely
  Step 2: Search backwards from the first error line for any Write-Host,
          $message =, or string assignment that uses "..." double quotes
  Step 3: Find the Write-Host or string line where the closing " is missing
  Step 4: Add the missing closing " at the end of that line
  Step 5: Verify the BH export block starts cleanly after all main code
  Step 6: Fix the BH export block string if also needed (Pattern E fix)
```

---

### PATTERN I — GPO-051 SYSVOL scan, regex in hashtable broken
```
Symptoms: Multiple complex errors including regex patterns, hash literals,
          string terminators throughout the file

Affected: GPO-051_SYSVOL_Credential_Content_Scan only

Root cause: This script scans SYSVOL for credentials using regex patterns
stored in a hashtable. The regex patterns contain special PowerShell
characters (quotes, brackets, pipe chars). The BH export block was
appended but the script's existing regex hashtable has patterns like:
  "GPP_cpassword" = 'cpassword="([^"]+)'
  "Password_Assignment" = '(?i)(password\s*=\s*["\']?)([^"\s\r\n]+)'
These strings contain " and ' characters that interfere with string parsing.

Fix:
  Step 1: Read GPO-051/adsi.ps1 completely
  Step 2: Find the $credentialPatterns hashtable
  Step 3: Ensure each regex pattern string is properly quoted:
    - Use single quotes for patterns containing " (double quotes)
    - Use double quotes (or here-string) for patterns containing ' (single quotes)
    - Escape any PowerShell special chars if needed
  Step 4: Verify the BH export block at the end is syntactically clean
  Step 5: Ensure the BH export block's try { } catch { } is not nested
          inside any of GPO-051's existing try blocks
```

---

## BLOODHOUND EXPORT BLOCK FIX (applies to Patterns D, E, G, H, I)

The BH export block was appended to scripts but contains a string syntax error.
The error manifests as `Unexpected token 'AD'` because a string property
like `adSuiteCheckName` or a `Write-Host` line has an improperly terminated
double-quoted string.

### Diagnosis step:
```powershell
# Find the broken line in the BH export block:
# Look for lines matching:
$content = Get-Content $scriptPath -Raw
$bhStart = $content.IndexOf('# ── BloodHound Export')
if ($bhStart -eq -1) { $bhStart = $content.IndexOf('$bhSession =') }
$bhBlock = $content.Substring($bhStart)
# Parse the BH block alone to find the exact error
$errors = $null
$null = [System.Management.Automation.Language.Parser]::ParseInput($bhBlock, [ref]$null, [ref]$errors)
$errors | ForEach-Object { Write-Host "BH block error at position $($_.Extent.StartLineNumber): $($_.Message)" }
```

### Common broken patterns and fixes:

**Broken pattern 1 — adSuiteCheckName with apostrophe in name:**
```powershell
# BROKEN (check name has apostrophe):
adSuiteCheckName  = 'Users That Can't Delegate'

# FIXED (escape the apostrophe, or use double quotes):
adSuiteCheckName  = "Users That Can't Delegate"
# OR:
adSuiteCheckName  = 'Users That Can''t Delegate'
```

**Broken pattern 2 — double-quoted string not closed:**
```powershell
# BROKEN:
$bhCheckName = "ADV-001 Print Spooler on Active Directory Domain Controllers

# FIXED (missing closing quote added):
$bhCheckName = "ADV-001 Print Spooler on Active Directory Domain Controllers"
```

**Broken pattern 3 — string spanning multiple lines incorrectly:**
```powershell
# BROKEN:
adSuiteCheckName = "AUTH-001 Accounts Without Kerberos Pre-Auth
(AS-REP Roastable)"

# FIXED (use single-line):
adSuiteCheckName = 'AUTH-001 Accounts Without Kerberos Pre-Auth'
```

**Broken pattern 4 — BH export block contains $bhDomainName referencing 'Active Directory' literally:**
```powershell
# BROKEN if check name template was substituted wrong:
adSuiteCategory = 'Access Control'   # fine
adSuiteCheckId  = 'Active           # BROKEN - truncated

# FIXED:
adSuiteCheckId  = 'ACC-014'
```

### The correct BH export block structure for adsi.ps1:
```powershell
# ── BloodHound Export ─────────────────────────────────────────────────────────
try {
    $bhSession = if ($env:ADSUITE_SESSION_ID) { $env:ADSUITE_SESSION_ID } else { [guid]::NewGuid().ToString('N') }
    $bhRoot    = if ($env:ADSUITE_OUTPUT_ROOT) { $env:ADSUITE_OUTPUT_ROOT } else { Join-Path $env:TEMP 'ADSuite_Sessions' }
    $bhDir     = Join-Path $bhRoot "$bhSession\bloodhound"
    if (-not (Test-Path $bhDir)) { New-Item -ItemType Directory -Path $bhDir -Force -ErrorAction Stop | Out-Null }

    $bhNodes = [System.Collections.Generic.List[hashtable]]::new()

    foreach ($r in $results) {
        $p    = $r.Properties
        $dn   = if ($p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { '' }
        $name = if ($p['name'].Count -gt 0) { $p['name'][0] } else { '' }
        $sidRaw = if ($p['objectsid'].Count -gt 0) { $p['objectsid'][0] } else { $null }

        $dom = (($dn -split ',') | Where-Object { $_ -match '^DC=' } | ForEach-Object { $_ -replace '^DC=','' }) -join '.' | ForEach-Object { $_.ToUpper() }

        $oid = $dn.ToUpper()
        if ($sidRaw) {
            try { $oid = (New-Object System.Security.Principal.SecurityIdentifier([byte[]]$sidRaw, 0)).Value }
            catch { }
        }

        $bhNodes.Add(@{
            ObjectIdentifier = $oid
            Properties       = @{
                name              = if ($dom) { "$($name.ToUpper())@$dom" } else { $name.ToUpper() }
                domain            = $dom
                distinguishedname = $dn.ToUpper()
                enabled           = $true
                adSuiteCheckId    = 'CHECKID_PLACEHOLDER'
                adSuiteCheckName  = 'CHECKNAME_PLACEHOLDER'
                adSuiteSeverity   = 'SEVERITY_PLACEHOLDER'
                adSuiteCategory   = 'CATEGORY_PLACEHOLDER'
                adSuiteFlag       = $true
            }
            Aces      = @()
            IsDeleted = $false
            IsACLProtected = $false
        })
    }

    $bhTs   = Get-Date -Format 'yyyyMMdd_HHmmss'
    $bhFile = Join-Path $bhDir "CHECKID_PLACEHOLDER_$bhTs.json"
    @{
        data = $bhNodes.ToArray()
        meta = @{ type = 'NODETYPE_PLACEHOLDER'; count = $bhNodes.Count; version = 5; methods = 0 }
    } | ConvertTo-Json -Depth 10 -Compress | Out-File -FilePath $bhFile -Encoding UTF8 -Force
} catch { }
# ── End BloodHound Export ─────────────────────────────────────────────────────
```

**Key rules for the BH export block:**
- `CHECKID_PLACEHOLDER` → actual check ID (e.g. `ACC-014`)
- `CHECKNAME_PLACEHOLDER` → check name as a SINGLE-QUOTED string, apostrophes escaped as `''`
- `SEVERITY_PLACEHOLDER` → `critical`, `high`, `medium`, `low`, or `info`
- `CATEGORY_PLACEHOLDER` → folder name (e.g. `Access_Control`)
- `NODETYPE_PLACEHOLDER` → `users`, `computers`, `groups`, `domains`, `gpos`, `ous`, or `containers`
- ALL strings use **single quotes** to avoid double-quote terminator issues
- The entire block wrapped in `try { } catch { }` — never crashes the main script
- Uses `$results` variable (which was fixed in Phase 1)

---

## CMD ERROR FIXES

### CMD ERROR: "The search filter cannot be recognized" (SVC-001 to SVC-030)

These service account checks use LDAP extensible match filters that `dsquery` cannot process:
```
(&(objectCategory=person)(objectClass=user)(servicePrincipalName=*)
  (userAccountControl:1.2.840.113556.1.4.803:=xxx))
```

The OID-based extensible match `userAccountControl:1.2.840.113556.1.4.803:=` is not supported by `dsquery`.

**Fix:** Replace the OID filter in cmd.bat with a simplified filter that dsquery CAN handle:
```bat
REM Instead of complex OID filter, use basic attributes dsquery understands:
dsquery * %DCPATH% -filter "(&(objectCategory=person)(objectClass=user)(servicePrincipalName=*))" -limit 0 -attr name distinguishedname samaccountname serviceprincipalname description
```
Remove the `userAccountControl` extensible match from the cmd.bat filter only. The adsi.ps1 and powershell.ps1 keep the full filter.

### CMD ERROR: "'-filter' is an unknown parameter" (DC-013)

This means the dsquery command format is wrong — `-filter` is a `dsquery *` parameter but the command is using a specific dsquery object type (like `dsquery computer`) which doesn't accept `-filter`.

**Fix:** Change `dsquery computer -filter "..."` to `dsquery * -filter "..."` in DC-013/cmd.bat.

### CMD ERROR: "Value for 'startnode' has incorrect format" (TRST-031)

The startnode DN passed to dsquery has a formatting error (extra comma, wrong DC= structure, etc.).

**Fix:** Read TRST-031/cmd.bat, find the dsquery startnode, verify it builds `DC=domain,DC=tld` correctly from `%DCPATH%`.

---

## EXECUTION ORDER

### Phase 1: Scan all adsi.ps1 files, identify pattern per file

For each adsi.ps1:
```powershell
$content = Get-Content $path -Raw
$errors  = $null
$null    = [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$null, [ref]$errors)

if ($errors.Count -eq 0) {
    Write-Host "PASS: $path"
} else {
    $firstError = $errors[0]
    Write-Host "FAIL: $path"
    Write-Host "  First error: Line $($firstError.Extent.StartLineNumber): $($firstError.Message)"
}
```

Categorize each failing file into one of the 9 patterns above.

### Phase 2: Fix PropertiesToLoad (Patterns A, B, C)

For each file with Pattern A/B/C:
1. Find every line containing `| ForEach-Object { [void]$searcher.PropertiesToLoad.Add`
2. Check if the `@(...)` array on that line is properly closed on the SAME line
3. If not, consolidate to single line: `@('attr1', 'attr2', ..., 'objectSid') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }`
4. Re-parse. Should have zero PropertiesToLoad errors.

### Phase 3: Fix BH Export Block (Patterns D, E)

For each file with Pattern D/E:
1. Find the BH export block (search for `bhSession` or `# BH export` or `bhDir`)
2. If block exists: parse it in isolation to find the exact string error
3. Replace the entire BH export block with the clean template above (substituting correct values)
4. Re-parse the full file. Verify zero errors.

### Phase 4: Fix structural issues (Patterns F, G, H, I)

Pattern F (TMGMT): Remove the extra } at line 46 after reading and verifying brace count.
Pattern G (TRST): Reorder catch blocks + fix BH export.
Pattern H (DC): Find unclosed string in Write-Host, fix it, then fix BH export.
Pattern I (GPO-051): Fix regex hashtable string quoting + BH export.

### Phase 5: Fix CMD errors

Fix the 3 specific CMD error types listed above.

### Phase 6: Verify all fixes

For each fixed file:
```powershell
$errors = $null
$null   = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$null, [ref]$errors)
if ($errors.Count -gt 0) {
    Write-Host "STILL FAILING: $path"
    $errors | ForEach-Object { Write-Host "  Line $($_.Extent.StartLineNumber): $($_.Message)" }
}
```

**Target: zero files with parse errors.**

---

## PER-CATEGORY FIX GUIDE

### Access_Control (ACC)
- ACC-001: PASS — do not touch
- ACC-002 to ACC-021 (failing): **Pattern A** — fix PropertiesToLoad + BH export
- ACC-013, ACC-025: PASS — do not touch  
- ACC-031, ACC-034, ACC-037 to ACC-039: **Pattern C** — fix PropertiesToLoad + $results + BH export
- ACC-043, ACC-044, ACC-045: **Pattern A** — fix PropertiesToLoad + BH export

### Advanced_Security (ADV)
- ADV-001 to ADV-007: **Pattern B** — fix PropertiesToLoad (Write-Host after)
- ADV-008, ADV-009, ADV-010: PASS — do not touch

### Authentication (AUTH)
- AUTH-001 to AUTH-004, AUTH-007, AUTH-009 to AUTH-020: **Pattern E** — fix BH export block only
- AUTH-005, AUTH-006, AUTH-008, AUTH-016, AUTH-018, AUTH-021 to AUTH-030: **Pattern D** — fix PropertiesToLoad + BH export
- AUTH-031, AUTH-032, AUTH-033: **Pattern C** — fix PropertiesToLoad + $results + BH export

### Azure_AD_Integration (AAD)
- AAD-001 to AAD-030: **Pattern D** — fix PropertiesToLoad + BH export
- AAD-031, AAD-032: **Pattern C** — fix PropertiesToLoad + $results + BH export
- AAD-033 to AAD-042: **Pattern B** — fix PropertiesToLoad (Write-Host after)
- AAD-041: PASS — do not touch

### Backup_Recovery (BCK)
- BCK-001, BCK-002, BCK-006, BCK-008: **Pattern B** — fix PropertiesToLoad
- BCK-003, BCK-004, BCK-005, BCK-007: PASS — do not touch

### Certificate_Services (CERT)
- CERT-001 to CERT-030: **Pattern E** — fix BH export block only (PropertiesToLoad OK)
- CERT-031 to CERT-053: PASS — do not touch

### Compliance (COMPLY)
- COMPLY-001 to COMPLY-004, COMPLY-008 to COMPLY-015, COMPLY-017: PASS — do not touch
- COMPLY-005, COMPLY-006, COMPLY-007, COMPLY-016, COMPLY-018, COMPLY-019, COMPLY-020: **Pattern B** — fix PropertiesToLoad

### Computer_Management (CMGMT)
- CMGMT-001, CMGMT-002: TIMEOUT in ADSI — check if script has infinite loop or missing RootDSE timeout
- CMGMT-003 to CMGMT-014, CMGMT-018 to CMGMT-027, CMGMT-031 to CMGMT-035: **Pattern A** — fix PropertiesToLoad
- CMGMT-005, CMGMT-008, CMGMT-013, CMGMT-016, CMGMT-017, CMGMT-028 to CMGMT-030, CMGMT-036, CMGMT-037: PASS

### Computers_Servers (COMP)
- COMP-001 to COMP-030: **Pattern D** — fix PropertiesToLoad (two blocks) + BH export
- COMP-030: Also has CMD EXCEPTION — check cmd.bat for process kill issue

### Domain_Configuration (DCONF)
- DCONF-001 to DCONF-031: PASS (mostly) — do not touch
- AD-002, AD-003: **Pattern D/E** — check and fix BH export

### Domain_Controllers (DC)
- DC-007, DC-019: PASS — do not touch
- DC-001, DC-002, DC-009 to DC-018, DC-020 to DC-036: **Pattern H** — complex, fix unclosed string + BH export
- DC-037 to DC-039: **Pattern A/C** — fix PropertiesToLoad
- DC-040: Mixed — read file and identify pattern

### Group_Policy (GPO)
- GPO-001 to GPO-030: **Pattern E** — fix BH export block only
- GPO-031 to GPO-050: PASS — do not touch
- GPO-051: **Pattern I** — complex regex hashtable + BH export fix

### Kerberos_Security (KRB)
- KRB-001, KRB-019, KRB-021: **Pattern D** — fix PropertiesToLoad (two blocks) + BH export
- KRB-002, KRB-004, KRB-009, KRB-010, KRB-013 to KRB-018, KRB-020, KRB-022, KRB-026, KRB-029, KRB-030: **Pattern E** — fix BH export only
- KRB-003, KRB-005 to KRB-008, KRB-011, KRB-012, KRB-015, KRB-016, KRB-023 to KRB-025, KRB-027, KRB-028: **Pattern D** — fix PropertiesToLoad + BH export
- KRB-031 to KRB-045: **Pattern B** — fix PropertiesToLoad
- KRB-038: PASS — do not touch

### LDAP_Security (LDAP)
- LDAP-001, LDAP-002, LDAP-004 to LDAP-010, LDAP-012, LDAP-013, LDAP-015: **Pattern B** — fix PropertiesToLoad
- LDAP-003, LDAP-006, LDAP-009, LDAP-011, LDAP-014: PASS

### Network_Security (NET)
- NET-002 to NET-005, NET-007 to NET-010: **Pattern B** — fix PropertiesToLoad
- NET-001, NET-006: PASS

### Persistence_Detection (PERS)
- PERS-001 to PERS-004, PERS-006 to PERS-009, PERS-011, PERS-012: **Pattern B** — fix PropertiesToLoad
- PERS-005, PERS-010: PASS

### PKI_Services (PKI)
- PKI-001 to PKI-030: ALL PASS — do not touch

### Privileged_Access (PRV)
- PRV-001 to PRV-016, PRV-021 to PRV-028: **Pattern E** — fix BH export only
- PRV-017, PRV-018: **Pattern D** — fix PropertiesToLoad + BH export
- PRV-019, PRV-020, PRV-029, PRV-030: **Pattern D** — fix PropertiesToLoad + BH export
- PRV-031, PRV-032: **Pattern C** — fix PropertiesToLoad + $results + BH export

### Published_Resources (PUBRES)
- PUBRES-001 to PUBRES-030: ALL PASS — do not touch

### Security_Accounts (SECACCT)
- SECACCT-001 to SECACCT-030: ALL PASS — do not touch
- AD-005: **Pattern A** — fix PropertiesToLoad
- SECACCT-002: Missing CMD result — check cmd.bat exists

### Service_Accounts (SVC)
- SVC-001 to SVC-030: **Pattern D** — fix PropertiesToLoad (two blocks) + BH export
- SVC-031: **Pattern C** — fix PropertiesToLoad + $results + BH export
- CMD errors SVC-001 to SVC-030: Fix dsquery filter (Pattern CMD-1 above)

### SMB_Security (SMB)
- SMB-001 to SMB-012: **Pattern B** — fix PropertiesToLoad

### Trust_Management (TMGMT)
- TMGMT-001 to TMGMT-030: **Pattern F** — remove extra } at line 46
- TMGMT-031, TMGMT-032: **Pattern F variant** (error at line 31) — same fix

### Trust_Relationships (TRST)
- TRST-001, TRST-007, TRST-018, TRST-019, TRST-021 to TRST-023, TRST-025, TRST-030: **Pattern E** — fix BH export only
- TRST-002, TRST-003, TRST-004: **Pattern E** — fix BH export
- TRST-005 to TRST-017, TRST-020, TRST-024, TRST-026 to TRST-029: **Pattern G** — fix catch order + BH export
- TRST-031: CMD error — fix dsquery startnode format. ADSI: PASS

### Users_Accounts (USR)
- USR-001, USR-003, USR-006, USR-008, USR-009, USR-011, USR-012, USR-014, USR-015, USR-017, USR-018, USR-021, USR-022, USR-026, USR-027, USR-032: **Pattern E** — fix BH export only
- USR-002, USR-004, USR-005, USR-007, USR-010, USR-013, USR-016, USR-019, USR-020, USR-023, USR-024, USR-025, USR-028, USR-029, USR-030, USR-031: **Pattern D** — fix PropertiesToLoad + BH export
- USR-033, USR-034, USR-035: **Pattern C** — fix PropertiesToLoad + $results + BH export

---

## VERIFICATION CHECKLIST

After completing all fixes, run this against every fixed adsi.ps1:

```powershell
$suiteRoot = 'C:\users\vagrant\Desktop\AD_SUITE_TESTING'
$results = @{ Pass=0; Fail=0; Files=@() }

Get-ChildItem $suiteRoot -Recurse -Filter 'adsi.ps1' | ForEach-Object {
    $errors = $null
    $null   = [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$null, [ref]$errors)
    if ($errors.Count -eq 0) {
        $results.Pass++
    } else {
        $results.Fail++
        $results.Files += [pscustomobject]@{
            File   = $_.FullName -replace [regex]::Escape($suiteRoot),''
            Errors = $errors.Count
            First  = "Line $($errors[0].Extent.StartLineNumber): $($errors[0].Message)"
        }
    }
}

Write-Host "PASS: $($results.Pass) | FAIL: $($results.Fail)"
$results.Files | Format-Table -AutoSize
```

**Target: FAIL = 0**

---

## CRITICAL DON'T-DO LIST

- **DO NOT** fix PowerShell.ps1 — they are all passing
- **DO NOT** change any LDAP filter in adsi.ps1
- **DO NOT** change any PSCustomObject field names or values in main script body
- **DO NOT** modify the $results = $searcher.FindAll() insertion (Phase 1 fix)
- **DO NOT** remove objectSid from PropertiesToLoad — just fix the syntax
- **DO NOT** add new properties or fields
- **DO NOT** change the BH export template structure — only fix string quoting and check-specific substitutions
- **DO NOT** touch INFRA, PKI, PUBRES, SECACCT, most DCONF — these are all passing