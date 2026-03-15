# 🎯 Attack Path Analysis Test Files

## 📁 Available Test Files

### 1. **GOAD Simulation Findings**
**File**: `sample_goad_findings.json`  
**Domain**: `sevenkingdoms.local`  
**Scenario**: Game of Active Directory (GOAD) environment simulation

#### Attack Chains Included:
- **ASREPRoasting**: `sansa.stark` (no Kerberos pre-auth)
- **Kerberoasting**: `tyrion.lannister` (SPN account)
- **Domain Admin Access**: `eddard.stark` (Domain Admins member)
- **Unconstrained Delegation**: `winterfell-server` (ticket theft)
- **DCSync Rights**: `cersei.lannister` (domain replication)
- **Local Admin on DCs**: `robert.baratheon` (critical privilege)

### 2. **Advanced Attack Scenario**
**File**: `advanced_attack_scenario.json`  
**Domain**: `contoso.local`  
**Scenario**: Complex enterprise environment with multiple attack paths

#### Attack Chains Included:
- **Multi-step Privilege Escalation**: User → Service → Domain Admin
- **Unconstrained Delegation Abuse**: Web server for ticket theft
- **DCSync Attack**: Backup admin with domain replication rights
- **Cross-Domain Trust**: Parent-child domain relationships
- **Service Account Exploitation**: Multiple vulnerable service accounts

### 3. **CSV Format**
**File**: `sample_goad_findings.csv`  
**Format**: CSV for easy upload to Attack Path Analysis

---

## 🚀 How to Use These Files

### Method 1: Upload JSON/CSV File
1. Open **http://localhost:5173**
2. Navigate to **Attack Path Analysis**
3. Select **"Upload JSON/CSV"** as data source
4. Choose one of the test files above
5. Click **"Upload"** and then **"Analyze"**

### Method 2: Direct API Testing
```bash
# Test GOAD simulation
curl -X POST -H "Content-Type: application/json" \
-d @sample_goad_findings.json \
http://localhost:3001/api/llm/analyse

# Test advanced scenario
curl -X POST -H "Content-Type: application/json" \
-d @advanced_attack_scenario.json \
http://localhost:3001/api/llm/analyse
```

---

## 🎭 Attack Path Scenarios Explained

### GOAD Scenario (sevenkingdoms.local)
Based on the popular Game of Active Directory lab, this scenario includes:

**Primary Attack Path:**
1. **ASREPRoasting** → `sansa.stark` (no pre-auth)
2. **Kerberoasting** → `tyrion.lannister` (SPN)
3. **Privilege Escalation** → `eddard.stark` (Domain Admin)
4. **Domain Compromise** → Full control

**Secondary Attack Paths:**
- **Unconstrained Delegation** → Ticket theft via `winterfell-server`
- **DCSync Attack** → Domain credentials via `cersei.lannister`
- **Local Admin Abuse** → DC compromise via `robert.baratheon`

### Advanced Scenario (contoso.local)
Enterprise environment with sophisticated attack chains:

**Complex Attack Path:**
1. **Initial Access** → `j.doe` (ASREPRoasting)
2. **Service Compromise** → `sql.service` (Kerberoasting)
3. **Web Server Abuse** → `web01` (unconstrained delegation)
4. **Domain Admin Access** → `admin.admin` (full compromise)

**Alternative Paths:**
- **DCSync Attack** → `backup.admin` (credential extraction)
- **Trust Abuse** → Cross-domain privilege escalation
- **Service Account Chain** → Multiple service account compromises

---

## 🌟 What to Expect in Analysis

### 📊 Generated Attack Graph
- **Nodes**: Color-coded by severity (CRITICAL=red, HIGH=orange, MEDIUM=yellow, LOW=green)
- **Edges**: Attack relationships and privilege escalation paths
- **Types**: Finding nodes, object nodes, control nodes

### 📝 Narrative Analysis
- **Attack Chain Identification**: Step-by-step attack paths
- **MITRE Mapping**: Technique references for each finding
- **Risk Assessment**: Impact and likelihood analysis
- **Recommendations**: Specific remediation steps

### 🎯 Key Features Tested
- ✅ **Multi-path Attack Analysis**
- ✅ **Severity-based Visualization**
- ✅ **MITRE ATT&CK Integration**
- ✅ **Interactive Graph Controls**
- ✅ **Professional Security Reporting**

---

## 🔧 Configuration

### OpenAI Settings
- **Provider**: OpenAI
- **Model**: GPT-4o-mini (recommended for cost-effectiveness)
- **API Key**: Your valid OpenAI key

### Expected Results
- **Processing Time**: 10-30 seconds
- **Graph Nodes**: 10-15 nodes per scenario
- **Attack Edges**: 8-12 relationships
- **Narrative Length**: 500-1000 words

---

## 🎯 Learning Objectives

These test files help you understand:

1. **Real Attack Paths**: Common techniques used in AD penetration testing
2. **Privilege Escalation**: How attackers move from user to domain admin
3. **Visualization**: How security findings translate to attack graphs
4. **Risk Prioritization**: Which vulnerabilities pose the greatest threat
5. **MITRE Mapping**: How findings align with ATT&CK framework

---

## 📚 Additional Resources

- **GOAD Lab**: https://github.com/Orange-Cyberdefense/GOAD
- **MITRE ATT&CK**: https://attack.mitre.org/
- **AD Security Best Practices**: Microsoft documentation
- **Attack Path Analysis Theory**: Academic papers on attack graphs

---

**🚀 Ready to test? Start with `sample_goad_findings.json` for a realistic attack path analysis!**
