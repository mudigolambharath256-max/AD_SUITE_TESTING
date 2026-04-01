# RFC: Microsoft Graph for AAD-* checks and optional elevated collector

## Problem

The catalog includes **AAD-001 … AAD-042** style rows (Azure / Entra integration). LDAP to on-premises DCs **cannot** read Entra ID tenant configuration (Conditional Access, hybrid join state as exposed by Graph, etc.). Today these checks are **`engine: inventory`** and are skipped in the default risk scan.

## Option A — Microsoft Graph service (recommended if cloud coverage is required)

- **Separate** small service (Node, C#, or Azure Function) using **application** or **delegated** permissions approved by the customer.
- **Data model:** Map Graph JSON to the same “finding row” shape the UI expects, or introduce `engine: graph` with a dedicated executor in a future release.
- **Auth:** Client credentials (app-only) or delegated with admin consent; tenant ID and secret/certificate stored in Key Vault.
- **Scope:** Start with 3–5 high-value controls (CA policies, legacy auth block, privileged role assignments) before porting all 42 stubs.

## Option B — Elevated on-prem collector (DC registry / WMI)

Some titles imply **local machine policy** (firewall, patches, RDP) that LDAP cannot see. A **optional**, **highly privileged** collector running on DCs or via WinRM could feed results into the same JSON schema.

- **Risks:** Credential exposure, blast radius, change control; must be **explicitly optional** and documented—not the default “domain user safe” path.
- **Delivery:** GPO-deployed scheduled task, SCCM, or dedicated audit VM with constrained management account.

## Recommendation

Ship **Option A** when the product commits to hybrid cloud assessment. Keep **Option B** as a separate SKU or integrator script; do not silently promote LDAP stubs to “pass/fail” without the right data source.

See [`docs/CATALOG_ESC_CERT_AND_AAD.md`](CATALOG_ESC_CERT_AND_AAD.md).
