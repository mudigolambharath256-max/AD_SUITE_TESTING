# Curated pack coverage (`checks.json`)

Rule pack version is in `checks.json` under `meta.packVersion` (also echoed in scan `report.html` and `scan-results.json`).

## Risk checks (in batch scan)

| Category | Check IDs |
|----------|-----------|
| Access_Control | ACC-001, ACC-002, ACC-003, ACC-004, ACC-006, ACC-007, ACC-034 |
| Kerberos_Security | KRB-001, KRB-002, KRB-003, KRB-004, KRB-005, KRB-006, KRB-009 |
| Group_Policy | GPO-ACL-001 (filesystem) |

**Total LDAP risk:** 14  
**Filesystem risk:** 1  
**Grand total risk:** 15

## Inventory (excluded from risk scan)

| Category | Check IDs |
|----------|-----------|
| Domain_Configuration | DC-003 |
| Domain_Controllers | DC-008 |
| LDAP_Security | LDAP-001 |
| Documentation | SAMPLE-SCHEMA-NC |

Update this table when promoting new IDs from `checks.generated.json`.

Pack metadata lives in `checks.json` → `meta` (`packVersion`, `packName`, `packDateUtc`).
