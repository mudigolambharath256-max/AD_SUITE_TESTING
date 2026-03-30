export interface RawFindingInput {
    CheckId?: string;
    CheckName?: string;
    Severity?: string;
    severity?: string;
    Category?: string;
    category?: string;
    Description?: string;
    Name?: string;
    Impact?: string;
    RiskData?: string;
    Message?: string;
    [key: string]: unknown;
}
export interface NormalizedFinding {
    CheckId: string;
    CheckName: string;
    Severity: string;
    Category: string;
    Description: string;
    Impact: string;
}
export declare function severityRank(s: string): number;
/** Tiered structure sent to the LLM. */
export interface AttackPathTieredPayload {
    summary: {
        totalFindings: number;
        bySeverity: Record<string, number>;
        byCategory: Record<string, number>;
        topChecksByVolume: {
            checkId: string;
            count: number;
        }[];
    };
    groupedFindings: Array<{
        groupKey: string;
        checkId: string;
        checkName: string;
        severity: string;
        category: string;
        occurrenceCount: number;
        samples: NormalizedFinding[];
    }>;
}
export interface BuildPayloadResult {
    payload: AttackPathTieredPayload;
    userPromptJson: string;
    stats: {
        rawInputCount: number;
        distinctGroups: number;
        groupsCollapsed: number;
        payloadRows: number;
        approxChars: number;
        truncatedToBudget: boolean;
    };
}
declare const DEFAULT_OPTS: {
    maxGroups: number;
    maxSamplesPerGroup: number;
    highVolumeThreshold: number;
    maxChars: number;
};
export declare function buildAttackPathPayload(rawFindings: RawFindingInput[], opts?: Partial<typeof DEFAULT_OPTS>): BuildPayloadResult;
export {};
//# sourceMappingURL=attackPathPayload.d.ts.map