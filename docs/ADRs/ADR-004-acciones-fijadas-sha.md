# ADR-004 — Acciones externas fijadas por SHA completo

- Estado: **Aceptado**
- Fecha: 2026-08-02

## Contexto

Las acciones de GitHub Actions con versión flotante (`v7`) pueden cambiar el
comportamiento silenciosamente y romper la reproducibilidad o la seguridad.

## Decisión

Todas las acciones externas se fijan por SHA-256 completo del commit, con un
comentario con la versión humana de la acción:

```yaml
# actions/checkout@v7.0.1
uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1
```

`00-quality.yml` verifica que ninguna acción externa use `@vN` o SHA corto.

## Consecuencias

- Dependabot puede sugerir cambios de versión, que se aplican re-fijando SHA.
- Menor riesgo de supply-chain.

## Referencias

- `actions/checkout@v7.0.1` -> `3d3c42e5aac5ba805825da76410c181273ba90b1`
- `actions/upload-artifact@v7.0.1` -> `043fb46d1a93c77aae656e7c1c64a875d1fc6a0a`
- `actions/download-artifact@v8.0.1` -> `3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c`
- `actions/setup-python@v7.0.0` -> `5fda3b95a4ea91299a34e894583c3862153e4b97`
