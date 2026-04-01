export type TokenType = 'user' | 'computer' | 'group' | 'template' | 'gpo' | 'ou' | 'ca' | 'spn' | 'other';

export interface TokenEntry {
    token: string;
    real: string;
    type: TokenType;
}

export interface TokenMaps {
    tokenToEntry: Record<string, TokenEntry>;
    realToToken: Record<string, string>;
}

const EMAIL_RE = /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b/g;
const LONG_HEX_RE = /\b[A-Fa-f0-9]{32,}\b/g;
const LONG_B64_RE = /\b[A-Za-z0-9+/]{40,}={0,2}\b/g;
const MAX_STRING_LEN = 800;

export function redactString(s: string): string {
    let out = s;
    out = out.replace(EMAIL_RE, '[email]');
    out = out.replace(LONG_HEX_RE, '[hex]');
    out = out.replace(LONG_B64_RE, '[blob]');
    if (out.length > MAX_STRING_LEN) out = `${out.slice(0, MAX_STRING_LEN)}…`;
    return out;
}

export function deepRedact<T>(value: T, depth = 0): T {
    if (depth > 12) return value;
    if (value === null || value === undefined) return value;
    if (typeof value === 'string') return redactString(value) as T;
    if (Array.isArray(value)) return value.map((v) => deepRedact(v, depth + 1)) as T;
    if (typeof value === 'object') {
        const o = value as Record<string, unknown>;
        const next: Record<string, unknown> = {};
        for (const k of Object.keys(o)) next[k] = deepRedact(o[k], depth + 1);
        return next as T;
    }
    return value;
}

const ENTITY_KEYS: Array<{ key: string; type: TokenType }> = [
    { key: 'SamAccountName', type: 'user' },
    { key: 'samAccountName', type: 'user' },
    { key: 'Account', type: 'user' },
    { key: 'account', type: 'user' },
    { key: 'Principal', type: 'user' },
    { key: 'principal', type: 'user' },
    { key: 'Trustee', type: 'group' },
    { key: 'trustee', type: 'group' },
    { key: 'Group', type: 'group' },
    { key: 'group', type: 'group' },
    { key: 'Computer', type: 'computer' },
    { key: 'computer', type: 'computer' },
    { key: 'TargetComputer', type: 'computer' },
    { key: 'targetComputer', type: 'computer' },
    { key: 'Template', type: 'template' },
    { key: 'template', type: 'template' },
    { key: 'CaName', type: 'ca' },
    { key: 'caName', type: 'ca' },
    { key: 'ServicePrincipalName', type: 'spn' },
    { key: 'servicePrincipalName', type: 'spn' },
    { key: 'GpoName', type: 'gpo' },
    { key: 'gpoName', type: 'gpo' },
    { key: 'LinkedOu', type: 'ou' },
    { key: 'linkedOu', type: 'ou' },
    { key: 'DistinguishedName', type: 'ou' },
    { key: 'distinguishedName', type: 'ou' }
];

function normalizeReal(v: unknown): string | null {
    if (v === null || v === undefined) return null;
    const s = String(v).trim();
    if (!s) return null;
    if (s.length > 140) return s.slice(0, 140) + '…';
    return s;
}

function prefixForType(t: TokenType): string {
    switch (t) {
        case 'user':
            return 'U';
        case 'computer':
            return 'C';
        case 'group':
            return 'G';
        case 'template':
            return 'T';
        case 'gpo':
            return 'GPO';
        case 'ou':
            return 'OU';
        case 'ca':
            return 'CA';
        case 'spn':
            return 'SPN';
        default:
            return 'X';
    }
}

function nextToken(prefix: string, index: number): string {
    const pad = String(index).padStart(3, '0');
    return `${prefix}${pad}`;
}

export function buildTokenMaps(findings: Array<Record<string, unknown>>): TokenMaps {
    const tokenToEntry: Record<string, TokenEntry> = {};
    const realToToken: Record<string, string> = {};

    const counters: Record<string, number> = {};
    function allocate(type: TokenType, real: string): string {
        if (realToToken[real]) return realToToken[real];
        const p = prefixForType(type);
        counters[p] = (counters[p] || 0) + 1;
        const tok = nextToken(p, counters[p]);
        tokenToEntry[tok] = { token: tok, real, type };
        realToToken[real] = tok;
        return tok;
    }

    for (const f of findings) {
        for (const { key, type } of ENTITY_KEYS) {
            if (Object.prototype.hasOwnProperty.call(f, key)) {
                const real = normalizeReal((f as any)[key]);
                if (real) allocate(type, real);
            }
        }
    }

    return { tokenToEntry, realToToken };
}

export function tokenizeText(text: string, maps: TokenMaps): string {
    let out = text;
    // Replace longest strings first to avoid partial replacement issues.
    const reals = Object.keys(maps.realToToken).sort((a, b) => b.length - a.length);
    for (const real of reals) {
        const tok = maps.realToToken[real];
        // Simple global replace (inputs are controlled finding strings).
        out = out.split(real).join(tok);
    }
    return out;
}

export function tokenizeFinding<T extends Record<string, unknown>>(finding: T, maps: TokenMaps): T {
    const next: Record<string, unknown> = {};
    for (const [k, v] of Object.entries(finding)) {
        if (typeof v === 'string') {
            next[k] = tokenizeText(v, maps);
        } else if (Array.isArray(v)) {
            next[k] = v.map((x) => (typeof x === 'string' ? tokenizeText(x, maps) : x));
        } else {
            next[k] = v;
        }
    }
    // Also tokenize known entity keys even if they were not strings originally.
    for (const { key, type } of ENTITY_KEYS) {
        if (Object.prototype.hasOwnProperty.call(finding, key)) {
            const real = normalizeReal((finding as any)[key]);
            if (real) {
                const tok = maps.realToToken[real] || (() => {
                    const p = prefixForType(type);
                    return (maps.realToToken[real] = nextToken(p, 999));
                })();
                next[key] = tok;
            }
        }
    }
    return next as T;
}

export function detokenizeText(text: string, maps: TokenMaps): string {
    let out = text;
    const tokens = Object.keys(maps.tokenToEntry).sort((a, b) => b.length - a.length);
    for (const tok of tokens) {
        out = out.split(tok).join(maps.tokenToEntry[tok].real);
    }
    return out;
}

export function sanitizeForMermaidLabel(real: string): string {
    // Prompt rules disallow parentheses, colons, slashes; we also remove backslashes.
    const cleaned = real
        .replace(/[\\/:()]/g, ' ')
        .replace(/\s+/g, ' ')
        .trim();
    // Avoid very long labels.
    return cleaned.length > 40 ? cleaned.slice(0, 40) + '…' : cleaned;
}

/**
 * Replace entity tokens with real names for display. Only mutates text inside
 * square-bracket node labels and edge labels (-->|...|). Longest tokens first.
 */
export function detokenizeMermaidChart(chart: string, maps: TokenMaps): string {
    const tokens = Object.keys(maps.tokenToEntry).sort((a, b) => b.length - a.length);

    function replaceTokensInText(s: string): string {
        let out = s;
        for (const tok of tokens) {
            if (out.includes(tok)) {
                out = out.split(tok).join(maps.tokenToEntry[tok].real);
            }
        }
        return sanitizeForMermaidLabel(out);
    }

    let out = chart;
    // Node shapes: A1["label"] or A1[label]
    out = out.replace(/(\w+)\[(\"[^\"]*\"|[^\]]+)\]/g, (_m, id: string, rawLabel: string) => {
        const inner =
            rawLabel.startsWith('"') && rawLabel.endsWith('"')
                ? rawLabel.slice(1, -1)
                : rawLabel;
        const safe = replaceTokensInText(inner);
        return `${id}["${safe.replace(/"/g, '')}"]`;
    });
    // Edge labels: -->|label|
    out = out.replace(/-->\|([^|]+)\|/g, (_m, label: string) => {
        return `-->|${replaceTokensInText(label)}|`;
    });
    // Subgraph titles: subgraph Chain1[title]
    out = out.replace(/subgraph\s+(\w+)\s*\[([^\]]*)\]/gi, (_m, id: string, title: string) => {
        return `subgraph ${id}[${replaceTokensInText(title)}]`;
    });

    return out;
}

export function tokenMapEntries(maps: TokenMaps): TokenEntry[] {
    return Object.values(maps.tokenToEntry).sort((a, b) => a.token.localeCompare(b.token));
}

