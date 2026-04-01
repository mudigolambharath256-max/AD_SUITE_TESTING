# Kerberos ticket lifetime and LDAP

**User and service ticket lifetimes** (TGT/TGS maximum lifetime, renewal, clock skew enforcement details) are primarily controlled by:

- **Group Policy** (Computer Configuration → Policies → Windows Settings → Security Settings → Account Policies → Kerberos Policy), and
- **Registry** on domain members / DCs as applied by policy—not by a single attribute on the `domainDNS` object that proves “ticket lifetime” in isolation.

## Catalog checks DCONF-015, DCONF-016, KRB-038

Historically, some rows used `(objectClass=domain)` with generic metadata. **LDAP alone cannot assert** the same controls as opening GPO or security baselines on DCs.

Current posture in the unified catalog (via [`checks.catalog-additions.json`](../checks.catalog-additions.json)):

- These IDs are **documented placeholders**: descriptions state that **ticket policy is not measured** from LDAP.
- Queries use a **non-matching filter** so the check does not emit false “findings” against the domain object for ticket lifetime semantics. **`scoreWeight`** is **0** where applicable so the global score is not driven by these rows.

## What to use instead

- Microsoft security baselines / GPO reporting for Kerberos policy.
- For **password expiration**, domain password-policy attributes on `domainDNS` are meaningful; that is separate from **Kerberos ticket** maximums.

See also [`docs/RISK_PACK.md`](RISK_PACK.md) and [`PRODUCT_POSTURE_SUMMARY.txt`](../PRODUCT_POSTURE_SUMMARY.txt).
