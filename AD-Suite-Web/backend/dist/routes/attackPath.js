"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const auth_1 = require("../middleware/auth");
const auditMiddleware_1 = require("../middleware/auditMiddleware");
const logger_1 = require("../utils/logger");
const attackPathPayload_1 = require("../utils/attackPathPayload");
const router = express_1.default.Router();
router.use(auth_1.authenticate);
router.use(auditMiddleware_1.auditMutations);
const GRAPH_SUMMARY_MAX_CHARS = 24000;
const SYSTEM_PROMPT = `You are an expert Active Directory penetration tester and security architect.
You will receive deduplicated findings from an automated AD security assessment.

### YOUR MISSION
Produce a structured attack path analysis with these outputs:
1. EXECUTIVE SUMMARY — 2-3 sentences. Overall risk level and single most critical finding.
2. KILL CHAINS — Ordered list of attack chains, each must:
   - Start from an unprivileged or external position
   - Chain at least 2 findings together using → notation in "chain"
   - Terminate at a Tier-0 asset (Domain Admin, KRBTGT, DC, GPO, AdminSDHolder)
   - In steps[].findingId use the real finding ID (e.g. KRB-002, ACC-034)
   - In steps[].attackerAction describe the realistic attacker action at that step
3. CHOKE POINTS — Max 5. Accounts or systems that appear in multiple chains.
4. IMMEDIATE ACTIONS — Top 3 remediations ordered by: (severity × occurrence count).

### DETERMINISTIC GRAPH SUMMARY (when provided in the user message)
- A block DETERMINISTIC_GRAPH_SUMMARY contains **nodes** and **edges** already merged from the scan engine (same entity tokens as findings). Treat it as **ground truth for topology**: do **not** claim edges that are not supported by that summary or the grouped findings.
- Choke points: prefer entities that appear in **multiple edges** or **multiple risks** (check IDs) in that summary.

### KILL CHAINS VS MERMAID
- Finding IDs belong in killChains (chain string, steps[].findingId), chokePoints, immediateActions, and executiveSummary.
- **mermaidChart is optional.** If you output it, use entity tokens only in node labels (U001, G002, …). If you are unsure or the summary is large, return **mermaidChart as an empty string** ""; the client may render a diagram from the deterministic summary instead.
- Do not put CheckId strings (ACC-033, KRB-002, …) inside Mermaid node labels as if they were entities.

### OUTPUT FORMAT
Return ONLY valid JSON with these keys:
{
  "executiveSummary": {
    "riskLevel": "Low|Medium|High|Critical",
    "mostCriticalFindingId": "STRING",
    "text": "STRING"
  },
  "killChains": [
    {
      "title": "STRING",
      "chain": "FindingA → FindingB → FindingC",
      "steps": [{ "findingId": "STRING", "attackerAction": "STRING" }],
      "endTier0Objective": "DomainAdmin|KRBTGT|DomainController|GPOEdit|AdminSDHolder|EnterpriseAdmin"
    }
  ],
  "chokePoints": [
    { "entity": "STRING", "whyHighLeverage": "STRING", "relatedFindingIds": ["STRING"] }
  ],
  "immediateActions": [
    { "action": "STRING", "targets": ["STRING"], "relatedFindingIds": ["STRING"], "expectedImpact": "STRING" }
  ],
  "mermaidChart": "OPTIONAL string: Mermaid graph TD, or empty string to skip"
}`;
router.post('/analyze', (0, auth_1.authorize)('admin', 'analyst'), async (req, res, next) => {
    try {
        const { findings, graphSummary, llmProvider, model, apiKey } = req.body;
        if (!findings || !Array.isArray(findings) || findings.length === 0) {
            return res.status(400).json({ message: 'Valid findings array is required' });
        }
        const built = (0, attackPathPayload_1.buildAttackPathPayload)(findings);
        const { userPromptJson, stats } = built;
        let graphSummaryJson = '';
        if (graphSummary != null && typeof graphSummary === 'object') {
            try {
                const raw = JSON.stringify(graphSummary);
                graphSummaryJson =
                    raw.length > GRAPH_SUMMARY_MAX_CHARS
                        ? `${raw.slice(0, GRAPH_SUMMARY_MAX_CHARS)}\n…(truncated)`
                        : raw;
            }
            catch {
                graphSummaryJson = '';
            }
        }
        logger_1.logger.info('attack-path analyze', {
            rawInputCount: stats.rawInputCount,
            distinctGroups: stats.distinctGroups,
            payloadRows: stats.payloadRows,
            approxChars: stats.approxChars,
            truncatedToBudget: stats.truncatedToBudget,
            provider: llmProvider,
            model,
            graphSummaryIncluded: Boolean(graphSummaryJson)
        });
        const startTime = Date.now();
        const graphBlock = graphSummaryJson
            ? `\n\nDETERMINISTIC_GRAPH_SUMMARY (canonical merged entities/edges from scan; token labels align with findings):\n${graphSummaryJson}\n`
            : '';
        const userPrompt = `Target AD Environment Assessment Data (tiered, deduplicated, redacted):\n\n${userPromptJson}${graphBlock}\nEntity tokens in samples use U/G/C/T/GPO/OU/CA/SPN prefixes where applicable. Prefer the deterministic graph summary for topology when present.`;
        let llmResponse = '';
        if (llmProvider === 'openai') {
            if (!apiKey)
                return res.status(400).json({ message: 'API Key required for OpenAI' });
            const response = await fetch('https://api.openai.com/v1/chat/completions', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${apiKey}` },
                body: JSON.stringify({
                    model: model,
                    response_format: { type: "json_object" },
                    messages: [
                        { role: 'system', content: SYSTEM_PROMPT },
                        { role: 'user', content: userPrompt }
                    ]
                })
            });
            if (!response.ok) {
                const errText = await response.text().catch(() => '');
                throw new Error(`OpenAI HTTP ${response.status}: ${errText || '(no body)'}`);
            }
            const responseData = await response.json();
            const data = responseData;
            llmResponse = data.choices[0].message.content;
        }
        else if (llmProvider === 'anthropic') {
            if (!apiKey)
                return res.status(400).json({ message: 'API Key required for Anthropic' });
            const response = await fetch('https://api.anthropic.com/v1/messages', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'x-api-key': apiKey,
                    'anthropic-version': '2023-06-01'
                },
                body: JSON.stringify({
                    model: model,
                    max_tokens: 4000,
                    system: SYSTEM_PROMPT + " Respond only with JSON.",
                    messages: [{ role: 'user', content: userPrompt }]
                })
            });
            if (!response.ok) {
                const errText = await response.text().catch(() => '');
                throw new Error(`Anthropic HTTP ${response.status}: ${errText || '(no body)'}`);
            }
            const responseData = await response.json();
            const data = responseData;
            llmResponse = data.content[0].text;
        }
        else if (llmProvider === 'ollama') {
            const endpoint = process.env.OLLAMA_URL || 'http://localhost:11434/api/generate';
            const prompt = `${SYSTEM_PROMPT}\n\n${userPrompt}`;
            const response = await fetch(endpoint, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    model: model,
                    prompt: prompt,
                    stream: false,
                    format: 'json'
                })
            });
            if (!response.ok) {
                const errText = await response.text().catch(() => '');
                throw new Error(`Ollama HTTP ${response.status}: ${errText || '(no body)'}`);
            }
            const responseData = await response.json();
            const data = responseData;
            llmResponse = data.response;
        }
        else {
            return res.status(400).json({ message: 'Unsupported LLM Provider' });
        }
        const endTime = Date.now();
        const duration = ((endTime - startTime) / 1000).toFixed(2);
        try {
            const parsed = JSON.parse(llmResponse);
            return res.json({
                executiveSummary: parsed.executiveSummary ?? null,
                killChains: Array.isArray(parsed.killChains) ? parsed.killChains : [],
                chokePoints: Array.isArray(parsed.chokePoints) ? parsed.chokePoints : [],
                immediateActions: Array.isArray(parsed.immediateActions) ? parsed.immediateActions : [],
                mermaidChart: parsed.mermaidChart || '',
                metadata: {
                    provider: llmProvider,
                    duration: `${duration}s`,
                    findingsCount: stats.payloadRows,
                    rawInputCount: stats.rawInputCount,
                    distinctGroups: stats.distinctGroups,
                    groupsCollapsed: stats.groupsCollapsed,
                    payloadRows: stats.payloadRows,
                    approxChars: stats.approxChars,
                    truncatedToBudget: stats.truncatedToBudget,
                    redactionApplied: true,
                    graphSummaryIncluded: Boolean(graphSummaryJson)
                }
            });
        }
        catch {
            return res.status(500).json({ message: 'LLM failed to return valid JSON', raw: llmResponse });
        }
    }
    catch (error) {
        res.status(500).json({ message: `Analysis Error: ${error.message}` });
    }
});
exports.default = router;
//# sourceMappingURL=attackPath.js.map