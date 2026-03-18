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

        if (!fs.existsSync(bloodhoundDir)) {
            return res.json({
                nodes: [],
                edges: [],
                message: 'No BloodHound data available for this scan'
            });
        }

        // Read all BloodHound JSON files
        const jsonFiles = fs.readdirSync(bloodhoundDir)
            .filter(file => file.endsWith('.json'));

        let allNodes = [];
        let allEdges = [];

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

        // Generate edges based on AD relationships
        const edges = generateADRelationships(allNodes);

        res.json({
            nodes: allNodes,
            edges: edges,
            meta: {
                scanId,
                nodeCount: allNodes.length,
                edgeCount: edges.length,
                timestamp: scan.timestamp
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

    findings.forEach(finding => {
        try {
            const details = JSON.parse(finding.detailsJson || '{}');
            const dn = finding.distinguishedName;

            if (!dn) return;

            // Extract domain from DN
            const domain = extractDomainFromDN(dn);

            // Determine node type based on DN and finding
            const nodeType = determineNodeType(dn, finding, details);

            // Create unique node ID
            const nodeId = finding.name ? `${finding.name.toUpperCase()}@${domain}` : dn;

            if (!nodeMap.has(nodeId)) {
                nodeMap.set(nodeId, {
                    ObjectIdentifier: details.objectSid || dn,
                    Properties: {
                        name: nodeId,
                        domain: domain,
                        distinguishedname: dn,
                        samaccountname: finding.name,
                        enabled: !details.disabled,
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
                    IsACLProtected: false
                });
            }
        } catch (error) {
            console.error('Error processing finding:', error);
        }
    });

    return Array.from(nodeMap.values());
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
    // This would generate edges based on AD relationships
    // For now, return empty array - we'll use findings-based relationships
    return [];
}

module.exports = router;