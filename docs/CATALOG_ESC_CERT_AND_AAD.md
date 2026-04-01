# ESC / CERT checks and Azure (AAD) stubs

## ADCS-ESC* vs CERT-*

- **`ADCS-ESC1` through `ADCS-ESC8`** use the **`adcs`** engine (`Invoke-ADSuiteAdcsCheck`). They are the **implemented** ESC-style assessments against the AD CS configuration exposed to the scanner.
- **`CERT-*`** rows in the catalog are often **inventory** or **legacy** placeholders (e.g. certificate store topics, duplicate “ESC” wording). They are **not** a second parallel ESC implementation. Treat **`ADCS-ESC*`** as the source of truth for ESC coverage unless a **`CERT-*`** check is explicitly promoted to a real engine with a defined data source.

## AAD-* checks

- **`AAD-*`** checks are typically **`engine: inventory`** and are **not** evaluated by LDAP against on-prem AD in the default risk scan (inventory is skipped).
- **Microsoft Entra ID / Azure AD** settings require **Microsoft Graph or other cloud APIs**, not LDAP to domain controllers. Promoting **`AAD-*`** to **`ldap`** would be misleading unless the product adds an Azure integration path and documents auth, scopes, and limitations.
