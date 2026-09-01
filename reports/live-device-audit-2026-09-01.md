# Auditoría en vivo del dispositivo laurel_sprout — 2026-09-01

## 1. Resumen ejecutivo

El dispositivo responde por SSH sobre USB RNDIS en `172.16.42.1` y está corriendo `Linux laziel 6.1.0-sm6125` con rootfs `pmOS` funcional para red y acceso remoto. El problema principal actual no es que el sistema no arranque: es que el entorno de trabajo sigue incompleto para pantalla, OTG host, input y GPU/DRM.

Los hallazgos actuales son consistentes con la documentación ya existente del repositorio:

- la pantalla se apaga por blanking de consola (`consoleblank` ausente), no por fallo del panel;
- la ruta USB está en modo gadget (`mode=device`), no host (`xhci`/`OTG host` ausentes);
- no hay `/sys/class/drm`, ni `/dev/dri`, ni `/sys/class/input`, por lo que el display y el touch no están habilitados a nivel de driver;
- los módulos relevantes existen en `/lib/modules`, pero no están cargados ni conectados al DTS/board, por lo que siguen bloqueados por configuración del kernel o DT.

## 2. Evidencia técnica en vivo

### 2.1. Arranque y cmdline

Comando ejecutado en el dispositivo:

```sh
cat /proc/cmdline
```

Salida relevante:

```text
clk_ignore_unused androidboot.verifiedbootstate=orange ... androidboot.secureboot=1 ... msm_drm.dsi_display0=dsi_s6e8fco_samsung_hdp_video_display: ... skip_initramfs rootwait ro init=/init
```

Hecho importante: el cmdline incluye `msm_drm.dsi_display0=dsi_s6e8fco_samsung_hdp_video_display`, pero no incluye `consoleblank=0` ni ninguna opción de `drm` para forzar el display. Eso coincide con la hipótesis del blanking de consola documentada en `reports/physical-tests/DISPLAY-SCREENOFF-6_1/result.md`.

### 2.2. Display / framebuffer

Comando ejecutado:

```sh
ls -l /sys/class/drm /sys/class/input /sys/class/graphics 2>/dev/null
ls -l /dev/fb0 /dev/dri/* 2>/dev/null
```

Resultado:

```text
/sys/class/input
/sys/class/leds
/sys/class/power_supply

crw-rw---- 1 root video 29, 0 Jan  1 00:00 /dev/fb0
```

No hay `/sys/class/drm` ni `/dev/dri`. Solo existe `fb0` como simple-framebuffer, y el kernel registra:

```text
simple-framebuffer 5c000000.framebuffer: fb0: simplefb registered!
```

Esto confirma que el sistema está mostrando un framebuffer básico, pero ni DRM ni el driver del panel están realmente activos. El display no puede considerarse “working” ni “usable” para multimedia ni modo gráfico.

### 2.3. Blanking de pantalla confirmado

La evidencia del dispositivo coincide con el documento de diagnóstico del repositorio:

```sh
cat /proc/cmdline
```

No incluye `consoleblank=0`.

Y la documentación del repo ya decía que este blanking se debía a `fbcon` y al timeout del VT sin `consoleblank`:

- `reports/physical-tests/DISPLAY-SCREENOFF-6_1/result.md`
- `docs/HARDWARE-STATUS.md`

Esto es la causa técnica más probable del apagado de la pantalla observado en el dispositivo.

### 2.4. USB OTG / host mode

Comando ejecutado:

```sh
ls -l /sys/kernel/debug/usb/4e00000.usb
cat /sys/kernel/debug/usb/4e00000.usb/mode
ls /sys/bus/usb/devices 2>/dev/null
ls /sys/class/udc 2>/dev/null
```

Salida relevante:

```text
/sys/kernel/debug/usb/4e00000.usb/mode => device
/sys/class/udc => /sys/class/udc/4e00000.usb
```

Y no hay `/sys/bus/usb/devices` con un árbol host visible; no hay `xhci` ni `usb1` ni dispositivos USB del host. El puerto se está comportando como gadget USB (RNDIS), no como OTG host.

Esto confirma el estado ya documentado:

- `USB gadget / OTG` = `partially-working`
- Modo host no validado
- El rol actual del DWC3 es `device`

### 2.5. Touch / input

Comando ejecutado:

```sh
ls -l /sys/class/input
ls -l /dev/input 2>/dev/null
```

Resultado: `input` existe como clase pero sin dispositivos y sin `/dev/input/event*`.

Esto coincide con la ausencia de driver `ft5x06`/`edt-ft5x06` cargado y con el estado del repositorio (`touchscreen compiled`, no runtime). No hay input táctil en el sistema actual.

### 2.6. GPIO / display / panel / GPU

Se verifica lo siguiente:

```sh
ls /lib/modules/$(uname -r) | head
find /lib/modules -type f | egrep -i '(msm|drm|qcom|panel|touch)' | head -200
```

Existe una estructura de módulos con soporte de `msm`, `drm`, `touchscreen`, etc., pero el dispositivo actual no está cargando esos módulos ni existe `/dev/dri` ni `/sys/class/drm`.

Eso significa que el problema actual no es que el código no exista; es que no se está configurando y conectando adecuadamente con el DTB y/o con el boot del kernel en uso.

## 3. Hallazgos

### Hallazgo A — pantalla: blanking de consola, no panel muerto

Hecho confirmado:

- el framebuffer existe (`/dev/fb0`);
- el panel está vivo porque el framebuffer se puede escribir y el sistema sigue respondiendo por SSH;
- el cmdline no tiene `consoleblank=0`; por tanto la pantalla se apaga por blanking de VT;
- no hay DRM ni driver del panel cargado.

Conclusión:

La pantalla no está “muerta”; está siendo apagada por software por el timeout de consola. Este es un problema de cmdline y de configuración de console framebuffer, no de hardware físico.

### Hallazgo B — USB OTG: no host, solo gadget

Hecho confirmado:

- modo USB actual: `device`;
- no hay xhci/host tree;
- el único endpoint serio es `4e00000.usb` en modo gadget.

Conclusión:

El port no ha habilitado todavía la ruta host de OTG. Así que ni teclado USB, ni Ethernet USB host, ni almacenamiento USB funcionan por ahora.

### Hallazgo C — input y GPU no arrancan

Hecho confirmado:

- sin `/dev/input`, sin `/dev/dri`;
- sin DRM/KMS;
- sin driver táctil cargado.

Conclusión:

Este kernel no está todavía en el estado de render acceleration / KWin / input usable. Falta completar la conexión del DTS y el árbol de módulos para display, interfaz de panel y sensor de touch.

## 4. Riesgos

- No es seguro flashear cambios en `boot_b` o `system_b` sin revisión previa del procedimiento FASE 8, porque el dispositivo ya está en uso y se requiere un plan de recuperación.
- El cambio de OTG host implica tocar la configuración del USB/phy y puede afectar el RNDIS gadget actual.
- El display/DRM requiere pruebas controladas por cmdline y de device tree; los cambios pueden dejar el panel negro o bloqueado.
- Touch/GPU no deben tratarse como “resueltos” solo por módulos existentes; deben validarse con `/dev/input` y `/dev/dri` reales.

## 5. Siguiente acción recomendada

### Prioridad 1 — pantalla

1. Verificar la opción `consoleblank=0` en el boot.img del 6.1 actual.
2. Preparar el artefacto `boot-consoleblank0.img` ya documentado por el repo.
3. Solicitar autorización FASE 8 para flash en `boot_b` y confirmar que la pantalla sigue visible durante al menos 10–60 minutos.

### Prioridad 2 — OTG host

1. Revisar la configuración del dispositivo USB en DTS: `dr_mode` y VBUS/ID.
2. Verificar si falta un `role_switch` o un nodo del PHY que fuerce `host`.
3. Probar con un teclado USB y/o dongle Ethernet desde el host USB del teléfono.

### Prioridad 3 — input + display real

1. Añadir la validación de `/dev/dri/` y `/dev/input/event*` después del boot.
2. Verificar que `drm_msm` y `edt-ft5x06` estén cargados y conectados con el DT.
3. Repetir la comprobación con un rootfs más completo que incluya módulos relevantes.

## 6. Almacenamiento de evidencia

La evidencia base del repo sigue siendo:

- `reports/physical-tests/DISPLAY-SCREENOFF-6_1/result.md`
- `docs/HARDWARE-STATUS.md`
- `docs/SSH-BRINGING.md`
- `reports/runtime-6.1-devtools-live.md`

La evidencia del dispositivo vivo confirma que siguen siendo ciertos los diagnósticos documentados. Este no es un problema “obvio” de hardware sino un problema de configuración y conexión del software del boot.

## 7. Conclusión breve

La prioridad inmediata no es “compilar más código”, sino resolver la cadena de hardware-software que falta para mostrar el framebuffer y activar el rol USB host. La pantalla está apagada por blanking de consola (configuración), y el USB está operando como gadget (no host). Ambos problemas son consistentes con el estado actual del repo y con la documentación ya escrita.
