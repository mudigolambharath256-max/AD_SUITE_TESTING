# Graph extraction: CheckId → fields → edges

Deterministic entity graphs are built in [AD-Suite-Web/frontend/src/lib/buildAdGraph.ts](../AD-Suite-Web/frontend/src/lib/buildAdGraph.ts) from **flattened** finding rows (see [SCAN_RESULTS_FINDINGS_SCHEMA.md](./SCAN_RESULTS_FINDINGS_SCHEMA.md)).

## Node identity (`makeNodeKey`)

- If `objectGuid` is present on the row, the node id is derived from that value (stable hash prefix).
- If the label contains `\` (e.g. `DOMAIN\user`), the id uses the lowercased label with a type/kind-based hash.
- Otherwise the id is a stable hash of `kind` + label string.

**Limitations:** Same `sAMAccountName` in different domains without `objectGuid` may still collapse if labels do not include the domain. Prefer exporter fields that include NetBIOS prefix or GUID when available.

## Explicit edge rules (evidence-based)

| CheckId    | Required fields (typical)                         | Edges |
|-----------|-----------------------------------------------------|-------|
| ACC-039   | `DelegationSetBy`, `TargetComputer`                 | Setter → `AllowedToAct(RBCD)` → computer |
| ACC-033   | `Principal`                                       | Principal → `DCSync` → Domain |
| GPO-001   | `Trustee`, `GpoName`; optional `LinkedOu`         | Trustee → right → GPO; optional GPO → `LinkedTo` → OU |
| ADCS-ESC1 | `EnrollableBy`, `Template`; optional `CaName`   | Enroller → `Enroll` → Template; optional Template → `PublishedBy` → CA |
| ADCS-ESC4 | `Trustee`, `Template`                             | Trustee → right (e.g. WriteDacl) → Template |
| ACC-034   | `SamAccountName`; optional `ServicePrincipalName` | AnyDomainUser → `Kerberoast` → user; optional user → `HasSPN` → SPN |
| KRB-002   | `SamAccountName`                                  | AnyDomainUser → `ASREPRoast` → user |
| ACC-001   | `SamAccountName`                                  | User → `ProtectedUser(adminCount=1)` → Domain |
| ACC-037   | `Account` or `SamAccountName`                     | Domain → `HasShadowCredentials` → account |
| ACC-026   | `SamAccountName`                                  | Domain → `ReversibleEncryptionEnabled` → user |

## Synthetic / anchor nodes

- **Domain** — label from scan `meta.defaultNamingContext` when the UI passes it; otherwise `"Domain"`.
- **AnyDomainUser** — `Other` kind; used as the source for Kerberoast and AS-REP edges.

## Generic fallback (no specific rule)

Rows that do not match any CheckId block above still contribute **nodes** when known entity columns are present. **SameFinding** star edges connect all entities extracted on that same row (co-occurrence in one finding, not an AD trust).

Keys include (among others): `SamAccountName`, `Account`, `Principal`, `DelegationSetBy`, `Trustee`, `Computer`, `TargetComputer`, `DnsHostName`, `Template`, `CaName`, `GpoName`, `LinkedOu`, `ServicePrincipalName`, `EnrollableBy`.

## `memberOf` (all rows)

When `samAccountName` or `name` is present together with `memberOf` / `MemberOf` (string or array of DNs), the builder adds **User|Group → MemberOf → Group** edges using the first `CN=` from each member DN (`cnFromDn`).

## Orphan nodes → Domain

After all rows, any node with **no incident edges** (except the Domain and AnyDomainUser anchors) gets **→ InScope → Domain** so force-directed layout stays one connected component. Edge `findingId` uses the node’s first check id in `risks` when available.

## Downstream consumers

| Consumer | Use |
|----------|-----|
| Scans → Cytoscape | `extractEntityGraphFromFindings` → delegates to `buildAdGraphFromFindings` → `adGraphToEntityGraph` |
| New Scan → Sigma | `toSigmaGraphData` after full `scan-results` fetch |
| Attack Path LLM | `buildGraphSummary` on tokenized rows, sent as `graphSummary`; client fills empty `mermaidChart` via `graphSummaryToMermaid` |

## Adding a new check

1. Confirm finding JSON shape from the PowerShell engine / catalog `outputPropertyMap`.
2. Add a `checkId === 'X-Y'` branch in `buildAdGraphFromFindings` **or** extend fallback keys only if edges are unknown (nodes-only).
3. Update this table.
