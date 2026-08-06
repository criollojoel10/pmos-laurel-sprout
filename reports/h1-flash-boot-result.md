# h1 — Resultado de pruebas de flash en partición (boot_b / vbmeta_b)

> Repositorio pmos-laurel-sprout. Estado honesto, sin datos sensibles
> (serial/IMEI/MAC redactados ni logueados).

## Contexto

- Artefacto de diagnóstico `TEST_IMG`: `boot-laurel-diagnostic.img`
  (SHA256 `66e7005f…a0…`, 21,499,904 B), kernel DT mainline + initramfs
  BusyBox, `/init` no-destructivo.
- Objetivo Fase H0: arrancar el kernel/initramfs desde una partición `boot`
  persistente sin tocar `boot_a` (ORIGINAL), usando `boot_b` como target y
  restaurando el slot `a` al final.
- Tamaño `boot_a`/`boot_b`: 64 MiB (0x4000000) → la imagen (~20.5 MiB) cabe.

## FASE 8 — punto de parada obligatorio

Antes de toda prueba se presenta: artefactos + hashes, tamaño vs límite,
slot actual, particiones a modificar, procedimiento de recuperación,
confirmación de respaldos, y la prueba menos destructiva. No proseguir sin
autorización explícita.

---

## ITER 1 — `fastboot flash boot_b` (TEST_IMG)

- Target: `boot_b` (SLAVE). `boot_a` (ORIGINAL) intacto.
- Resultado: Sending OKAY + Writing OKAY; `set_active b` OK (current-slot=b).
- Reboot → **volvió a Fastboot** (idVendor 18d1 / idProduct d00d), current-slot=b.
  Kernel/initramfs no llegaron a `/init`.
- Recuperación: `set_active a` (sin escritura) restauró el slot a.

## ITER 2 — Hipótesis AVB con vbmeta_b flags=3

- Autorización: flash SOLO `vbmeta_b` (vbmeta /e/OS, flags=3 = verif OFF).
  No se reflasheó `boot_b` ni se borró `dtbo`.
- Candidato auditado: `VBMETA_custom_flags3_eos.img` (4096 B,
  SHA-256 `b5c6ca4a…60f`), byte-idéntico al vbmeta del payload /e/OS.
- Resultado: `flash vbmeta_b` OKAY (Sending+Writing); `set_active b` OK;
  current-slot=b.
- Reboot → **volvió a Fastboot**. Verificación AVB (flags=3) NO hizo bootear.
- Clasificación honesta: la **hipótesis AVB queda debilitada**. La causa más
  probable pasa a ser la **imagen boot en sí / selección por aboot** (p. ej.
  método de DTB), no la verificación AVB.

---

## ITER 3 — EJECUTADO: variante `append_dtb=true` / `qcdt=false` (2026-08-05)

Hipótesis: el TEST_IMG incluía el DTB en el campo `dtb` del header v2 (método
conocido como "DTB por campo" — en reportes previos mal etiquetado como QCDT;
QCDT es el mecanismo que añade el DTB al kernel, que es justo lo que IT3
reproduce). Probamos el modo postmarketOS `deviceinfo_append_dtb=true` +
`deviceinfo_bootimg_qcdt=false`: el DTB se **concatena al final del kernel**
y `dtb_size=0`.

### Artefacto validado

| Campo | Valor |
|---|---|
| Archivo | `boot-laurel-append-dtb.img` |
| Ruta | `local-private/phase-e-flash/preflight/it3-variant/boot-laurel-append-dtb.img` |
| SHA-256 | `b0761f109a7be40da56f17abb51720616be93ade1b1a754ea24b2e9a6fc9ed14` |
| Tamaño | 21,495,808 B (~20.5 MiB) — cabe en boot (64 MiB) |
| header | v2, page 4096, base 0x0 |
| kernel_size | 20,284,596 (Image.gz 20,247,402 + dtb 37,194) |
| dtb_size (field) | 0 (append_dtb, sin campo DTB separado) |
| dtb | byte-idéntico a `sm6125-xiaomi-laurel-sprout.dtb` (SHA-256 `fc4f6e42…`), magic `d00dfeed` (4B), validado |
| ramdisk / cmdline / os_version | idénticos al TEST_IMG |

### Verificación realizada (auditoría pre-flash completa)

- DTB concatenado == archivo fuente, byte-por-byte (SHA `fc4f6e42…` igual).
- Image.gz extraído byte-idéntico a fuente (SHA `9e7c1e48…`).
- `size(payload kernel) = size(Image.gz) + size(dtb)` = 20,284,596 ✔.
- `dtb_size=0`, `dtb_addr=0x0`; solo **una** aparición de magic DTB en la imagen
  (sin copia duplicada accidental).
- ramdisk (SHA `38fc6a10…`) y cmdline idénticos al TEST_IMG.

### Ejecución (usuario; flash/set_active/reboot denegados al agente)

```
sha256sum .../boot-laurel-append-dtb.img
b0761f109a7be40da56f17abb51720616be93ade1b1a754ea24b2e9a6fc9ed14
Sending 'boot_b' (20992 KB)   OKAY [0.480s]
Writing 'boot_b'              OKAY [0.116s]
current-slot: a               (no se cambió con el flash)
set_active b                  OKAY
current-slot: b
```

Verificación independiente del agente: `current-slot: b`, `unlocked: yes`.

### Resultado del reboot (2026-08-05, ~15:01)

Captura journal/udev (logs/it3): USB disconnect 15:01:35 → reconnect
15:01:40 como **idVendor=18d1 idProduct=d00d (Fastboot)**. Sin gadget
adbc/serial/interfaz de red. El kernel/initramfs **no llegó a `/init`**:
volvió a Fastboot en la misma ventana que IT1/IT2.

### Clasificación honesta (después de 3 iteraciones)

| Hipótesis | Estado |
|---|---|
| AVB como causa principal | **Descartada razonablemente** (vbmeta_b flags=3 ya desde IT2) |
| Método de entrega del DTB (campo v2 vs append_dtb) | **Sin efecto** — IT1 y IT3 idénticos en retorno a Fastboot |
| Imagen boot en sí / kernel / DTS | **Causa probable** — misma imagen kernel en las 3 iteraciones |
| Selección por aboot (layout header, address, etc.) | **Posible**, sin descartar |

Próximos pasos propuestos (NO ejecutados): opción A (control positivo con
boot histórico 6.1 si existe), opción B (comparación binaria boot 6.1 vs IT3),
opción C (UART/pstore para distinguir rechazo de aboot vs kernel muerto),
opción D (dtbo_b como IT4 solo si A+B lo apuntan). No borrar dtbo.

Estado transaccional actual: current-slot=b; boot_b=variante append_dtb
fallida; vbmeta_b=flags=3; boot_a/vbmeta_a intactos.

## Recuperación

- Volver al sistema original: `fastboot set_active a` + verificar +
  `fastboot reboot` (autorización específica).
- Restaurar `boot_b` a KNOWN_GOOD si hiciera falta.

## No publicado

- Serial, IMEI, MAC redactados. Logs raw fastboot solo en `local-private/…`.