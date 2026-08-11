# Encadenamiento post-rebuild WCN3990 (03 → 04/05)

Secuencia automática a ejecutar cuando la nueva build 03 (con 31a256e + SID
0x80) termine success. NO se ejecuta todavía.

> Estado 2026-08-11: kernel Wi-Fi `31513653872` (HEAD `e1957d3`, SID 0x80)
> terminó success y fue validado (Kconfig + DTB con phandles resueltas).
> Encadenados 04 `31523487558` (diag) y 05 `31523494602` (pmOS-shell),
> ambos success. Boot pmOS-shell final:
> `local-private/boot-31523494602/boot-out/boot-laurel-pmos-shell-v71.img`
> SHA-256 `998df537f4d993d1c3adf9abd2790359553e07cf74ccb3d6da77c74b28d13ec2`.
> Pendiente: prueba física FASE 8 y `dmesg` para confirmar probe ath10k_snoc /
> board-id en board-2.bin.

## 1. Validar kernel-debug (03)

```sh
scripts/validate-kernel-artifact.sh --run-id <RUN_03> --out local-private/<run>-kernel
scripts/validate-wifi-artifact.sh \
  --config local-private/<run>-kernel/kernel-debug/kernel.config \
  --dtb    local-private/<run>-kernel/kernel-debug/sm6125-xiaomi-laurel-sprout.dtb \
  --out    local-private/<run>-kernel/wifi
```

Comprueba Kconfig (ATH10K/SMEM/QMI/SCM/POWER_SEQUENCING/QRTR) y nodo DTB
`wifi@c800000` con SID 0x80, MSA, IRQ 358-369 y supplies.

## 2. Boot diagnóstico con el nuevo kernel (04)

```sh
gh workflow run 04-build-diagnostic-boot.yml \
  --ref main --field kernel_artifact_run_id=<RUN_03>
```

## 3. Boot pmOS shell (05) con el nuevo kernel

```sh
gh workflow run 05-build-pmos-shell-v71.yml \
  --ref main --field kernel_artifact_run_id=<RUN_03> \
  --field rootfs_artifact_run_id=31355730519 \
  --field skip_initramfs=false
```

## 4. Verificación final del boot (05)

- `sha256sum -c SHA256SUMS`.
- Extraer boot final: kernel/ramdisk/DTB hashes idénticos.
- Cmdline: `root=PARTUUID=dd9c45fe-41b1-02a1-ed69-58eb218e5043 rootwait ro
  init=/init console=tty0 consoleblank=0`, SIN `skip_initramfs`.
- DTB conserva `framebuffer@5c000000` y `wifi@c800000`.

## 5. Parada

No lanzar prueba física automáticamente. Preparar FASE 8 con run IDs, SHA-256
y comando `fastboot flash boot_b <boot-laurel-pmos-shell-v71.img>` (preparado,
no ejecutado). Tras boot, capturar `dmesg` y comprobar:
- `ath10k_snoc` probe;
- `qcom,wcn3990-wifi` bind;
- mensaje `board-2.bin` (¿board-id de laurel presente?);
- presencia de `wlan0`.
