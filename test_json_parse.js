// Test the JSON parsing
const narrative = `# Active Directory Penetration Test Analysis

Based on the findings from the penetration test, we will analyze the potential attack chains leveraging the identified vulnerabilities.

## Findings

### 1. Accounts Without Kerberos Pre-Auth
- **Check ID:** AUTH-001
- **Category:** Authentication
- **Severity:** HIGH
- **Risk Score:** 8
- **MITRE:** T1558.003
- **User Affected:** testuser
- **Distinguished Name:** CN=testuser,CN=Users,DC=test,DC=com

**Description:**
The user \`testuser\` has been identified as an account without Kerberos Pre-Authorization, which allows an adversary to obtain a valid ticket for this account without the need for a password. This vulnerability poses a significant risk for account compromise.

### 2. Domain Admins Members
- **Check ID:** USR-019
- **Category:** Users_Accounts
- **Severity:** CRITICAL
- **Risk Score:** 10
- **MITRE:** T1069.002
- **User Affected:** adminuser
- **Distinguished Name:** CN=adminuser,CN=Users,DC=test,DC=com

**Description:**
The account \`adminuser\` is a member of the Domain Admins group. This is critical because Domain Admins have unrestricted access and control over the domain, giving them the capability to compromise the entire Active Directory environment.

## Potential Attack Chains

### Attack Chain 1: Compromising Domain Admin Account
1. **Exploitation of testuser Account:** 
   - An attacker can exploit the \`testuser\` account, leveraging its lack of Kerberos Pre-Auth to obtain a Ticket Granting Ticket (TGT) using tools like Rubeus or Mimikatz.
  
2. **Performing Privilege Escalation:**
   - Once the attacker has a TGT for \`testuser\`, they may gain access to various resources and services where \`testuser\` has permissions.
   - If \`testuser\` has any of the attributes that allow for privilege escalation or lateral movement, the attacker can leverage these weaknesses.

3. **Accessing Domain Admin:**
   - The attacker can then aim to pivot toward the \`adminuser\`, as it is a member of the Domain Admins group.
   - If the attacker can compromise \`adminuser\`, they will potentially gain complete control over the Active Directory environment.

### Attack Chain 2: Direct Attack on Adminuser Account
1. **Direct Attack on \`adminuser\`:**
   - Since \`adminuser\` is critical and has known vulnerabilities associated with group permissions, an attacker with some level of access can attempt to exploit this account directly, especially if they can guess or crack its password.
  
2. **Domain Control:**
   - If the attacker successfully compromises \`adminuser\`, they will have immediate access to all domain resources and complete authority to further manipulate or compromise the entire Active Directory setup.

## Visualisation

\`\`\`json
{
  "graph": {
    "nodes": [
      {
        "id": "AUTH-001",
        "label": "Accounts Without Kerberos Pre-Auth",
        "type": "finding",
        "severity": "HIGH"
      },
      {
        "id": "USR-019",
        "label": "Domain Admins Members",
        "type": "finding",
        "severity": "CRITICAL"
      },
      {
        "id": "testuser",
        "label": "testuser",
        "type": "object",
        "severity": "LOW"
      },
      {
        "id": "adminuser",
        "label": "adminuser",
        "type": "object",
        "severity": "CRITICAL"
      }
    ],
    "edges": [
      {
        "source": "AUTH-001",
        "target": "testuser",
        "label": "Exploits"
      },
      {
        "source": "testuser",
        "target": "USR-019",
        "label": "Targets"
      },
      {
        "source": "USR-019",
        "target": "adminuser",
        "label": "Critical Access"
      }
    ]
  }
}
\`\`\` 
This structured analysis and visualisation enables understanding of the vulnerabilities present and potential attack paths, emphasizing the critical need for security measures and controls.`;

function parseGraphFromResponse(narrative) {
  try {
    // Try to find graph data in different formats
    let graphMatch = narrative.match(/```graph\n([\s\S]*?)\n```/);
    if (!graphMatch) {
      graphMatch = narrative.match(/```json\n([\s\S]*?)\n```/);
    }
    
    if (graphMatch) {
      let graphText = graphMatch[1];
      const graphJson = JSON.parse(graphText);
      
      // Handle both formats: direct nodes/edges or wrapped in graph object
      if (graphJson.graph) {
        return {
          nodes: graphJson.graph.nodes || [],
          edges: graphJson.graph.edges || []
        };
      } else {
        return {
          nodes: graphJson.nodes || [],
          edges: graphJson.edges || []
        };
      }
    }
  } catch (error) {
    console.error('Error parsing graph from response:', error);
  }

  return { nodes: [], edges: [] };
}

const result = parseGraphFromResponse(narrative);
console.log('Parsed Graph Data:');
console.log(JSON.stringify(result, null, 2));
