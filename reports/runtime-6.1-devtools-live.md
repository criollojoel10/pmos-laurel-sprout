# Runtime pmOS 6.1 devtools — sesión física en vivo

Fecha: 2026-09-01. pmOS 6.1 (v22.12.2) corriendo en el Xiaomi Mi A3
(`laurel_sprout`/`laziel`), flasheado con el run 21 (`33434873426`).
Acceso: `ssh root@172.16.42.1` (RNDIS USB, clave
`local-private/devkeys/id_ed25519`).

Estado honrado de los componentes (ver FASE 8 / AGENTS.md §2):
`boot-untested` → se reconoce que el 6.1 arranca y se usa como entorno de
trabajo; la clasificación global sigue en `partially-working` (display tiene
blanking pendiente de fix físico; OTG host sin validar; internet vía USB
depende de NAT en el host).

---

## 1. Conectividad de red al pmOS (RNDIS) — resuelta

### Problema detectado

- El pmOS tenía la ruta local `172.16.0.0/16` por `usb0`, pero **sin gateway
  por defecto**.
- `ping 8.8.8.8` → `Network unreachable`.
- DNS stub `127.0.0.53` (systemd-resolved) → `Connection refused` (no había
  servicio DNS levantado para el host).
- Por eso `apk update` fallaba con "temporary error" en los 3 repos.

### Causa raíz

El gadget RNDIS solo da red con la laptop (`172.16.42.2`); la laptop **no
enrutaba/NAT** el tráfico del USB hacia `wlan0`, por lo que el pmOS no tenía
salida a internet.

### Solución aplicada

En la **laptop** (host Fedora), con sudo:

```
sysctl -w net.ipv4.ip_forward=1
iptables -t nat -A POSTROUTING -s 172.16.42.0/24 -o wlan0 -j MASQUERADE
iptables -A FORWARD -i enp4s0f3u2 -o wlan0 -j ACCEPT
iptables -A FORWARD -i wlan0 -o enp4s0f3u2 -m state --state RELATED,ESTABLISHED -j ACCEPT
```

En el **pmOS**:

```
ip route add default via 172.16.42.2 dev usb0
printf "nameserver 1.1.1.1\nnameserver 8.8.8.8\n" > /etc/resolv.conf
```

### Verificación

- `ping 8.8.8.8` desde el pmOS: 2/2, ~22 ms.
- DNS resuelve `dl-cdn.alpinelinux.org`.
- `apk update` → `OK: 18130 distinct packages available`.

> Nota de persistencia: la ruta default y el NAT son **volátiles** (no se
> persisten en el pmOS ni en el host). Al reconectar el USB o reiniciar, hay
> que rehacerlos. Documentar como paso de arranque si se quiere reproducción.

## 2. Actualización de paquetes (apk upgrade)

- Repos: `postmarketos/v22.12`, `alpine/v3.17/main`, `alpine/v3.17/community`.
- `apk update` OK (18130 paquetes).
- `apk upgrade --no-progress` → `OK: 560 MiB in 321 packages`. Sin cambios que
  rompan el arranque (el rootfs siguió funcionando).

## 3. Pantalla — apagado a los ~5 min (blanking de consola)

### Síntoma observado en esta sesión

- La consola pmOS aparece visible al arrancar.
- A los ~5 minutos la pantalla se apaga (queda negra), de forma recurrente.
- El sistema sigue vivo (SSH/red intactos).

### Causa raíz (confirmada en `reports/physical-tests/DISPLAY-SCREENOFF-6_1/result.md`)

- No hay `consoleblank` en el cmdline del boot.img actual (run 21: solo
  `clk_ignore_unused`).
- El blanking de consola fbcon (default 600 s) expira, `fbcon_blank` no tiene
  `fb_blank` en simplefb → limpia el framebuffer a negro.
- Como no hay input devices, ningún evento despierta la consola → queda negra.

### Fix preparado (NO flasheado aún)

- `scripts/patch-bootimg-cmdline.py` generó `boot-consoleblank0.img` añadiendo
  `consoleblank=0`:
  - cmdline ANTES:  `clk_ignore_unused`
  - cmdline DESPUÉS: `clk_ignore_unused consoleblank=0`
  - kernel/ramdisk **byte-idénticos** (header v0, misma estructura).
  - sha256 `boot-consoleblank0.img` = `c344668f74f18927b246dce963f6b939458718d694185e5cbbad07874b3f136b`
  - Tamaño 12,406,784 B, cabe en `boot_b` (64 MiB).
- **Pendiente FASE 8**: autorización explícita para `fastboot flash boot_b`.

## 4. USB OTG host — pendiente de validación

Estado previo conocido (diagnóstico anterior):
- `/sys/bus/usb/devices/` vacío (sin árbol host).
- `/sys/class/udc/4e00000.usb` registrada (gadget RNDIS).
- `CONFIG_USB_DWC3_DUAL_ROLE=y`, `CONFIG_USB_OTG=y`,
  `CONFIG_USB_XHCI_PLATFORM=y`.

Siguiente paso: verificar el rol actual del DWC3/xHCI y probar físicamente
teclado y dongle TP-Link (USB Ethernet) para confirmar OTG host.

## 5. Plan de migración al kernel 7.1 (contexto)

- El workflow `03-build-kernel.yml` → `reusable-build-kernel.yml` produce
  `Image`, `Image.gz`, `System.map`, `kernel.config`, `modules.tar.zst`,
  `dtb.tar.zst` (NO boot.img).
- Último run exitoso: `33038035387`, artefacto `kernel-debug` (67 MB).
- Problema conocido: el pipeline de display del 7.1 (DPU/DSI/panel) da
  **pantalla negra** en hardware
  (`reports/physical-tests/H61-KERNEL-7_1-BLACKSCREEN/result.md`).
- Falta: entender cómo empaquetar el 7.1 como boot.img instalable e instalar
  los módulos en el rootfs, resolviendo antes el display (probablemente
  `DRM_NOMODESET=y` para no derribar simplefb).

## 6. Artefactos relevantes (run 21)

- `local-private/linux61-dev/export-resolved/boot.img`
  sha256 `f5769064303ce077d5fc9377826cd7d78cd43f2bd2dd34401b9dc407e8883402`
- `local-private/linux61-dev/export-resolved/boot-consoleblank0.img`
  sha256 `c344668f74f18927b246dce963f6b939458718d694185e5cbbad07874b3f136b`
- `local-private/linux61-dev/artifacts/xiaomi-laurel-ssh-final.img`
  sha256 `19fbe7bf…` (flasheado en system_b)

## 7. Riesgos / no tocar

- No tocar `system_b`, `vbmeta_b`, `dtbo_b` ni cambiar de slot.
- El boot.img **actual** del run 21 es el estado funcional conocido; el
  `boot-consoleblank0.img` solo cambia cmdline y es el rollback/aplicable
  para el fix de pantalla.
- El NAT/ruta del host y del pmOS son volátiles; no confiar en ellos sin
  rehacerlos.
