# AD Suite Syntax Fix Bugfix Design

## Overview

This bugfix addresses 515 syntax errors in the AD Security Suite that reduced the ADSI engine success rate to ~33%. The errors were introduced during previous enhancement phases (objectSid addition to PropertiesToLoad arrays and BloodHound export block appending). The fix will restore all scripts to syntactically valid state without changing functionality, raising the ADSI engine success rate from 33% to 100%.

The fix strategy uses pattern-based categorization: 9 distinct error patterns have been identified, each with a specific algorithmic fix. The approach is surgical—fix only broken syntax, preserve all logic, and verify with PowerShell's AST parser.

## Glossary

- **Bug_Condition (C)**: The condition that triggers syntax errors - when PropertiesToLoad arrays span multiple lines, BloodHound export blocks have unterminated strings, or structural issues exist (extra braces, catch block ordering, unclosed strings)
- **Property (P)**: The desired behavior - all scripts parse with zero errors using PowerShell's AST parser
- **Preservation**: All existing logic, LDAP filters, PSCustomObject fields, and functional behavior must remain unchanged
- **PropertiesToLoad**: PowerShell array syntax `@('attr1', 'attr2', ..., 'objectSid') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }` that must be on a single line
- **BloodHound Export Block**: JSON export code block appended to scripts with try-catch wrapper, containing metadata properties that must use proper string quoting
- **Pattern**: One of 9 distinct error signatures identified in the test results, each requiring a specific fix algorithm
- **AST Parser**: PowerShell's `[System.Management.Automation.Language.Parser]::ParseFile()` used for syntax validation

## Bug Details

### Fault Condition

The bug manifests when PowerShell scripts contain syntax errors that prevent parsing. The errors fall into 9 distinct patterns based on error messages, line numbers, and affected script categories.

**Formal Specification:**
```
FUNCTION isBugCondition(scriptFile)
  INPUT: scriptFile of type FileInfo (PowerShell .ps1 file)
  OUTPUT: boolean
  
  errors := []
  AST := PowerShellParser.ParseFile(scriptFile.Path, ref null, ref errors)
  
  RETURN errors.Count > 0
         AND scriptFile.Name == 'adsi.ps1'
         AND (
           errors.Any(e => e.Message CONTAINS "Missing closing ')' in expression")
           OR errors.Any(e => e.Message CONTAINS "The string is missing the terminator")
           OR errors.Any(e => e.Message CONTAINS "Unexpected token")
           OR errors.Any(e => e.Message CONTAINS "Catch block must be the last")
         )
END FUNCTION
```

### Examples

- **Pattern A (Broken PropertiesToLoad)**: ACC-002/adsi.ps1 line 44 reports "Missing closing ')' in expression" because the array spans two lines: `@('name', 'distinguishedName', 'objectSid'\n) | ForEach-Object`. Expected: single line with proper closing before pipe.

- **Pattern D (Two broken PropertiesToLoad + BH export)**: AUTH-031/adsi.ps1 reports errors at lines 20, 22, 134, 136, and 173+ because TWO searcher blocks have broken arrays AND the BloodHound export block has an unterminated string containing "Active Directory". Expected: both arrays fixed, BH export strings properly quoted.

- **Pattern F (Extra brace)**: TMGMT-001/adsi.ps1 line 46 reports "Unexpected token '}'" because an extra closing brace was inserted. Expected: remove spurious brace, verify all braces match.

- **Pattern G (Catch block ordering)**: TRST-005/adsi.ps1 line 152 reports "Catch block must be the last catch block" because untyped catch precedes typed catch. Expected: `} catch [ADException] { ... } catch { ... }` order.

## Expected Behavior

### Preservation Requirements

**Unchanged Behaviors:**
- All PowerShell.ps1 scripts (100% passing) must remain completely unmodified
- LDAP filter syntax in main script bodies must be preserved exactly
- PSCustomObject field names and values must remain unchanged
- The $results = $searcher.FindAll() variable assignment (Phase 1 fix) must be preserved
- objectSid property must remain in PropertiesToLoad arrays (only syntax fixed, not removed)
- BloodHound export block structure (try-catch wrapper, $bhSession, $bhDir, $bhNodes list, JSON export) must be maintained
- Scripts in INFRA, PKI, PUBRES, SECACCT, and most DCONF categories (already passing) must not be touched
- CMD scripts with timeout status (70% of CMD scripts) should not be modified
- All functional output for valid inputs must remain identical after syntax fixes

**Scope:**
All scripts that do NOT have syntax errors (parse with zero errors) should be completely unaffected by this fix. This includes:
- PowerShell.ps1 engine scripts (all passing)
- Already-passing adsi.ps1 scripts in specific categories
- cmd.bat scripts without the 3 specific CMD error types
- Any script that successfully parses with PowerShell's AST parser

## Hypothesized Root Cause

Based on the bug description and error patterns, the most likely issues are:

1. **PropertiesToLoad Array Line Break**: The objectSid addition to PropertiesToLoad arrays introduced newlines before the closing parenthesis, causing the array to span multiple lines. PowerShell requires the closing `)` before the pipe operator `|` on the same line. This affects 300+ scripts across multiple categories.

2. **BloodHound Export String Terminator**: The BloodHound export block appending process failed to properly quote strings containing apostrophes (e.g., "Can't Delegate") or multi-word phrases (e.g., "Active Directory"). Double-quoted strings were not closed, causing the parser to consume subsequent code as part of the string.

3. **TMGMT Extra Brace**: The TMGMT scripts (~40 lines) had the BloodHound export block's closing brace inserted inside the main ForEach block instead of after it, creating an unmatched brace at line 46.

4. **TRST Catch Block Ordering**: Trust relationship scripts with multi-catch try statements had untyped catch blocks placed before typed catch blocks during code generation, violating PowerShell's catch block ordering rules.

5. **DC Unclosed Write-Host Strings**: Complex DC scripts with Write-Host statements using backtick-n escape sequences had missing closing double-quotes, causing the parser to treat all subsequent code (including the BH export block) as part of the string.

6. **GPO-051 Regex Hashtable Quoting**: The SYSVOL credential scan script's regex patterns contain special characters (quotes, brackets) that interfere with string parsing when the BH export block is appended.

7. **CMD OID Filter Incompatibility**: Service account checks use LDAP extensible match filters with OID syntax (userAccountControl:1.2.840.113556.1.4.803:=) that dsquery cannot process.

8. **CMD dsquery Object Type Parameter**: DC-013 uses `dsquery computer -filter` but specific object type commands don't accept the -filter parameter (only `dsquery *` does).

9. **CMD Startnode DN Format**: TRST-031 passes malformed DN to dsquery startnode parameter.

## Correctness Properties

Property 1: Fault Condition - All Scripts Parse Successfully

_For any_ PowerShell script file where syntax errors exist (isBugCondition returns true), the fixed script SHALL parse with zero errors when validated using PowerShell's AST parser, producing a valid abstract syntax tree.

**Validates: Requirements 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 2.9**

Property 2: Preservation - Functional Behavior Unchanged

_For any_ script input that does NOT have syntax errors (isBugCondition returns false) OR for any valid runtime input to a fixed script, the fixed code SHALL produce exactly the same functional output, LDAP queries, and side effects as the original code, preserving all logic and behavior.

**Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 3.9**

## Fix Implementation

### Changes Required

Assuming our root cause analysis is correct:

**Files**: All `adsi.ps1` files in affected categories (515 files), plus 3 specific `cmd.bat` files

**Pattern-Based Fix Algorithm**:

1. **Pattern A/B/C - PropertiesToLoad Single Line Fix**:
   - Locate all lines containing `| ForEach-Object { [void]$searcher.PropertiesToLoad.Add`
   - Extract the `@(...)` array portion
   - Consolidate to single line: `@('attr1', 'attr2', ..., 'objectSid') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }`
   - Remove any trailing commas, doubled parentheses, or newlines within the array
   - Verify single `)` before `|`

2. **Pattern D/E - BloodHound Export Block String Fix**:
   - Locate BH export block (search for `$bhSession =` or `# ── BloodHound Export`)
   - Parse block in isolation to identify string terminator errors
   - Replace entire block with clean template, substituting:
     - `CHECKID_PLACEHOLDER` → actual check ID (e.g., 'ACC-014')
     - `CHECKNAME_PLACEHOLDER` → check name with single quotes, apostrophes escaped as `''`
     - `SEVERITY_PLACEHOLDER` → severity level
     - `CATEGORY_PLACEHOLDER` → folder name
     - `NODETYPE_PLACEHOLDER` → BloodHound node type
   - Ensure all strings use single quotes to avoid double-quote terminator issues

3. **Pattern F - TMGMT Extra Brace Removal**:
   - Read file completely
   - Count opening `{` and closing `}` braces
   - Identify the spurious `}` at line 46 that doesn't match an opening `{`
   - Remove the extra brace
   - Verify BH export block starts AFTER the main ForEach block's closing brace

4. **Pattern G - TRST Catch Block Reordering**:
   - Locate try-catch blocks with multiple catch clauses
   - Identify untyped `catch { }` blocks that precede typed `catch [ExceptionType] { }` blocks
   - Reorder so all typed catches come before the untyped catch
   - Fix BH export block string issues (Pattern E)

5. **Pattern H - DC Unclosed String Fix**:
   - Search backwards from first error line for Write-Host or string assignment using double quotes
   - Identify the line where closing `"` is missing
   - Add missing closing quote at end of line
   - Fix BH export block if also needed

6. **Pattern I - GPO-051 Regex Hashtable Fix**:
   - Locate `$credentialPatterns` hashtable
   - For each regex pattern:
     - Use single quotes for patterns containing `"` (double quotes)
     - Use double quotes for patterns containing `'` (single quotes)
     - Escape PowerShell special characters if needed
   - Verify BH export block is not nested inside existing try blocks

7. **CMD Error Fix 1 - SVC OID Filter Simplification**:
   - In SVC-001 through SVC-030 cmd.bat files
   - Replace OID extensible match filter with simplified filter:
     ```bat
     dsquery * %DCPATH% -filter "(&(objectCategory=person)(objectClass=user)(servicePrincipalName=*))" -limit 0 -attr name distinguishedname samaccountname serviceprincipalname description
     ```
   - Remove `userAccountControl:1.2.840.113556.1.4.803:=` portion

8. **CMD Error Fix 2 - DC-013 dsquery Command Type**:
   - Change `dsquery computer -filter "..."` to `dsquery * -filter "..."`

9. **CMD Error Fix 3 - TRST-031 Startnode DN Format**:
   - Verify dsquery startnode constructs valid DN: `DC=domain,DC=tld` from `%DCPATH%`

### Data Structures for Tracking Fixes

```powershell
# Fix tracking structure
$fixTracker = @{
    TotalScanned = 0
    TotalFixed = 0
    ByPattern = @{
        PatternA = @{ Count=0; Files=@() }
        PatternB = @{ Count=0; Files=@() }
        PatternC = @{ Count=0; Files=@() }
        PatternD = @{ Count=0; Files=@() }
        PatternE = @{ Count=0; Files=@() }
        PatternF = @{ Count=0; Files=@() }
        PatternG = @{ Count=0; Files=@() }
        PatternH = @{ Count=0; Files=@() }
        PatternI = @{ Count=0; Files=@() }
    }
    ByCategory = @{}  # Category name => { Pass=N, Fail=N, Fixed=N }
    FailedToFix = @()  # Files that still have errors after fix attempt
}

# Pattern detection result
$patternResult = @{
    FilePath = ''
    Pattern = ''  # 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', or 'PASS'
    ErrorCount = 0
    FirstError = @{
        Line = 0
        Message = ''
    }
}
```

## Testing Strategy

### Validation Approach

The testing strategy follows a two-phase approach: first, surface counterexamples that demonstrate the bugs on unfixed code using PowerShell's AST parser, then verify the fixes work correctly and preserve existing behavior through re-parsing and functional testing.

### Exploratory Fault Condition Checking

**Goal**: Surface counterexamples that demonstrate the syntax errors BEFORE implementing the fix. Confirm or refute the root cause analysis by examining actual parse errors. If we refute, we will need to re-hypothesize.

**Test Plan**: Run PowerShell's AST parser on all adsi.ps1 files in the UNFIXED codebase. Collect all parse errors with line numbers and messages. Categorize each failing file into one of the 9 patterns based on error signatures. This confirms which patterns exist and their frequency.

**Test Cases**:
1. **Pattern A Detection Test**: Parse ACC-002/adsi.ps1 unfixed - expect "Missing closing ')' in expression" at line 44 and "Unexpected token 'try'" at line 47 (will fail on unfixed code)
2. **Pattern D Detection Test**: Parse AUTH-031/adsi.ps1 unfixed - expect errors at lines 20, 22, 134, 136, and 173+ for two broken PropertiesToLoad and BH export string (will fail on unfixed code)
3. **Pattern F Detection Test**: Parse TMGMT-001/adsi.ps1 unfixed - expect "Unexpected token '}'" at line 46 (will fail on unfixed code)
4. **Pattern G Detection Test**: Parse TRST-005/adsi.ps1 unfixed - expect "Catch block must be the last catch block" at line 152 (will fail on unfixed code)
5. **PowerShell.ps1 Baseline Test**: Parse all PowerShell.ps1 files - expect zero errors (should pass on unfixed code, confirming preservation target)

**Expected Counterexamples**:
- 515 adsi.ps1 files will fail parsing with specific error patterns
- Error messages will match the 9 pattern signatures documented in xxxmain.md
- Possible causes: objectSid addition line breaks, BH export string quoting, structural issues from code generation

### Fix Checking

**Goal**: Verify that for all scripts where the bug condition holds, the fixed script produces the expected behavior (zero parse errors).

**Pseudocode:**
```
FOR ALL scriptFile WHERE isBugCondition(scriptFile) DO
  fixedScript := applyPatternFix(scriptFile, identifyPattern(scriptFile))
  errors := []
  AST := PowerShellParser.ParseFile(fixedScript.Path, ref null, ref errors)
  ASSERT errors.Count == 0
END FOR
```

**Verification Algorithm**:
```powershell
# After applying fixes, re-parse all fixed files
$verificationResults = @{ Pass=0; Fail=0; Files=@() }

Get-ChildItem $suiteRoot -Recurse -Filter 'adsi.ps1' | ForEach-Object {
    $errors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$null, [ref]$errors)
    
    if ($errors.Count -eq 0) {
        $verificationResults.Pass++
    } else {
        $verificationResults.Fail++
        $verificationResults.Files += [pscustomobject]@{
            File = $_.FullName
            Errors = $errors.Count
            First = "Line $($errors[0].Extent.StartLineNumber): $($errors[0].Message)"
        }
    }
}

# Target: Fail = 0
```

### Preservation Checking

**Goal**: Verify that for all scripts where the bug condition does NOT hold, the fixed codebase produces the same result as the original codebase (no modifications made).

**Pseudocode:**
```
FOR ALL scriptFile WHERE NOT isBugCondition(scriptFile) DO
  ASSERT scriptFile_original.Content == scriptFile_fixed.Content
END FOR
```

**Testing Approach**: Property-based testing is recommended for preservation checking because:
- It generates many test cases automatically across the input domain (all script files)
- It catches edge cases that manual unit tests might miss (scripts that should not be touched)
- It provides strong guarantees that behavior is unchanged for all non-buggy inputs

**Test Plan**: Before applying any fixes, create a hash manifest of all files. After fixes, verify that:
1. All PowerShell.ps1 files have identical hashes (not modified)
2. All already-passing adsi.ps1 files have identical hashes
3. All cmd.bat files without the 3 specific errors have identical hashes
4. For fixed adsi.ps1 files, run functional comparison tests

**Test Cases**:
1. **PowerShell.ps1 Preservation**: Hash all PowerShell.ps1 files before and after - expect 100% match (no modifications)
2. **Passing adsi.ps1 Preservation**: Hash all adsi.ps1 files that parse successfully before fix - expect 100% match after fix
3. **LDAP Filter Preservation**: Extract all LDAP filter strings from fixed scripts - expect exact match with original filters
4. **PSCustomObject Preservation**: Extract all PSCustomObject definitions from fixed scripts - expect exact field names and structure match
5. **Functional Output Preservation**: Run sample fixed scripts against test AD environment - expect identical output to unfixed scripts (for scripts that could run despite syntax errors in unreached code paths)

### Unit Tests

- Test PropertiesToLoad line consolidation algorithm on sample broken arrays
- Test BloodHound export block template substitution with various check names (apostrophes, quotes, special chars)
- Test brace matching algorithm for TMGMT pattern
- Test catch block reordering algorithm for TRST pattern
- Test string terminator detection for DC pattern
- Test regex hashtable quoting logic for GPO-051 pattern
- Test CMD filter simplification for SVC pattern
- Test dsquery command type replacement for DC-013 pattern
- Test DN format validation for TRST-031 pattern

### Property-Based Tests

- Generate random PropertiesToLoad arrays with various attribute combinations - verify consolidation produces valid single-line syntax
- Generate random check metadata (IDs, names with special chars, severities, categories) - verify BH export block template produces valid PowerShell strings
- Generate random brace nesting patterns - verify brace matching algorithm correctly identifies unmatched braces
- Generate random catch block orderings - verify reordering algorithm produces valid PowerShell catch sequences
- Generate random file content hashes - verify preservation checking correctly identifies unchanged files

### Integration Tests

- Run full fix pipeline on a test subset of 50 scripts (10 from each pattern category) - verify all parse successfully after fix
- Run full fix pipeline on entire suite - verify target of 100% ADSI success rate achieved
- Execute fixed scripts against test AD environment - verify functional output matches expected results
- Run automated test suite after fixes - verify success rate increases from 56.75% to target level
- Verify BloodHound JSON exports from fixed scripts are valid and importable

