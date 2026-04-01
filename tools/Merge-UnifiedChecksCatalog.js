'use strict';
/**
 * Single catalog: checks.generated.json + checks.overrides.phaseB-complete.json,
 * then overlay checks.json, then optional checks.catalog-additions.json (last wins on id).
 *
 * Usage: node tools/Merge-UnifiedChecksCatalog.js
 * Output: checks.unified.json (repo root)
 */
const fs = require('fs');
const path = require('path');

const root = path.join(__dirname, '..');

function readJson(p) {
    return JSON.parse(fs.readFileSync(p, 'utf8').replace(/^\uFEFF/, ''));
}

function mergePatches(baseDoc, overridesDoc) {
    if (!overridesDoc?.checks?.length) {
        return baseDoc;
    }
    const byId = new Map();
    for (const c of baseDoc.checks) {
        if (c?.id != null) {
            byId.set(String(c.id), c);
        }
    }
    for (const ov of overridesDoc.checks) {
        if (ov?.id == null) {
            continue;
        }
        const row = byId.get(String(ov.id));
        if (!row) {
            continue;
        }
        for (const [k, v] of Object.entries(ov)) {
            if (k === 'id') {
                continue;
            }
            row[k] = v;
        }
    }
    return baseDoc;
}

function main() {
    const genPath = path.join(root, 'checks.generated.json');
    const phaseBPath = path.join(root, 'checks.overrides.phaseB-complete.json');
    const curatedPath = path.join(root, 'checks.json');
    const additionsPath = path.join(root, 'checks.catalog-additions.json');
    const outPath = path.join(root, 'checks.unified.json');

    for (const p of [genPath, phaseBPath, curatedPath]) {
        if (!fs.existsSync(p)) {
            console.error('Missing required file:', p);
            process.exit(1);
        }
    }

    const generated = readJson(genPath);
    const phaseB = readJson(phaseBPath);
    const curated = readJson(curatedPath);

    if (!Array.isArray(generated.checks) || !Array.isArray(curated.checks)) {
        console.error('Invalid catalog: expected checks arrays');
        process.exit(1);
    }

    const base = JSON.parse(JSON.stringify(generated));
    mergePatches(base, phaseB);

    const byId = new Map();
    for (const c of base.checks) {
        if (c?.id != null) {
            byId.set(String(c.id), c);
        }
    }

    let curatedReplaced = 0;
    let curatedAdded = 0;
    for (const c of curated.checks) {
        if (c?.id == null) {
            continue;
        }
        const id = String(c.id);
        const copy = JSON.parse(JSON.stringify(c));
        if (byId.has(id)) {
            curatedReplaced++;
        } else {
            curatedAdded++;
        }
        byId.set(id, copy);
    }

    let additionsReplaced = 0;
    let additionsAdded = 0;
    if (fs.existsSync(additionsPath)) {
        const addDoc = readJson(additionsPath);
        if (Array.isArray(addDoc.checks)) {
            for (const c of addDoc.checks) {
                if (c?.id == null) {
                    continue;
                }
                const id = String(c.id);
                const copy = JSON.parse(JSON.stringify(c));
                if (byId.has(id)) {
                    additionsReplaced++;
                } else {
                    additionsAdded++;
                }
                byId.set(id, copy);
            }
        }
    }

    const checks = Array.from(byId.values()).sort((a, b) =>
        String(a.id).localeCompare(String(b.id), undefined, { numeric: true, sensitivity: 'base' })
    );

    const out = {
        schemaVersion: curated.schemaVersion ?? base.schemaVersion ?? 1,
        meta: {
            ...(typeof curated.meta === 'object' && curated.meta ? curated.meta : {}),
            unifiedCatalog: true,
            unifiedMerge: {
                baseCatalog: 'checks.generated.json',
                promotions: 'checks.overrides.phaseB-complete.json',
                curatedPack: 'checks.json',
                checksAfterPhaseB: base.checks.length,
                checksInCurated: curated.checks.length,
                curatedReplacedExisting: curatedReplaced,
                curatedAddedOnly: curatedAdded,
                catalogAdditionsFile: fs.existsSync(additionsPath) ? 'checks.catalog-additions.json' : null,
                catalogAdditionsReplaced: additionsReplaced,
                catalogAdditionsAdded: additionsAdded,
                totalChecks: checks.length,
                mergedAtUtc: new Date().toISOString()
            }
        },
        defaults: curated.defaults != null ? curated.defaults : base.defaults,
        checks
    };

    fs.writeFileSync(outPath, JSON.stringify(out, null, 4) + '\n', 'utf8');
    console.log('Wrote', outPath);
    console.log('  checks after Phase B:', base.checks.length);
    console.log('  curated overlay:', curated.checks.length, '(replaced', curatedReplaced + ', added', curatedAdded + ')');
    if (fs.existsSync(additionsPath)) {
        const addDoc = readJson(additionsPath);
        const n = Array.isArray(addDoc.checks) ? addDoc.checks.length : 0;
        console.log('  catalog additions:', n, '(replaced', additionsReplaced + ', added', additionsAdded + ')');
    }
    console.log('  total unified:', checks.length);
}

main();
