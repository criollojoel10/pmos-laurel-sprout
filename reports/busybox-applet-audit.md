# Auditoría de applets BusyBox del initramfs diagnóstico (v0, defectuoso)

Fecha: 2026-08-09. Fuente: `initramfs.cpio.gz` extraído en
`local-private/phase-e-flash/preflight/h61-sed-fix/old-initramfs/`.

## Causa raíz del panic EX3

El initramfs instaló symlinks solo para una lista fija de applets. `sed`
(usado por `/init` en `mount | sed 's/^/  /'`, línea 35) **no tenía enlace**,
por lo que el shell produjo `sed: not found`, PID 1 terminó y el kernel
paniqueó (`Attempted to kill init! exitcode=0x00007f00` = status 127).

## Evidencia

- `bin/busybox`: ELF64 AArch64, **statically linked**, sin `.interp`.
- `strings` del binario contiene `sed`, `grep`, `awk`, `mount`, `dmesg`,
  `uptime`, `setsid`, `sync`, `switch_root`, `tr`, `wc` (applet_names incluye
  todos los nombres, compilados o no; la tabla real se confirma en CI con
  `busybox --list`).
- Enlaces presentes (target `/bin/busybox`):
  `bin/{sh,cat,chmod,cp,df,dmesg,echo,free,head,ln,ls,mkdir,mknod,mount,mv,ps,rm,sleep,tail,touch,umount,uname}`
  y `sbin/{mount,reboot}`.
- Enlaces ausentes:
  `bin/{sed,grep,awk,uptime,setsid,sync,switch_root,tr,wc}`.

## Comandos usados por `/init` (v0) y su disponibilidad

Extraídos de `init` (versión embebida; la del repo actual es idéntica salvo
secciones de texto):

| Comando | Usado en | Symlink | Estado |
|---|---|---|---|
| sh | shells/consola | OK | OK |
| cat | cmdline, governors, firmware | OK | OK |
| echo | log() | OK | OK |
| uname | cabecera | OK | OK |
| awk | uptime | FALTA | P1 bloqueante |
| mkdir | /proc /sys /dev | OK | OK |
| mount | proc/sys/devtmpfs/pstore | OK | OK |
| sed | mtab, drm, fb, sd*, pstore | FALTA | P1 bloqueante (causa panic) |
| ls | /dev/dri, /dev/fb*, /dev/sd* | OK | OK |
| test | -c ttyMSM0 | OK (builtin sh) | OK |
| wc | vregs | FALTA | P1 |
| tr | vregs | FALTA | P1 |
| setsid | shell serial | FALTA | P1 |
| sleep | wait_or_sleep | OK | OK |
| grep | (solo si se usa) | FALTA | P1 |
| uptime | cabecera | FALTA | P1 |
| sync | (no usado, sí en kernel panic) | FALTA | P2 |
| switch_root | (no usado aquí) | FALTA | P2 |

## Fix requerido

1. `scripts/build-busybox-arm64.sh`: construir con CONFIG_SED=y (y el resto),
   `make olddefconfig`, `make CONFIG_PREFIX=<stage> install` para que BusyBox
   instale los enlaces de applets, y fallar si falta `sed`.
2. `scripts/build-diagnostic-initramfs.sh`: instalar enlaces para **todos** los
   applets usados por `/init` y la shell de rescate (lista completa, no
   subconjunto fijo).
3. `initramfs/init`: no depender de `sed` obligatorio; tolerar fallos;
   mantener PID 1 vivo y abrir shell de rescate.
