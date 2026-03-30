"use strict";
/** Redact sensitive patterns in finding strings before sending to external LLMs. */
Object.defineProperty(exports, "__esModule", { value: true });
exports.redactFindingFields = redactFindingFields;
const MAX_STRING_LEN = 800;
const EMAIL_RE = /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b/g;
const LONG_HEX_RE = /\b[A-Fa-f0-9]{32,}\b/g;
const LONG_B64_RE = /\b[A-Za-z0-9+/]{40,}={0,2}\b/g;
function redactString(s) {
    let out = s;
    out = out.replace(EMAIL_RE, '[email]');
    out = out.replace(LONG_HEX_RE, '[hex]');
    out = out.replace(LONG_B64_RE, '[blob]');
    if (out.length > MAX_STRING_LEN) {
        out = `${out.slice(0, MAX_STRING_LEN)}…`;
    }
    return out;
}
/**
 * Deep-clone plain objects and redact all string values (arrays recurse).
 */
function redactFindingFields(value, depth = 0) {
    if (depth > 12)
        return value;
    if (value === null || value === undefined)
        return value;
    if (typeof value === 'string') {
        return redactString(value);
    }
    if (Array.isArray(value)) {
        return value.map((v) => redactFindingFields(v, depth + 1));
    }
    if (typeof value === 'object') {
        const o = value;
        const next = {};
        for (const k of Object.keys(o)) {
            next[k] = redactFindingFields(o[k], depth + 1);
        }
        return next;
    }
    return value;
}
//# sourceMappingURL=findingRedact.js.map