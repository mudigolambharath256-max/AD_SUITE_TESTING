const express = require('express');
const router = express.Router();
const fs = require('fs');
const path = require('path');
const db = require('../services/db');

// GET /api/bloodhound/scan/:scanId - Get BloodHound data for a scan
router.get('/scan/:scanId', (req, res) => {
    try {
        const { scanId } = req.params;

        // Get scan info
        const scan = db.getScan(scanId);
        if (!scan) {
            return res.status(404).json({ error: 'Scan not found' });
        }

        // Look for BloodHound JSON files in reports directory
        const reportsDir = path.join(__dirname, '..', 'reports');
        const scanDir = path.join(reportsDir, scanId);
        const bloodhoundDir = path.join(scanDir, 'bloodhound');

        let allNodes = [];
        let allEdges = [];

        // Try to read BloodHound JSON files first
        if (fs.existsSync(bloodhoundDir)) {
            const jsonFiles = fs.readdirSync(bloodhoundDir)
                .filter(file => file.endsWith('.json'));

            for (const file of jsonFiles) {
                try {
                    const filePath = path.join(bloodhoundDir, file);
                    const content = JSON.parse(fs.readFileSync(filePath, 'utf8'));

                    if (content.data && Array.isArray(content.data)) {
                        allNodes.push(...content.data);
                    }
                } catch (error) {
                    console.error(`Error reading BloodHound file ${file}:`, error);
                }
            }
        }

        // If no BloodHound data found, convert findings to BloodHound format
        if (allNodes.length === 0) {
            console.log(`No BloodHound files found for scan ${scanId}, converting findings...`);
            const findings = db.getScanFindings(scanId);

            if (findings && findings.length > 0) {
                allNodes = convertFindingsToNodes(findings);
                console.log(`Converted ${findings.length} findings to ${allNodes.length} nodes`);
            }
        }

        // Generate edges based on AD relationships
        const edges = generateADRelationships(allNodes);

        // Add virtual attacker node if we have attack edges
        const hasAttackEdges = edges.some(e => e.type === 'attack');
        if (hasAttackEdges) {
            allNodes.push({
                ObjectIdentifier: 'ATTACKER_NODE',
                Properties: {
                    name: 'ATTACKER',
                    domain: 'EXTERNAL',
                    distinguishedname: 'CN=ATTACKER,CN=EXTERNAL',
                    samaccountname: 'ATTACKER',
                    enabled: true,
                    isdeleted: false
                },
                Labels: ['ATTACKER'],
                Aces: [],
                IsDeleted: false,
                IsACLProtected: false
            });
        }

        res.json({
            nodes: allNodes,
            edges: edges,
            meta: {
                scanId,
                nodeCount: allNodes.length,
                edgeCount: edges.length,
                timestamp: scan.timestamp,
                source: allNodes.length > 0 ? (fs.existsSync(bloodhoundDir) ? 'bloodhound_export' : 'findings_conversion') : 'none'
            }
        });

    } catch (error) {
        console.error('Error getting BloodHound data:', error);
        res.status(500).json({ error: error.message });
    }
});

// GET /api/bloodhound/findings/:scanId - Convert findings to BloodHound format
router.get('/findings/:scanId', (req, res) => {
    try {
        const { scanId } = req.params;

        // Get findings from database
        const findings = db.getScanFindings(scanId);

        if (!findings || findings.length === 0) {
            return res.json({
                nodes: [],
                edges: [],
                message: 'No findings available for this scan'
            });
        }

        // Convert findings to BloodHound-style nodes
        const nodes = convertFindingsToNodes(findings);
        const edges = generateRelationshipsFromFindings(findings, nodes);

        res.json({
            nodes,
            edges,
            meta: {
                scanId,
                nodeCount: nodes.length,
                edgeCount: edges.length,
                findingCount: findings.length
            }
        });

    } catch (error) {
        console.error('Error converting findings to BloodHound format:', error);
        res.status(500).json({ error: error.message });
    }
});

// Helper function to convert findings to BloodHound nodes
function convertFindingsToNodes(findings) {
    const nodeMap = new Map();
    const domainSet = new Set();

    findings.forEach(finding => {
        try {
            const details = JSON.parse(finding.detailsJson || '{}');
            let dn = finding.distinguishedName || details.DistinguishedName || details.distinguishedname;
            let name = finding.name || details.Name || details.SamAccountName || details.samaccountname;

            // If no DN or name, create synthetic ones based on the finding
            if (!dn && !name) {
                name = `${finding.checkId}_Object_${finding.id}`;
                dn = `CN=${name},CN=Users,DC=domain,DC=local`;
            } else if (!dn && name) {
                dn = `CN=${name},CN=Users,DC=domain,DC=local`;
            } else if (dn && !name) {
                const cnMatch = dn.match(/CN=([^,]+)/i);
                name = cnMatch ? cnMatch[1] : `Object_${finding.id}`;
            }

            // Extract domain from DN
            const domain = extractDomainFromDN(dn);
            domainSet.add(domain);

            // Determine node type based on DN and finding
            const nodeType = determineNodeType(dn, finding, details);

            // Create unique node ID
            const nodeId = details.objectSid || `${name.toUpperCase()}@${domain}`;

            if (!nodeMap.has(nodeId)) {
                nodeMap.set(nodeId, {
                    ObjectIdentifier: nodeId,
                    Properties: {
                        name: `${name.toUpperCase()}@${domain}`,
                        domain: domain,
                        distinguishedname: dn,
                        samaccountname: name,
                        enabled: !details.disabled && details.enabled !== false,
                        isdeleted: false,
                        // Add finding-specific properties
                        adSuiteCheckId: finding.checkId,
                        adSuiteCheckName: finding.checkName,
                        adSuiteSeverity: finding.severity,
                        adSuiteCategory: finding.category,
                        adSuiteRiskScore: finding.riskScore,
                        adSuiteMitre: finding.mitre,
                        // Add details from finding
                        ...details
                    },
                    Labels: [nodeType],
                    Aces: [],
                    IsDeleted: false,
                    IsACLProtected: details.adminCount === 1 || details.AdminCount === 1 || finding.severity === 'CRITICAL'
                });
            } else {
                // Update existing node with additional finding info
                const existingNode = nodeMap.get(nodeId);
                if (finding.severity === 'CRITICAL' || finding.severity === 'HIGH') {
                    existingNode.Properties.adSuiteSeverity = finding.severity;
                    existingNode.Properties.adSuiteCheckId = finding.checkId;
                    existingNode.IsACLProtected = true;
                }
            }
        } catch (error) {
            console.error('Error processing finding:', error);
        }
    });

    // Add domain nodes
    const nodes = Array.from(nodeMap.values());
    domainSet.forEach(domain => {
        if (domain && domain !== 'UNKNOWN.LOCAL') {
            const domainDN = `DC=${domain.split('.').join(',DC=')}`;
            const domainId = `${domain.toUpperCase()}_DOMAIN`;

            nodes.push({
                ObjectIdentifier: domainId,
                Properties: {
                    name: domain.toUpperCase(),
                    domain: domain,
                    distinguishedname: domainDN,
                    samaccountname: domain.split('.')[0],
                    enabled: true,
                    isdeleted: false
                },
                Labels: ['Domain'],
                Aces: [],
                IsDeleted: false,
                IsACLProtected: false
            });
        }
    });

    return nodes;
}

// Helper function to generate relationships from findings
function generateRelationshipsFromFindings(findings, nodes) {
    const edges = [];
    const nodeMap = new Map(nodes.map(n => [n.Properties.distinguishedname, n]));

    findings.forEach(finding => {
        try {
            const details = JSON.parse(finding.detailsJson || '{}');

            // Generate relationships based on finding type
            if (finding.checkId.startsWith('ACC-') && details.memberOf) {
                // Group membership relationships
                const memberOf = Array.isArray(details.memberOf) ? details.memberOf : [details.memberOf];
                memberOf.forEach(groupDN => {
                    if (nodeMap.has(groupDN)) {
                        edges.push({
                            id: `${finding.distinguishedName}-${groupDN}`,
                            source: finding.distinguishedName,
                            target: groupDN,
                            label: 'MemberOf',
                            type: 'membership',
                            properties: {
                                checkId: finding.checkId,
                                severity: finding.severity
                            }
                        });
                    }
                });
            }

            if (finding.checkId.startsWith('AUTH-') && finding.severity === 'HIGH') {
                // Authentication vulnerabilities - create attack edges
                edges.push({
                    id: `attack-${finding.distinguishedName}`,
                    source: 'ATTACKER',
                    target: finding.distinguishedName,
                    label: getAttackLabel(finding.checkId),
                    type: 'attack',
                    properties: {
                        checkId: finding.checkId,
                        severity: finding.severity,
                        mitre: finding.mitre
                    }
                });
            }

            // Add more relationship types based on other findings...

        } catch (error) {
            console.error('Error generating relationships:', error);
        }
    });

    return edges;
}

// Helper functions
function extractDomainFromDN(dn) {
    const dcParts = dn.split(',').filter(part => part.trim().startsWith('DC='));
    return dcParts.map(part => part.replace('DC=', '').trim()).join('.').toUpperCase();
}

function determineNodeType(dn, finding, details) {
    if (dn.includes('CN=Computers') || details.objectClass === 'computer') return 'Computer';
    if (dn.includes('OU=Domain Controllers') || details.userAccountControl & 0x2000) return 'Computer';
    if (finding.category === 'Users_Accounts' || details.objectClass === 'user') return 'User';
    if (dn.includes('CN=Groups') || details.objectClass === 'group') return 'Group';
    return 'User'; // Default
}

function getAttackLabel(checkId) {
    const attackLabels = {
        'AUTH-001': 'ASREPRoast',
        'AUTH-002': 'Kerberoast',
        'AUTH-003': 'Password Spray',
        'ACC-001': 'Privilege Escalation',
        'ACC-002': 'Group Enumeration'
    };
    return attackLabels[checkId] || 'Exploit';
}

function generateADRelationships(nodes) {
    const edges = [];
    const nodeMap = new Map();

    // Create a map of nodes by their identifier for quick lookup
    nodes.forEach(node => {
        if (node.ObjectIdentifier) {
            nodeMap.set(node.ObjectIdentifier, node);
        }
    });

    nodes.forEach(node => {
        const props = node.Properties || {};
        const sourceId = node.ObjectIdentifier;

        // Generate MemberOf relationships from memberof property
        if (props.memberof && Array.isArray(props.memberof)) {
            props.memberof.forEach(groupDN => {
                // Try to find the group node by DN
                const groupNode = Array.from(nodeMap.values()).find(n =>
                    n.Properties?.distinguishedname === groupDN
                );

                if (groupNode) {
                    edges.push({
                        id: `${sourceId}-memberof-${groupNode.ObjectIdentifier}`,
                        source: sourceId,
                        target: groupNode.ObjectIdentifier,
                        label: 'MemberOf',
                        type: 'membership'
                    });
                }
            });
        }

        // Generate attack edges for high-severity findings
        if (props.adSuiteSeverity === 'CRITICAL' || props.adSuiteSeverity === 'HIGH') {
            // Create virtual attacker node
            const attackerId = 'ATTACKER_NODE';

            edges.push({
                id: `attack-${sourceId}`,
                source: attackerId,
                target: sourceId,
                label: getAttackLabel(props.adSuiteCheckId),
                type: 'attack'
            });
        }

        // Generate delegation relationships
        if (props.adSuiteCheckId && props.adSuiteCheckId.includes('Delegation')) {
            // Find domain node
            const domainNode = Array.from(nodeMap.values()).find(n =>
                n.Properties?.domain === props.domain &&
                (n.Labels?.includes('Domain') || n.Properties?.distinguishedname?.startsWith('DC='))
            );

            if (domainNode) {
                edges.push({
                    id: `${sourceId}-delegate-${domainNode.ObjectIdentifier}`,
                    source: sourceId,
                    target: domainNode.ObjectIdentifier,
                    label: 'AllowedToDelegate',
                    type: 'delegation'
                });
            }
        }
    });

    // Add virtual attacker node if we have attack edges
    const hasAttackEdges = edges.some(e => e.type === 'attack');
    if (hasAttackEdges) {
        // This will be handled by the frontend to add the attacker node
    }

    return edges;
}

// GET /api/bloodhound/demo - Generate demo BloodHound data for testing
router.get('/demo', (req, res) => {
    try {
        // Create sample BloodHound nodes representing typical AD objects
        const demoNodes = [
            {
                ObjectIdentifier: 'S-1-5-21-123456789-123456789-123456789-1001',
                Properties: {
                    name: 'ADMIN@CONTOSO.COM',
                    domain: 'CONTOSO.COM',
                    distinguishedname: 'CN=admin,CN=Users,DC=contoso,DC=com',
                    samaccountname: 'admin',
                    enabled: true,
                    isdeleted: false,
                    adSuiteCheckId: 'ACC-001',
                    adSuiteCheckName: 'Privileged Users (adminCount=1)',
                    adSuiteSeverity: 'HIGH',
                    adSuiteCategory: 'Access_Control',
                    admincount: 1
                },
                Labels: ['User'],
                Aces: [],
                IsDeleted: false,
                IsACLProtected: true
            },
            {
                ObjectIdentifier: 'S-1-5-21-123456789-123456789-123456789-512',
                Properties: {
                    name: 'DOMAIN ADMINS@CONTOSO.COM',
                    domain: 'CONTOSO.COM',
                    distinguishedname: 'CN=Domain Admins,CN=Users,DC=contoso,DC=com',
                    samaccountname: 'Domain Admins',
                    enabled: true,
                    isdeleted: false,
                    adSuiteCheckId: 'ACC-002',
                    adSuiteCheckName: 'Privileged Groups',
                    adSuiteSeverity: 'CRITICAL',
                    adSuiteCategory: 'Access_Control'
                },
                Labels: ['Group'],
                Aces: [],
                IsDeleted: false,
                IsACLProtected: true
            },
            {
                ObjectIdentifier: 'S-1-5-21-123456789-123456789-123456789-1000',
                Properties: {
                    name: 'DC01@CONTOSO.COM',
                    domain: 'CONTOSO.COM',
                    distinguishedname: 'CN=DC01,OU=Domain Controllers,DC=contoso,DC=com',
                    samaccountname: 'DC01$',
                    enabled: true,
                    isdeleted: false,
                    adSuiteCheckId: 'CMP-001',
                    adSuiteCheckName: 'Domain Controllers',
                    adSuiteSeverity: 'HIGH',
                    adSuiteCategory: 'Computers_Servers'
                },
                Labels: ['Computer'],
                Aces: [],
                IsDeleted: false,
                IsACLProtected: true
            },
            {
                ObjectIdentifier: 'S-1-5-21-123456789-123456789-123456789-2001',
                Properties: {
                    name: 'JDOE@CONTOSO.COM',
                    domain: 'CONTOSO.COM',
                    distinguishedname: 'CN=John Doe,CN=Users,DC=contoso,DC=com',
                    samaccountname: 'jdoe',
                    enabled: true,
                    isdeleted: false,
                    adSuiteCheckId: 'AUTH-001',
                    adSuiteCheckName: 'Kerberoastable Users',
                    adSuiteSeverity: 'MEDIUM',
                    adSuiteCategory: 'Authentication',
                    serviceprincipalnames: ['HTTP/webapp.contoso.com']
                },
                Labels: ['User'],
                Aces: [],
                IsDeleted: false,
                IsACLProtected: false
            },
            {
                ObjectIdentifier: 'CONTOSO_DOMAIN',
                Properties: {
                    name: 'CONTOSO.COM',
                    domain: 'CONTOSO.COM',
                    distinguishedname: 'DC=contoso,DC=com',
                    samaccountname: 'contoso',
                    enabled: true,
                    isdeleted: false
                },
                Labels: ['Domain'],
                Aces: [],
                IsDeleted: false,
                IsACLProtected: false
            }
        ];

        // Generate relationships
        const demoEdges = [
            {
                id: 'admin-memberof-domainadmins',
                source: 'S-1-5-21-123456789-123456789-123456789-1001',
                target: 'S-1-5-21-123456789-123456789-123456789-512',
                label: 'MemberOf',
                type: 'membership'
            },
            {
                id: 'attack-admin',
                source: 'ATTACKER_NODE',
                target: 'S-1-5-21-123456789-123456789-123456789-1001',
                label: 'Privilege Escalation',
                type: 'attack'
            },
            {
                id: 'attack-jdoe',
                source: 'ATTACKER_NODE',
                target: 'S-1-5-21-123456789-123456789-123456789-2001',
                label: 'Kerberoast',
                type: 'attack'
            }
        ];

        // Add attacker node
        demoNodes.push({
            ObjectIdentifier: 'ATTACKER_NODE',
            Properties: {
                name: 'ATTACKER',
                domain: 'EXTERNAL',
                distinguishedname: 'CN=ATTACKER,CN=EXTERNAL',
                samaccountname: 'ATTACKER',
                enabled: true,
                isdeleted: false
            },
            Labels: ['ATTACKER'],
            Aces: [],
            IsDeleted: false,
            IsACLProtected: false
        });

        res.json({
            nodes: demoNodes,
            edges: demoEdges,
            meta: {
                scanId: 'demo',
                nodeCount: demoNodes.length,
                edgeCount: demoEdges.length,
                timestamp: new Date().toISOString(),
                source: 'demo_data'
            }
        });

    } catch (error) {
        console.error('Error generating demo BloodHound data:', error);
        res.status(500).json({ error: error.message });
    }
});

module.exports = router;