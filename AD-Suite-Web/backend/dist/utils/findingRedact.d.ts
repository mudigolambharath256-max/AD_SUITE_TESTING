/** Redact sensitive patterns in finding strings before sending to external LLMs. */
/**
 * Deep-clone plain objects and redact all string values (arrays recurse).
 */
export declare function redactFindingFields<T>(value: T, depth?: number): T;
//# sourceMappingURL=findingRedact.d.ts.map