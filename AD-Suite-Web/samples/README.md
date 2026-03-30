# Sample scan outputs (demos)

## GOAD-style Attack Path demo

File: [`goad-attackpath-demo-scan-results.json`](goad-attackpath-demo-scan-results.json)

**Synthetic only** — fictional `corp.local`-style names and findings for testing the **Attack Path** LLM flow. It is **not** a real GOAD export or a live scan.

### How to test in the UI

1. Start the backend and frontend (`AD-Suite-Web/backend` and `AD-Suite-Web/frontend`).
2. Sign in to the web app.
3. Open **Attack Path** (sidebar).
4. Under **Data Source**, click the **Upload** button and choose `goad-attackpath-demo-scan-results.json`.
5. Adjust **Severity** toggles (Critical / High / Medium / Low) to control how many rows are sent to analysis.
6. Set **Provider** and **Model** (e.g. Ollama with a JSON-capable model locally).
7. Click **Generate Attack Path** and wait for the narrative and Mermaid graph.
8. Check **Payload sent to model** for counts, grouping, and redaction (server-side).

### Format

The upload parser expects a JSON document with a top-level `results` (or `Results`) array. Each row should include `CheckId`, `CheckName`, `Severity`, `Category`, `Description`, and optional `Impact` / `Message` / `RiskData` (see [`AttackPath.tsx`](../frontend/src/pages/AttackPath.tsx)).
