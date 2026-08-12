# FASE 8 — Preflight display-first v7.1 v4

Estado: artefacto construido/validado; **detenerse antes de Fastboot**.

| Campo | Valor |
|---|---|
| Kernel run | `31513653872` |
| Workflow 15 | `31552881595` |
| Commit | `73ddbc0` |
| Artefacto | `boot-laurel-v71-display-first-diag-v4.img` |
| Ruta local | `local-private/boot-31552881595/boot-out/boot-laurel-v71-display-first-diag-v4.img` |
| SHA-256 | `3737b43f873e6ce2f8c2446b21032c170e993c036da79c3574b975ce3c3f2276` |
| Tamaño | 23,097,344 bytes |
| Límite boot | 67,108,864 bytes |
| Rootfs | no monta `system_b` |

## Cmdline v4

```text
console=ttyMSM0,115200n8 console=tty0 consoleblank=0 loglevel=7
ignore_loglevel printk.time=1 panic=0 clk_ignore_unused pd_ignore_unused
regulator_ignore_unused androidboot.hardware=qcom androidboot.console=ttyMSM0
loop.max_part=7 buildvariant=user
```

Se eliminó `initcall_debug` para que la pantalla sea legible; `panic=0`
conserva un panic/oops en vez de reiniciar; no se activa `panic_on_warn`.

## Orden visual esperado

1. Solo logs y nunca `V71_V4_PID1_FIRST_INSTRUCTION`: bloqueo antes de `/init`,
   descompresión o consola/framebuffer.
2. VERDE (`V71_V4_FB_CHECKPOINT_GREEN`): `/init` alcanzado y fb0 escribible.
3. AZUL (`V71_V4_FB_CHECKPOINT_BLUE`): display sobrevivió la auditoría previa
   a USB.
4. ROJO (`V71_V4_FB_CHECKPOINT_RED`): userspace/fb siguen vivos y USB/UDC falló.
5. Heartbeat visible: PID1 sigue vivo.
6. Negro después de VERDE/AZUL: pérdida de framebuffer/panel/recursos; no se
   clasifica automáticamente como panic.

## Validación

- Kernel/ramdisk/DTB byte-idénticos.
- DTB USB/display auditado con `fdtget`.
- Initramfs v4 ARM64 estático, sin módulos 6.1.
- Patrones green/blue/red incluidos y validados.
- 58 tests, ShellCheck, YAML/JSON, `bash -n`, `git diff --check` y auditoría
  pública superados.

## Punto de parada

No se ejecutó ninguna operación física. Repetir Fastboot read-only, confirmar
slot/backups, verificar SHA y solicitar autorización explícita inmediata antes
de cualquier prueba.

## Comando preparado, NO ejecutado

```text
fastboot flash boot_b local-private/boot-31552881595/boot-out/boot-laurel-v71-display-first-diag-v4.img
```
