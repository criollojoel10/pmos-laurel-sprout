# ADR-003 — opencode.json usa `permission` (singular) según el schema oficial

- Estado: **Aceptado**
- Fecha: 2026-08-02

## Contexto

Una configuración previa de opencode era inválida por mezclar esquemas
(`permissions` plural con lista `allow`/`deny`, clave `version`). El schema
oficial (`https://opencode.ai/config.json`) define `PermissionConfig` con la
clave **`permission`** (singular) y sin clave `version` de nivel superior.

## Decisión

`opencode.json` usa:

- `permission` (singular), objeto de reglas por herramienta;
- sin clave `version`;
- `default_agent: "build"`;
- reglas `allow`/`deny` por patrón en `permission.bash`.

La validez se comprueba contra el schema en `00-quality.yml` y con
`scripts/test-opencode-security-policy.sh`.

## Consecuencias

- Se prohíbe volver a introducir `permissions` (plural) o `version`.
- El `$schema` apunta al schema oficial de opencode.

## Referencia

- Schema: https://opencode.ai/config.json
