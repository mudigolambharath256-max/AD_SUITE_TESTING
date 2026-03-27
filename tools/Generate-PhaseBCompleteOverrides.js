const path = require('path');
const { generateOverrides } = require('./phaseBOverrideHelpers');

const root = path.join(__dirname, '..');
const outPath = path.join(root, 'checks.overrides.phaseB-complete.json');

const n = generateOverrides({
  root,
  outPath,
  categories: null,
  metaExtra: {
    phase: 'B-complete',
    waves: 'B1 through B11 — all categories except Certificate_Services and Azure_AD_Integration',
  },
});
console.log('Wrote', outPath, 'with', n, 'overrides');
