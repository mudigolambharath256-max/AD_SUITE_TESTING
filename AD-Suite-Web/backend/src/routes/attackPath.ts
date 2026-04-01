import express from 'express';
import { authenticate, authorize } from '../middleware/auth';
import { auditMutations } from '../middleware/auditMiddleware';
import { logger } from '../utils/logger';
import { buildAttackPathPayload, type RawFindingInput } from '../utils/attackPathPayload';

const router = express.Router();
router.use(authenticate);
router.use(auditMutations);

interface AnalyzeParams {
    findings: any[];
    llmProvider: 'openai' | 'anthropic' | 'ollama';
    model: string;
    apiKey?: string;
}

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

### KILL CHAINS VS MERMAID (critical)
- Finding IDs belong in killChains (chain string, steps[].findingId), chokePoints, immediateActions, and executiveSummary—not inside Mermaid node boxes.
- The Mermaid diagram is an ENTITY attack graph (who/what is abused), not a list of check codes.

### MERMAID GRAPH RULES — follow exactly or the render will break:
- Use graph TD (top-down)
- Output MUST include MULTIPLE SUBGRAPHS: one subgraph per kill chain (Chain1, Chain2, ...).
- Each subgraph MUST visualize the corresponding killChains[i] as an ordered entity path.
- Per-chain limit: max 15 nodes. Overall limit: max 80 nodes.
- Node IDs: alphanumeric only (e.g. N1, A2, EXT). No hyphens in node IDs.
- Node labels (inside brackets) MUST be ENTITY TOKENS from the payload only: U001, C002, G003, T001, GPO001, OU001, CA001, SPN001, etc.—matching tokenized Entities/Evidence in the JSON. Do NOT emit real names.
- FORBIDDEN inside any node label or as a standalone node label: CheckId-style strings (anything like ACC-025, GPO-001, KRB-002, LDAP-003, ADCS-ESC1, DCONF-001, CERT-001, COMPLY-001). Those are not entities.
- If you need an "external / unprivileged starting point" with no entity token, use node ID EXT or START and label EXT or START only.
- Edges carry the attack: use short attacker-action words in edge labels, e.g. -->|Kerberoast|, -->|DCSync|, -->|Enroll|. Optional trailing ref without hyphens, e.g. via KRB002, is allowed if it fits.
- No parentheses, colons, slashes, or backslashes inside node labels.
- Every node must appear in at least one edge.

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
  "mermaidChart": "graph TD\\nA1[... ] -->|...| B1\\n..."
}`;

router.post('/analyze', authorize('admin', 'analyst'), async (req, res, next) => {
    try {
        const { findings, llmProvider, model, apiKey } = req.body as AnalyzeParams;

        if (!findings || !Array.isArray(findings) || findings.length === 0) {
            return res.status(400).json({ message: 'Valid findings array is required' });
        }

        const built = buildAttackPathPayload(findings as RawFindingInput[]);
        const { userPromptJson, stats } = built;

        logger.info('attack-path analyze', {
            rawInputCount: stats.rawInputCount,
            distinctGroups: stats.distinctGroups,
            payloadRows: stats.payloadRows,
            approxChars: stats.approxChars,
            truncatedToBudget: stats.truncatedToBudget,
            provider: llmProvider,
            model
        });

        const startTime = Date.now();
        const userPrompt = `Target AD Environment Assessment Data (tiered, deduplicated, redacted):\n\n${userPromptJson}\n\nMERMAID: In samples[].Entities and Evidence, entity values are tokenized (U-prefix users, C computers, G groups, templates, GPO, OU, CA, SPN). The mermaidChart must use those same tokens as node labels—not CheckId strings.`;
        let llmResponse = '';

        if (llmProvider === 'openai') {
            if (!apiKey) return res.status(400).json({ message: 'API Key required for OpenAI' });
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
            const data = responseData as any;
            llmResponse = data.choices[0].message.content;
        } 
        else if (llmProvider === 'anthropic') {
            if (!apiKey) return res.status(400).json({ message: 'API Key required for Anthropic' });
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
            const data = responseData as any;
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
            const data = responseData as any;
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
                    redactionApplied: true
                }
            });
        } catch {
            return res.status(500).json({ message: 'LLM failed to return valid JSON', raw: llmResponse });
        }
    } catch (error: any) {
        res.status(500).json({ message: `Analysis Error: ${error.message}` });
    }
});

export default router;
