# AD Suite Severity and Risk Score Mapping

## Severity to Weight Mapping

| Severity | Weight | Description | Example Checks |
|----------|--------|-------------|----------------|
| **Critical** | 5 | Immediate exploitation risk, direct path to domain compromise | Unconstrained delegation on users, AS-REP roastable accounts, accounts without Kerberos pre-auth |
| **High** | 4 | Significant security misconfiguration, high privilege escalation risk | adminCount=1 issues, RBCD misconfigurations, shadow credentials (KeyCredentialLink), weak encryption |
| **Medium** | 3 | Moderate risk requiring review, potential security impact | sIDHistory populated, certain delegation patterns, password policy weaknesses |
| **Low** | 2 | Minor issues, informational findings with limited direct impact | Configuration recommendations, best practice violations |
| **Info** | 1 | Inventory items, no immediate security risk | Discovery checks, asset enumeration, not yet promoted to risk assessment |

## Risk Score Calculation Formula

```
CheckScore = SeverityWeight × min(FindingCount, FindingCapPerCheck) × ScoreWeight

Where:
- SeverityWeight: 1-5 based on severity level (see table above)
- FindingCount: Number of findings for this check
- FindingCapPerCheck: Maximum findings counted per check (default: 10)
- ScoreWeight: Optional multiplier per check (default: 1.0)
```

### Example Calculations

| Check | Severity | Weight | Findings | Capped Findings | Check Score |
|-------|----------|--------|----------|-----------------|-------------|
| ACC-001 (Privileged Users) | High | 4 | 14 | 10 | 4 × 10 = **40** |
| ACC-002 (Privileged Groups) | High | 4 | 4 | 4 | 4 × 4 = **16** |
| KRB-002 (AS-REP Roastable) | Critical | 5 | 0 | 0 | 5 × 0 = **0** |
| GPO-ACL-001 (SYSVOL ACLs) | High | 4 | 2 | 2 | 4 × 2 = **8** |

## Global Risk Score Calculation

```
GlobalRawScore = Sum of all CheckScores
GlobalScore = min(100, ceiling(GlobalRawScore / Normalizer))

Where:
- Normalizer: Scaling factor (default: 5)
- GlobalScore: Final score capped at 100
```

### Global Risk Bands

| Global Score | Risk Band | Color | Interpretation |
|--------------|-----------|-------|----------------|
| 0 - 30 | **Low** | Green | Minimal security issues, good security posture |
| 31 - 60 | **Moderate** | Orange | Some security concerns, review and remediate findings |
| 61 - 80 | **High** | Dark Orange | Significant security issues, immediate attention required |
| 81 - 100 | **Critical** | Red | Severe security exposure, urgent remediation needed |

## Your Current Scan Results

Based on your Phase B scan:

```
Checks run: 661
With findings: 342
Errors: 30
Total findings: 1,234
Global Score: 100/100
Risk Band: Critical
```

### What This Means

- **342 checks with findings** out of 661 total checks detected security issues
- **1,234 total findings** across all checks (many checks found multiple issues)
- **Global Score 100/100 (Critical)** indicates:
  - Multiple high-severity and critical-severity checks have findings
  - Finding counts are significant (many checks hit the 10-finding cap)
  - Raw score exceeded 500 (100 × 5 normalizer = 500+)

### Score Impact Examples

**High-impact findings:**
- 1 critical check with 10 findings = 50 points (5 × 10)
- 1 high check with 10 findings = 40 points (4 × 10)
- 1 medium check with 10 findings = 30 points (3 × 10)

**Your environment likely has:**
- Multiple privileged account misconfigurations (ACC-* checks)
- Delegation issues (KRB-* checks)
- Group Policy security concerns (GPO-* checks)
- Other high-severity findings across 342 checks

## Scoring Design Principles

1. **Finding Cap (10)**: Prevents a single check with hundreds of findings from dominating the score
2. **Severity Weighting**: Critical issues count 5× more than info-level findings
3. **Normalizer (5)**: Scales raw scores to 0-100 range for easier interpretation
4. **Error Handling**: Checks with errors don't contribute to risk score (prevents false positives)
5. **Category Scoring**: Scores are also aggregated by category for targeted remediation

## Remediation Priority

Focus remediation efforts based on:

1. **Severity**: Critical > High > Medium > Low
2. **Finding Count**: More findings = broader exposure
3. **Check Score**: Combines both factors (severity × findings)
4. **Category**: Target categories with highest aggregate scores

Use the UI dashboard filters to:
- Filter by severity (critical, high) to see most urgent issues
- Sort by "Score" column to prioritize remediation
- Filter by category to focus on specific security domains
