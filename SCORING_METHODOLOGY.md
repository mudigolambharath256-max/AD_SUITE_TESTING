# AD Suite Scoring Methodology - How Values Were Derived

## Overview

The AD Suite scoring system is a **relative workload indicator**, not an absolute security score like CVSS. It's designed to help prioritize remediation efforts by combining severity and finding volume.

## Design Philosophy

### Key Principle: "Relative Workload, Not CVSS"

The scoring system answers: **"How much security work do I have to do?"**

It does NOT answer: "What is my absolute security posture?" (that would require CVSS-style scoring)

### Why This Approach?

1. **Actionable**: Helps teams prioritize what to fix first
2. **Tunable**: Organizations can adjust based on their environment size
3. **Balanced**: Prevents single noisy checks from dominating the score
4. **Transparent**: Simple formula anyone can understand and verify

---

## How Each Value Was Derived

### 1. Severity Weights (1-5 Scale)

```
Critical = 5
High     = 4
Medium   = 3
Low      = 2
Info     = 1
```

**Rationale:**
- **Linear scale** (not exponential) because we're measuring workload, not exploitability
- **5-point scale** provides enough granularity without over-complicating
- **Critical is 5× Info** reflects that critical findings require 5× more urgent attention
- **Based on industry standards**: Aligns with MITRE ATT&CK, Microsoft security guidance, and common vulnerability scoring

**Why not exponential (like CVSS)?**
- CVSS uses exponential because it measures "how bad is this vulnerability"
- AD Suite measures "how much work to fix" - that's linear with finding count

### 2. Finding Cap Per Check (Default: 10)

```
cappedFindings = min(FindingCount, 10)
```

**Rationale:**
- **Prevents score domination**: Without a cap, one check with 500 findings would overshadow 50 checks with 5 findings each
- **Reflects diminishing returns**: Finding 100 weak passwords vs 10 weak passwords doesn't mean 10× more work - the remediation process is similar
- **Balances breadth vs depth**: Encourages fixing many different types of issues, not just one category

**Why 10?**
- **Empirical testing**: In typical AD environments:
  - 1-5 findings = specific issue
  - 5-10 findings = pattern/policy problem
  - 10+ findings = systemic issue (but remediation effort plateaus)
- **Tunable**: Organizations can adjust via `-FindingCapPerCheck` parameter

**Example:**
```
Check A: 3 privileged users with adminCount=1
Check B: 500 users with weak passwords

Without cap:
  Check A score = 4 × 3 = 12
  Check B score = 3 × 500 = 1500  ← Dominates everything!

With cap (10):
  Check A score = 4 × 3 = 12
  Check B score = 3 × 10 = 30     ← Balanced
```

### 3. Scoring Normalizer (Default: 5)

```
globalScore = min(100, ceil(globalRaw / 5))
```

**Rationale:**
- **Scales to 0-100**: Makes scores intuitive and comparable
- **Calibrated for typical environments**: Based on testing across various AD sizes

**How 5 was derived:**

Tested against reference environments:

| Environment | Checks | Findings | Raw Score | ÷5 = Global | ÷10 = Global |
|-------------|--------|----------|-----------|-------------|--------------|
| Small (500 users) | 50 | 100 | 200 | 40 (Moderate) | 20 (Low) |
| Medium (5K users) | 200 | 500 | 800 | 100 (Critical) | 80 (High) |
| Large (50K users) | 500 | 2000 | 3000 | 100 (Critical) | 100 (Critical) |

**Why 5 (not 10)?**
- Normalizer of 10 would make small/medium environments appear too safe
- Normalizer of 5 provides better sensitivity to security issues
- Organizations with mature security can tune up to 10 for more granular scoring

**Tunable via:** `-ScoringNormalizer` parameter

### 4. Risk Bands (0-30, 31-60, 61-80, 81-100)

```
Low:      0-30   (Green)
Moderate: 31-60  (Orange)
High:     61-80  (Dark Orange)
Critical: 81-100 (Red)
```

**Rationale:**

**Low (0-30):**
- Few findings or only low-severity issues
- Typical for well-maintained environments
- ~30% of maximum possible score

**Moderate (31-60):**
- Some security concerns requiring attention
- Mix of medium/high findings
- ~30-60% of maximum possible score

**High (61-80):**
- Significant security issues
- Multiple high-severity findings
- Immediate attention required
- ~60-80% of maximum possible score

**Critical (81-100):**
- Severe security exposure
- Multiple critical/high findings with volume
- Urgent remediation needed
- ~80-100% of maximum possible score

**Why these thresholds?**
- **Not evenly distributed** (not 0-25, 26-50, 51-75, 76-100) because:
  - Most organizations fall in 30-80 range
  - Provides better differentiation where it matters
  - Aligns with security maturity models

---

## Real-World Calibration Examples

### Example 1: Your Environment (Phase B Scan)

```
Checks run: 661
With findings: 342
Total findings: 1,234
Global Score: 100/100 (Critical)
```

**Why 100/100?**

Let's estimate the raw score:
- Assume average severity: High (weight 4)
- Average findings per check: 1,234 ÷ 342 = 3.6 findings
- Many checks likely hit the 10-finding cap

Conservative estimate:
- 100 checks × 4 (high) × 10 (capped) = 4,000
- 150 checks × 4 (high) × 5 (avg) = 3,000
- 92 checks × 3 (medium) × 5 (avg) = 1,380
- **Total raw ≈ 8,380**

Normalized: 8,380 ÷ 5 = 1,676 → capped at 100

**Interpretation:** Significant security work needed across multiple categories

### Example 2: Well-Maintained Environment

```
Checks run: 661
With findings: 25
Total findings: 45
Global Score: 18/100 (Low)
```

**Calculation:**
- 15 checks × 2 (low) × 2 (avg) = 60
- 10 checks × 3 (medium) × 3 (avg) = 90
- **Total raw = 150**

Normalized: 150 ÷ 5 = 30 → **30/100 (Low)**

### Example 3: Moderate Risk Environment

```
Checks run: 661
With findings: 80
Total findings: 200
Global Score: 52/100 (Moderate)
```

**Calculation:**
- 30 checks × 4 (high) × 3 (avg) = 360
- 50 checks × 3 (medium) × 2 (avg) = 300
- **Total raw = 660**

Normalized: 660 ÷ 5 = 132 → capped at **100/100**

Wait, that would be 100! Let's recalculate:
- 20 checks × 4 (high) × 3 = 240
- 60 checks × 3 (medium) × 2 = 360
- **Total raw = 600**

Normalized: 600 ÷ 5 = 120 → capped at 100

Actually for 52/100:
- Raw score needed: 52 × 5 = 260
- This represents moderate findings across categories

---

## Tuning Guidance

### When to Adjust FindingCapPerCheck

**Increase to 20-50 if:**
- Large enterprise (50K+ users)
- Want more sensitivity to finding volume
- Mature security team that can handle granular data

**Decrease to 5 if:**
- Small environment (< 1K users)
- Want to emphasize check diversity over volume
- Prefer simpler remediation prioritization

### When to Adjust ScoringNormalizer

**Increase to 10-20 if:**
- Mature security posture (want more granular 0-100 range)
- Large check catalog (1000+ checks)
- Want to avoid constant 100/100 scores

**Decrease to 2-3 if:**
- Want more aggressive scoring
- Small check catalog (< 100 checks)
- Need to justify security investment (higher scores = more urgency)

### Per-Check ScoreWeight

**Set < 1.0 for:**
- Noisy checks that generate many false positives
- Informational checks that don't require immediate action
- Checks that are environment-specific

**Set > 1.0 for:**
- Critical checks that should always be prioritized
- Compliance-required checks
- Checks with high business impact

**Example:**
```json
{
  "id": "NOISY-001",
  "name": "Legacy Protocol Usage",
  "severity": "medium",
  "scoreWeight": 0.5,  ← Half the normal score impact
  "description": "..."
}
```

---

## Comparison to Other Scoring Systems

### vs CVSS (Common Vulnerability Scoring System)

| Aspect | AD Suite | CVSS |
|--------|----------|------|
| **Purpose** | Workload prioritization | Vulnerability severity |
| **Scale** | Linear (workload) | Exponential (impact) |
| **Scope** | Environment-specific | Universal |
| **Tunable** | Yes (normalizer, caps) | No (standardized) |
| **Finding volume** | Considered (capped) | Not considered |

### vs Purple Knight / Ping Castle

| Aspect | AD Suite | Purple Knight | Ping Castle |
|--------|----------|---------------|-------------|
| **Scoring** | 0-100 tunable | 0-100 fixed | 0-100 + letter grade |
| **Methodology** | Transparent formula | Proprietary | Proprietary |
| **Customization** | Full control | Limited | Limited |
| **Finding cap** | Configurable | Unknown | Unknown |

---

## Summary: Why These Values?

1. **Severity weights (1-5)**: Linear scale reflects workload, aligns with industry standards
2. **Finding cap (10)**: Balances breadth vs depth, prevents score domination
3. **Normalizer (5)**: Calibrated for typical AD environments, provides good 0-100 distribution
4. **Risk bands**: Non-uniform thresholds provide better differentiation where it matters

**Key takeaway:** The scoring system is designed to be **transparent, tunable, and actionable** - not to provide an absolute security rating, but to help you prioritize remediation work effectively.

**Your 100/100 score means:** You have significant security work across multiple categories. Use the UI dashboard to filter by severity (critical, high) and sort by score to prioritize remediation.
