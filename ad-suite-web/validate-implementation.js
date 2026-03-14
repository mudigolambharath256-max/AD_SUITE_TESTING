#!/usr/bin/env node

/**
 * Validation script for Graph Features implementation
 * Run with: node validate-implementation.js
 */

const fs = require('fs');
const path = require('path');

const checks = [];
let passed = 0;
let failed = 0;

function check(name, condition, details = '') {
    const result = condition();
    checks.push({ name, passed: result, details });
    if (result) {
        passed++;
        console.log(`✓ ${name}`);
    } else {
        failed++;
        console.log(`✗ ${name}`);
        if (details) console.log(`  ${details}`);
    }
}

console.log('\n=== Graph Features Implementation Validation ===\n');

// Backend files
console.log('Backend Files:');
check(
    'PowerShell parser script exists',
    () => fs.existsSync('backend/scripts/Parse-ADExplorerSnapshot.ps1')
);
check(
    'ADExplorer route exists',
    () => fs.existsSync('backend/routes/adexplorer.js')
);
check(
    'ADExplorer route is valid JavaScript',
    () => {
        try {
            require('./backend/routes/adexplorer.js');
            return true;
        } catch (e) {
            return false;
        }
    }
);

// Frontend files
console.log('\nFrontend Files:');
check(
    'AdGraphVisualiser component exists',
    () => fs.existsSync('frontend/src/components/AdGraphVisualiser.jsx')
);
check(
    'AdExplorerSection component exists',
    () => fs.existsSync('frontend/src/components/AdExplorerSection.jsx')
);

// Modified files
console.log('\nModified Files:');
check(
    'server.js has adexplorer route import',
    () => {
        const content = fs.readFileSync('backend/server.js', 'utf8');
        return content.includes("require('./routes/adexplorer')");
    }
);
check(
    'server.js has adexplorer route registration',
    () => {
        const content = fs.readFileSync('backend/server.js', 'utf8');
        return content.includes("app.use('/api/integrations/adexplorer'");
    }
);
check(
    'server.js has graph-data endpoint',
    () => {
        const content = fs.readFileSync('backend/server.js', 'utf8');
        return content.includes("app.get('/api/reports/graph-data/:scanId'");
    }
);
check(
    'Integrations.jsx imports AdGraphVisualiser',
    () => {
        const content = fs.readFileSync('frontend/src/pages/Integrations.jsx', 'utf8');
        return content.includes("import { AdGraphVisualiser }");
    }
);
check(
    'Integrations.jsx imports AdExplorerSection',
    () => {
        const content = fs.readFileSync('frontend/src/pages/Integrations.jsx', 'utf8');
        return content.includes("import { AdExplorerSection }");
    }
);
check(
    'Integrations.jsx uses AdExplorerSection',
    () => {
        const content = fs.readFileSync('frontend/src/pages/Integrations.jsx', 'utf8');
        return content.includes("<AdExplorerSection");
    }
);
check(
    'Integrations.jsx uses AdGraphVisualiser',
    () => {
        const content = fs.readFileSync('frontend/src/pages/Integrations.jsx', 'utf8');
        return content.includes("<AdGraphVisualiser");
    }
);
check(
    'Integrations.jsx has graphSessionId state',
    () => {
        const content = fs.readFileSync('frontend/src/pages/Integrations.jsx', 'utf8');
        return content.includes("graphSessionId");
    }
);

// Dependencies
console.log('\nDependencies:');
check(
    'cytoscape package installed',
    () => fs.existsSync('frontend/node_modules/cytoscape')
);
check(
    'cytoscape can be required',
    () => {
        try {
            const cytoscape = require('./frontend/node_modules/cytoscape');
            return typeof cytoscape === 'function';
        } catch (e) {
            return false;
        }
    }
);

// Directories
console.log('\nDirectories:');
check(
    'uploads/adexplorer directory exists',
    () => fs.existsSync('uploads/adexplorer')
);

// Component structure validation
console.log('\nComponent Structure:');
check(
    'AdGraphVisualiser exports component',
    () => {
        const content = fs.readFileSync('frontend/src/components/AdGraphVisualiser.jsx', 'utf8');
        return content.includes('export function AdGraphVisualiser');
    }
);
check(
    'AdGraphVisualiser uses cytoscape',
    () => {
        const content = fs.readFileSync('frontend/src/components/AdGraphVisualiser.jsx', 'utf8');
        return content.includes("import cytoscape from 'cytoscape'");
    }
);
check(
    'AdExplorerSection exports component',
    () => {
        const content = fs.readFileSync('frontend/src/components/AdExplorerSection.jsx', 'utf8');
        return content.includes('export function AdExplorerSection');
    }
);
check(
    'AdExplorerSection has onOpenInGraph prop',
    () => {
        const content = fs.readFileSync('frontend/src/components/AdExplorerSection.jsx', 'utf8');
        return content.includes('onOpenInGraph');
    }
);

// PowerShell script validation
console.log('\nPowerShell Script:');
check(
    'PowerShell script has required parameters',
    () => {
        const content = fs.readFileSync('backend/scripts/Parse-ADExplorerSnapshot.ps1', 'utf8');
        return content.includes('param(') &&
            content.includes('$SnapshotPath') &&
            content.includes('$OutputDir');
    }
);
check(
    'PowerShell script has Track 1 (convertsnapshot.exe)',
    () => {
        const content = fs.readFileSync('backend/scripts/Parse-ADExplorerSnapshot.ps1', 'utf8');
        return content.includes('TRACK 1') && content.includes('convertsnapshot.exe');
    }
);
check(
    'PowerShell script has Track 2 (PowerShell parser)',
    () => {
        const content = fs.readFileSync('backend/scripts/Parse-ADExplorerSnapshot.ps1', 'utf8');
        return content.includes('TRACK 2') && content.includes('BinaryReader');
    }
);
check(
    'PowerShell script outputs graph.json',
    () => {
        const content = fs.readFileSync('backend/scripts/Parse-ADExplorerSnapshot.ps1', 'utf8');
        return content.includes('graph.json');
    }
);

// Route validation
console.log('\nRoute Endpoints:');
check(
    'ADExplorer route has POST /convert',
    () => {
        const content = fs.readFileSync('backend/routes/adexplorer.js', 'utf8');
        return content.includes("router.post('/convert'");
    }
);
check(
    'ADExplorer route has GET /stream/:sessionId',
    () => {
        const content = fs.readFileSync('backend/routes/adexplorer.js', 'utf8');
        return content.includes("router.get('/stream/:sessionId'");
    }
);
check(
    'ADExplorer route has GET /graph/:sessionId',
    () => {
        const content = fs.readFileSync('backend/routes/adexplorer.js', 'utf8');
        return content.includes("router.get('/graph/:sessionId'");
    }
);
check(
    'ADExplorer route has GET /download/:sessionId/:filename',
    () => {
        const content = fs.readFileSync('backend/routes/adexplorer.js', 'utf8');
        return content.includes("router.get('/download/:sessionId/:filename'");
    }
);
check(
    'ADExplorer route uses SSE',
    () => {
        const content = fs.readFileSync('backend/routes/adexplorer.js', 'utf8');
        return content.includes('text/event-stream');
    }
);

// Summary
console.log('\n=== Summary ===');
console.log(`Passed: ${passed}/${checks.length}`);
console.log(`Failed: ${failed}/${checks.length}`);

if (failed === 0) {
    console.log('\n✓ All validation checks passed!');
    console.log('The implementation is complete and ready for testing.');
    console.log('\nNext steps:');
    console.log('1. Run: npm run dev');
    console.log('2. Navigate to: http://localhost:5173');
    console.log('3. Go to Integrations page');
    console.log('4. Scroll to bottom to see new features');
    console.log('5. Follow TESTING_GRAPH_FEATURES.md for detailed testing');
    process.exit(0);
} else {
    console.log('\n✗ Some validation checks failed.');
    console.log('Please review the failed checks above and fix any issues.');
    process.exit(1);
}
