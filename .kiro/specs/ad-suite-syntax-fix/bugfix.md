# Bugfix Requirements Document

## Introduction

The AD Security Suite automated test run (2026-03-14) revealed a 56.75% success rate (1,291/2,275 scripts passing), with 515 scripts failing due to syntax errors. The primary issue affects ADSI engine scripts (~33% passing rate) which need to reach 100% success. This bugfix addresses 9 distinct syntax error patterns introduced during previous enhancement phases, specifically:

- Broken PropertiesToLoad array syntax (objectSid addition caused line breaks)
- BloodHound export block string terminator issues
- Structural problems (extra braces, catch block ordering, unclosed strings)
- CMD engine filter compatibility issues

The fix will restore all scripts to syntactically valid state without changing functionality, raising the ADSI engine success rate from 33% to 100%.

## Bug Analysis

### Current Behavior (Defect)

1.1 WHEN an ADSI script contains PropertiesToLoad with objectSid addition that spans multiple lines THEN the PowerShell parser reports "Missing closing ')' in expression" at the array line and "Unexpected token" at the next statement

1.2 WHEN an ADSI script contains a BloodHound export block with improperly terminated double-quoted strings (e.g., check names with apostrophes, "Active Directory" references) THEN the parser reports "The string is missing the terminator" and cascading errors for all subsequent braces and try-catch blocks

1.3 WHEN a TMGMT script contains an extra closing brace at line 46 THEN the parser reports "Unexpected token '}' in expression or statement"

1.4 WHEN a TRST script has catch blocks ordered with untyped catch before typed catch THEN the parser reports "Catch block must be the last catch block"

1.5 WHEN a DC script contains Write-Host statements with unclosed double-quoted strings containing backtick-n escape sequences THEN the parser reports "Unexpected token '`nSummary:' in expression" and "The string is missing the terminator"

1.6 WHEN GPO-051 script contains regex patterns in hashtables with unescaped quote characters THEN the parser reports multiple string terminator and hash literal errors

1.7 WHEN a CMD script uses LDAP extensible match filters with OID syntax (userAccountControl:1.2.840.113556.1.4.803:=) THEN dsquery reports "The search filter cannot be recognized"

1.8 WHEN a CMD script uses dsquery with specific object type (e.g., dsquery computer) and -filter parameter THEN dsquery reports "'-filter' is an unknown parameter"

1.9 WHEN a CMD script passes malformed DN to dsquery startnode parameter THEN dsquery reports "Value for 'startnode' has incorrect format"

### Expected Behavior (Correct)

2.1 WHEN an ADSI script contains PropertiesToLoad with objectSid THEN the array SHALL be formatted on a single line with proper closing parenthesis before the pipe operator: `@('attr1', 'attr2', 'objectSid') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }`

2.2 WHEN an ADSI script contains a BloodHound export block THEN all string properties SHALL use single quotes for values containing apostrophes, properly escaped apostrophes (''), or double quotes for plain strings, ensuring all strings are properly terminated

2.3 WHEN a TMGMT script reaches line 46 THEN it SHALL contain only matched braces with the BloodHound export block starting after the main ForEach block's closing brace

2.4 WHEN a TRST script contains multiple catch blocks THEN typed catch blocks SHALL precede the untyped catch block: `} catch [SpecificException] { ... } catch { ... }`

2.5 WHEN a DC script contains Write-Host statements with backtick-n escape sequences THEN all double-quoted strings SHALL have proper closing quotes before the line end

2.6 WHEN GPO-051 script contains regex patterns in hashtables THEN each pattern SHALL use appropriate quote style (single quotes for patterns with double quotes, double quotes for patterns with single quotes) with proper escaping

2.7 WHEN a CMD script needs to filter by userAccountControl flags THEN it SHALL use simplified dsquery filters without OID extensible match syntax: `dsquery * -filter "(&(objectCategory=person)(objectClass=user)(servicePrincipalName=*))"`

2.8 WHEN a CMD script needs to use LDAP filters THEN it SHALL use `dsquery *` with -filter parameter instead of specific object type commands

2.9 WHEN a CMD script passes DN to dsquery startnode THEN it SHALL construct valid DN format from %DCPATH% variable: `DC=domain,DC=tld`

### Unchanged Behavior (Regression Prevention)

3.1 WHEN a PowerShell.ps1 script is already passing (100% success rate) THEN the system SHALL CONTINUE TO leave it unmodified

3.2 WHEN an ADSI script contains LDAP filter logic in the main script body THEN the system SHALL CONTINUE TO preserve the exact filter syntax

3.3 WHEN an ADSI script contains PSCustomObject field names and values THEN the system SHALL CONTINUE TO preserve all field definitions

3.4 WHEN an ADSI script contains the $results = $searcher.FindAll() variable assignment (Phase 1 fix) THEN the system SHALL CONTINUE TO preserve this assignment

3.5 WHEN an ADSI script contains objectSid in PropertiesToLoad array THEN the system SHALL CONTINUE TO include objectSid in the array (only fixing syntax, not removing the property)

3.6 WHEN a BloodHound export block template is corrected THEN the system SHALL CONTINUE TO maintain the standard structure with try-catch wrapper, $bhSession, $bhDir, $bhNodes list, and JSON export

3.7 WHEN scripts in INFRA, PKI, PUBRES, SECACCT, or most DCONF categories are already passing THEN the system SHALL CONTINUE TO leave them unmodified

3.8 WHEN a CMD script has timeout status (70% of CMD scripts) THEN the system SHALL CONTINUE TO accept timeout as expected behavior and not modify those scripts

3.9 WHEN an ADSI script is fixed for syntax errors THEN the system SHALL CONTINUE TO produce functionally identical output for all valid inputs (no logic changes)
