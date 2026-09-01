# Diferencia entre boot.img y boot-consoleblank0.img

## Objetivo

Demostrar si la única diferencia semántica es `consoleblank=0` y no hay cambios inesperados en kernel, ramdisk ni payload.

## Evidencia

La herramienta del repositorio `scripts/patch-bootimg-cmdline.py` produjo:

```text
header cmdline ANTES : 'clk_ignore_unused'
header cmdline DESPUÉS: 'clk_ignore_unused consoleblank=0'
layout: header@4096 kernel@4096 ramdisk@9428992 second@12406784 dtb@12406784 total=12406784
kernel    sha256=a6c11ca2ce1f33fa5f31019ad5810ce5ac776fcc804c3e58e16842b7cc376197 size=9422366
ramdisk   sha256=c34d6b83b57a296cb8b085d18a53b4033415e6f292fe0a79c79ac0662749e136 size=2974573
OK: solo cambió el cmdline del header; payload byte-idéntico
```

## Resultado

- `boot.img` SHA256: `f5769064303ce077d5fc9377826cd7d78cd43f2bd2dd34401b9dc407e8883402`
- `boot-consoleblank0.img` SHA256: `c344668f74f18927b246dce963f6b939458718d694185e5cbbad07874b3f136b`

## Conclusión

PASS: la diferencia semántica está limitada a `consoleblank=0` en el cmdline del header. No existe evidencia de cambio del kernel, ramdisk ni contenido crítico del payload.
