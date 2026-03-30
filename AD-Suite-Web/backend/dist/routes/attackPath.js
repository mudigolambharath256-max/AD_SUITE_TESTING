"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const auth_1 = require("../middleware/auth");
const logger_1 = require("../utils/logger");
const attackPathPayload_1 = require("../utils/attackPathPayload");
const router = express_1.default.Router();
router.use(auth_1.authenticate);
const SYSTEM_PROMPT = `You are an expert Active Directory Security Architect and Red Team lead.
I am providing you with security findings from an AD Security Suite assessment.

The user message contains a JSON object with:
- "summary": counts by severity/category and top checks by volume (for context).
- "groupedFindings": deduplicated groups; each has "occurrenceCount" and representative "samples" (redacted). Use counts to infer scale.

### YOUR MISSION
1. Identify **Lateral Movement** and **Privilege Escalation** paths.
2. Chain multiple low/medium/high findings together to form a "Critical Path" (e.g., a service account with high privileges + a cleartext password exposure).
3. Identify **Choke Points**: Systems or accounts that, if compromised, grant disproportionate access (e.g., Tier-0 assets, Domain Controllers, GPO editors).
4. Provide a Narrative and a Visual Graph (Mermaid).

### OUTPUT FORMAT
You MUST return a JSON object exactly matching this format:
{
    "narrative": "Markdown string with ## Headings. Focus on 'The Big Picture' and specific 'Kill Chains'.",
    "mermaidChart": "A valid Mermaid.js graph string (graph TD). Example: node1[User A] -- Exploit --> node2[Admin B]. Use descriptive labels."
}

DO NOT wrap the response in markdown blocks. Return ONLY the JSON object.`;
router.post('/analyze', async (req, res, next) => {
    try {
        const { findings, llmProvider, model, apiKey } = req.body;
        if (!findings || !Array.isArray(findings) || findings.length === 0) {
            return res.status(400).json({ message: 'Valid findings array is required' });
        }
        const built = (0, attackPathPayload_1.buildAttackPathPayload)(findings);
        const { userPromptJson, stats } = built;
        logger_1.logger.info('attack-path analyze', {
            rawInputCount: stats.rawInputCount,
            distinctGroups: stats.distinctGroups,
            payloadRows: stats.payloadRows,
            approxChars: stats.approxChars,
            truncatedToBudget: stats.truncatedToBudget,
            provider: llmProvider,
            model
        });
        const startTime = Date.now();
        const userPrompt = `Target AD Environment Assessment Data (tiered, deduplicated, redacted):\n\n${userPromptJson}`;
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
            if (!response.ok)
                throw new Error(`OpenAI HTTP Error: ${response.status}`);
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
            if (!response.ok)
                throw new Error(`Anthropic Error: ${response.status}`);
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
            if (!response.ok)
                throw new Error(`Ollama Error: ${response.status}`);
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
                narrative: parsed.narrative || "No narrative generated.",
                mermaidChart: parsed.mermaidChart || "",
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
                    redactionApplied: true
                }
            });
        }
        catch (e) {
            return res.status(500).json({ message: 'LLM failed to return valid JSON', raw: llmResponse });
        }
    }
    catch (error) {
        res.status(500).json({ message: `Analysis Error: ${error.message}` });
    }
});
exports.default = router;
//# sourceMappingURL=attackPath.js.map