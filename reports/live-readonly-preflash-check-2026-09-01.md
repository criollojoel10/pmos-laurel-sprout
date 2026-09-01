# Verificación de solo lectura del dispositivo vivo

## Acceso

Se utilizó SSH en modo solo lectura a `root@172.16.42.1` usando la clave local y sin ninguna operación de escritura.

## Datos obtenidos

```text
Linux laziel 6.1.0-sm6125 #1-postmarketos-qcom-sm6125 SMP PREEMPT Mon Aug 31 21:16:57 UTC aarch64 Linux
cmdline: clk_ignore_unused ... skip_initramfs rootwait ro init=/init
```

## Observaciones clave

- `/dev/fb0` existe.
- `/sys/class/drm` está vacío.
- `/dev/dri` no existe.
- `/sys/class/input` está vacío.
- `/sys/class/usb_role` no aparece.
- `/sys/kernel/debug/usb/4e00000.usb/mode` informa `device`.
- No existe `xHCI` ni árbol host USB.
- El cmdline actual no contiene `consoleblank=0`.

## Interpretación

La base Linux 6.1 sigue arrancando y siendo accesible por SSH, pero el estado actual es solo simple-framebuffer y gadget USB. No hay evidencia de DRM/KMS, touch o OTG host activos.
