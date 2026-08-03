# Layout de boot image para laurel_sprout (A/B)

Generado: 2026-08-03

Particiones relevantes (metadatos reales del dispositivo):

```text
boot   (64 MiB, has-slot) -> kernel + ramdisk + DTB
dtbo   (24 MiB, has-slot) -> overlays DTBO (NO se modificará)
vbmeta (64 KiB, has-slot) -> verified boot (NO se modificará)
```

Estrategia no destructiva (ver docs/NON-DESTRUCTIVE-BOOT.md):

- boot.img v2+ con DTB integrado (QCDT) para arranque sin partición dtbo
- usar `fastboot boot` para prueba en RAM (NO escribir flash)
- lk2nd habilita boot de mainline desde boot_a sin tocar dtbo/vbmeta

Riesgo: si el bootloader exige dtbo, el DTB en boot.img (QCDT) debe
coincidir con el índice del dispositivo. Se valida con boot-image
convencional (Android) antes de probar mainline.
