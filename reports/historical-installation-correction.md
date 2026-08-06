# Corrección de la interpretación de los prompts de shell históricos

- Fecha de la corrección: 2026-08-05.
- Motivo: se malinterpretaron los prefijos `$` y `#` de la guía histórica de
  instalación de postmarketOS como si fueran comentarios de script. En realidad
  son **prompts de shell**: `$` = usuario sin privilegios, `#` = root.

## Fuente histórica

- Página: `https://wiki.postmarketOS.org/wiki/Xiaomi_Mi_A3_(xiaomi-laurel)`.
- Capture Wayback `20240121085749`; última edición 13 nov 2023 (oldid 52435).
- Copia de evidencia sin alterar: `local-private/wiki-xiaomi-laurel-20240121.md`.

Texto literal de la sección Installation (prompts de shell):

```
$ pmbootstrap init
$ pmbootstrap install
# fastboot erase dtbo
$ pmbootstrap flasher flash_vbmeta
$ pmbootstrap flasher flash_rootfs
$ pmbootstrap flasher flash_kernel
# fastboot reboot
```

La página aclara: *"Install fastboot on your host system and run the following
commands"* — es decir, **todos** los renglones indican comandos a ejecutar. No
especifica que ninguno esté comentado u opcional.

## Corrección de la interpretación

| Prompt | Significado | Interpretación correcta |
|---|---|---|
| `$` | unprivileged shell prompt | ejecutar como usuario normal |
| `#` | root shell prompt | ejecutar como root |
| `# fastboot erase dtbo` | comando ejecutado como root | `sudo fastboot erase dtbo` |
| `# fastboot reboot` | comando ejecutado como root | `sudo fastboot reboot` |

El procedimiento histórico **completo y obligatorio** es:

```
pmbootstrap init
pmbootstrap install
sudo fastboot erase dtbo
pmbootstrap flasher flash_vbmeta
pmbootstrap flasher flash_rootfs
pmbootstrap flasher flash_kernel
sudo fastboot reboot
```

`pmbootstrap flasher` los que requieren root ya ejecutan internamente
`sudo`/root cuando hace falta; lo relevante es que **los dos comandos Fastboot
(`erase dtbo` y `reboot`) y la línea `pmbootstrap flasher` NO estaban comentados**:
eran parte activa del flujo.

## Alcance de la corrección

Se modifica únicamente la **interpretación** en documentos derivados. La fuente
(`local-private/wiki-xiaomi-laurel-20240121.md`) se conserva como evidencia y
**no se altera** su texto literal.

Documentos afectados (interpretación derivada a corregir/registrar):

- `reports/postmarketos-history-analysis.md` — clasificación de pasos
  (sección "Clasificación de los pasos de la guía histórica").
- `reports/android-reference-comparison.md` — aprendizaje sobre `erase dtbo`
  (línea 87-91).
- `docs/INSTALL.md` (notas "Qué NO hacer" respecto a dtbo).
- Documentos derivados y estado que referencien el flujo histórico.

> Registro técnico: `HISTORICAL_SHELL_PROMPT_CORRECTION`.

## Consecuencias para la estrategia experimental

1. Ya no puede afirmarse que `erase dtbo` fuera opcional/comentado. El boot del
   kernel mainline del port histórico **incluyó** un `dtbo` borrado.
2. La hipótesis H3 (DTBO debe borrarse antes del arranque mainline) cobra más peso
   y debe probarse de forma aislada y protegida (solo `dtbo_b`, con respaldo).
3. La hipótesis H2/H5 (la combinación coherente `vbmeta + rootfs + kernel + dtbo
   borrado + initramfs histórico`) es coherente con un **flujo completo de
   instalación** y no un arranque puntual.
4. `fastboot reboot` final era parte estándar del flujo tras el flash; su uso
   aquí (autorizado, con gate) es normal, no una desviación.

## Evidencia de que era flujo completo

La página está categorizada como "Flashing Works"; los comandos de instalación
cubren init, install, erase dtbo, flash de 3 artefactos (vbmeta, rootfs, kernel)
y reboot. No hay marcado de "comentado" en la fuente original, solo prompts de
shell. El prefijo `#` de `erase dtbo` y `reboot` es el prompt de **root**, no la
sintaxis de comentario.