# Forense del boot v7.1 fallido

Artefacto auditado: boot pmOS-shell de run `31523494602`, copia completa en
`local-private/diagnostics/v71-failed-pmos-ramdisk/`. No se publica el ramdisk
ni sus datos privados.

## Hechos confirmados

- Header v2, kernel v7.1, DTB v7.1 y ramdisk histórico pmOS extraído.
- El ramdisk contiene `/lib/modules/6.1.0-sm6125/`, `modules.dep`, alias y
  metadatos de módulos del kernel histórico.
- `/init` carga `deviceinfo` e `init_functions.sh`, ejecuta:
  `modprobe -a ${deviceinfo_modules_initfs} usb_f_rndis`.
- `setup_log()` redirige stdout/stderr a `/pmOS_init.log` antes de la mayor
  parte del bring-up; esto explica que la pantalla solo mostrara el inicio.
- El flujo intenta montar proc/sys/configfs/devpts, iniciar mdev/udev,
  configurar USB, montar boot, extraer `initramfs-extra`, localizar
  `pmOS_root`, montar root y ejecutar `switch_root /sysroot /sbin/init`.
- Contiene `kpartx`, `telnetd`, `unudhcpd` y funciones configfs RNDIS.

## Incompatibilidad demostrada

El initramfs fue construido para release `6.1.0-sm6125` y conserva su árbol de
módulos. El kernel v7.1 no puede cargar módulos 6.1 por release/vermagic; los
drivers que no estén built-in quedan ausentes. El ramdisk no es autónomo para
el kernel v7.1.

## Riesgos/hipótesis restantes

- H2 confirmado parcialmente: `modprobe` usa módulos 6.1; su efecto exacto en
  cada función depende de qué drivers v7.1 estén built-in.
- H6/H7 siguen posibles: DWC3/QUSB2 puede no registrar UDC o configfs puede no
  bindear la función; el ramdisk histórico no conserva marcadores/heartbeat.
- H3/H4/H5 no se pueden distinguir desde la pantalla porque el log se mueve a
  `/pmOS_init.log` y no hay canal USB activo.
- H1/H9/H10 siguen sin evidencia runtime: no hubo pstore/USB/UART disponible.

## Corrección aplicada

El workflow 12 construye un initramfs nativo con BusyBox arm64 estático, sin
`/lib/modules/6.1*`, marcadores `V71_*`, heartbeat de 15 s, pstore, diagnóstico
de UFS/fb/UDC y gadget configfs seleccionable. PID 1 no tiene salida normal.

Estado: la causa del ramdisk histórico queda `confirmed`; el siguiente boot
diagnóstico debe separar probe de kernel, UDC y switch_root sin reutilizar
módulos 6.1.
