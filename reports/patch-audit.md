# Auditoría de parches

Registro de parches aplicados o pendientes. Cada parche se documenta con:
origen, licencia, estado (upstream/accepted/queued/pending/downstream-only/
local-workaround) y dependencias.

## Reglas

- Verificar si el parche está upstream, en la rama sm61x5 o en el commit
  fijado antes de aplicarlo.
- Ejecutar `git apply --check` previamente.
- Evitar duplicados.
- Conservar autoría y Signed-off-by.

## Estado

| Parche | Área | Estado | Origen | Notas |
|---|---|---|---|---|
| _pendiente_ | — | — | — | Ejecutar `01-research-upstream`. |
