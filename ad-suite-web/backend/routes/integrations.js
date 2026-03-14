const express = require('express');
const router = express.Router();
const neo4j = require('neo4j-driver');
const axios = require('axios');
const bloodhound = require('../services/bloodhound');
const db = require('../services/db');

// BloodHound integration
router.get('/bloodhound/test', async (req, res) => {
  try {
    const config = {
      url: req.query.url || 'http://localhost:8080',
      username: req.query.username || 'neo4j',
      password: req.query.password,
      version: req.query.version || 'CE'
    };

    const result = await bloodhound.testConnection(config);
    res.json(result);
  } catch (error) {
    console.error('BloodHound test error:', error);
    res.status(500).json({ error: error.message });
  }
});

router.post('/bloodhound/push', async (req, res) => {
  try {
    const { scanId, config } = req.body;
    
    if (!scanId) {
      return res.status(400).json({ error: 'Missing scanId' });
    }

    const findings = db.getFindings(scanId, 1, 10000);
    if (findings.length === 0) {
      return res.status(404).json({ error: 'No findings found for scan' });
    }

    const result = await bloodhound.pushFindings(findings, config);
    res.json(result);
  } catch (error) {
    console.error('BloodHound push error:', error);
    res.status(500).json({ error: error.message });
  }
});

// Neo4j Direct integration
router.get('/neo4j/test', async (req, res) => {
  try {
    const { boltUri = 'bolt://localhost:7687', username = 'neo4j', password, database = 'neo4j' } = req.query;
    
    if (!password) {
      return res.status(400).json({ connected: false, error: 'Password required' });
    }

    const driver = neo4j.driver(boltUri, neo4j.auth.basic(username, password));
    const session = driver.session({ database });
    
    try {
      const result = await session.run('RETURN 1 as test');
      await session.close();
      await driver.close();
      
      res.json({ connected: true });
    } catch (sessionError) {
      await session.close();
      await driver.close();
      res.json({ connected: false, error: sessionError.message });
    }
  } catch (error) {
    console.error('Neo4j test error:', error);
    res.status(500).json({ connected: false, error: error.message });
  }
});

router.post('/neo4j/push', async (req, res) => {
  try {
    const { scanId, config } = req.body;
    
    if (!scanId) {
      return res.status(400).json({ error: 'Missing scanId' });
    }

    const { boltUri = 'bolt://localhost:7687', username = 'neo4j', password, database = 'neo4j' } = config;
    
    if (!password) {
      return res.status(400).json({ error: 'Password required' });
    }

    const findings = db.getFindings(scanId, 1, 10000);
    if (findings.length === 0) {
      return res.status(404).json({ error: 'No findings found for scan' });
    }

    const driver = neo4j.driver(boltUri, neo4j.auth.basic(username, password));
    const session = driver.session({ database });
    
    let nodesCreated = 0;
    let relationshipsCreated = 0;

    try {
      for (const finding of findings) {
        // Create finding node
        await session.run(`
          MERGE (f:ADFinding { checkId: $checkId })
          SET f += { 
            checkName: $checkName, 
            severity: $severity, 
            mitre: $mitre,
            name: $name, 
            dn: $dn, 
            scanDate: $scanDate,
            riskScore: $riskScore,
            category: $category
          }
        `, {
          checkId: finding.check_id,
          checkName: finding.check_name,
          severity: finding.severity,
          mitre: finding.mitre,
          name: finding.name,
          dn: finding.distinguished_name,
          scanDate: new Date(finding.created_at).toISOString(),
          riskScore: finding.risk_score,
          category: finding.category
        });

        nodesCreated++;

        // Create category node and relationship
        await session.run(`
          MERGE (c:Category { name: $category })
          MERGE (f:ADFinding { checkId: $checkId })
          MERGE (f)-[:BELONGS_TO]->(c)
        `, {
          category: finding.category,
          checkId: finding.check_id
        });

        relationshipsCreated++;

        // Create MITRE technique node and relationship if applicable
        if (finding.mitre) {
          await session.run(`
            MERGE (t:MITRETechnique { id: $mitre })
            MERGE (f:ADFinding { checkId: $checkId })
            MERGE (f)-[:MAPS_TO]->(t)
          `, {
            mitre: finding.mitre,
            checkId: finding.check_id
          });

          nodesCreated++;
          relationshipsCreated++;
        }
      }

      await session.close();
      await driver.close();

      res.json({ 
        nodesCreated, 
        relationshipsCreated,
        totalFindings: findings.length
      });
    } catch (sessionError) {
      await session.close();
      await driver.close();
      throw sessionError;
    }
  } catch (error) {
    console.error('Neo4j push error:', error);
    res.status(500).json({ error: error.message });
  }
});

// MCP Server integration
router.get('/mcp/test', async (req, res) => {
  try {
    const { serverUrl, apiKey, workspaceId } = req.query;
    
    if (!serverUrl || !apiKey || !workspaceId) {
      return res.status(400).json({ connected: false, error: 'Missing required parameters' });
    }

    const response = await axios.get(`${serverUrl}/health`, {
      headers: {
        'Authorization': `Bearer ${apiKey}`
      },
      timeout: 10000
    });

    res.json({ connected: true, serverInfo: response.data });
  } catch (error) {
    console.error('MCP test error:', error);
    res.json({ 
      connected: false, 
      error: error.response?.data?.message || error.message 
    });
  }
});

router.post('/mcp/push', async (req, res) => {
  try {
    const { scanId, config } = req.body;
    
    if (!scanId) {
      return res.status(400).json({ error: 'Missing scanId' });
    }

    const { serverUrl, apiKey, workspaceId } = config;
    
    if (!serverUrl || !apiKey || !workspaceId) {
      return res.status(400).json({ error: 'Missing required MCP configuration' });
    }

    const findings = db.getFindings(scanId, 1, 10000);
    if (findings.length === 0) {
      return res.status(404).json({ error: 'No findings found for scan' });
    }

    const payload = {
      workspace: workspaceId,
      source: "AD-Security-Suite",
      findings: findings.map(f => ({
        checkId: f.check_id,
        checkName: f.check_name,
        category: f.category,
        severity: f.severity,
        riskScore: f.risk_score,
        mitre: f.mitre,
        name: f.name,
        distinguishedName: f.distinguished_name,
        details: JSON.parse(f.details_json || '{}'),
        createdAt: f.created_at
      }))
    };

    const response = await axios.post(`${serverUrl}/findings`, payload, {
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json'
      },
      timeout: 30000
    });

    res.json({ 
      pushed: true, 
      count: findings.length,
      response: response.data 
    });
  } catch (error) {
    console.error('MCP push error:', error);
    res.status(500).json({ 
      pushed: false, 
      error: error.response?.data?.message || error.message 
    });
  }
});

module.exports = router;
