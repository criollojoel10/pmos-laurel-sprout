# Auditoría DTB final Linux 6.1 — WCN3990

Artefacto instalado: `boot-linux61-baseline-consoleblank0.img`, run CI
`31563265029`, SHA-256 `41ed6045f5b587f4917fa24e1e00b5710c9e7fab088212ab98f9979a9c4f6056`.
Captura y extracción: `local-private/diagnostics/wifi-priority/baseline-before-wifi-20260812T131500Z/`.

## Hashes y extracción

- Kernel payload con DTB appendado: 9,422,414 B, SHA-256
  `637c94ecd2aeab74dcb1b81f9fed1b5c4b6087895ff711b774817c377fdc2370`.
- DTB extraído del final del payload: 13,536 B, SHA-256
  `cb37540db8e8667c4a850c8da34704003f05e5c84c7761e58f369b18371c690e`.
- `final.dts` generado desde el DTB: SHA-256
  `76543d16401590aa781b0810304db0d0748064f3659ae773b2edd90f05c0ec60`.
- Cmdline efectiva: contiene `consoleblank=0`, `root=...system_b` y
  `skip_initramfs`.

## Hallazgos semánticos

| Elemento | Resultado |
|---|---|
| `wifi`, `wlan`, `wcn`, `wcn3990`, `icnss` | Ausentes del DTB final |
| `wcss`, `remoteproc`, `q6` | Ausentes como nodos Wi-Fi |
| `apps_smmu`, `iommu`, `smmu` | Ausentes del DTB final |
| `memory@53300000` | Presente, `0x200000`; no tiene consumer Wi-Fi |
| `mmc@4744000` | Presente, compatible SDHCI Qualcomm, `status = "disabled"` |
| `mmc@4784000` | Presente, compatible SDHCI Qualcomm, `status = "disabled"` |
| regulators Wi-Fi | No hay consumer node; labels `vreg_l8a/l16a/l17a/l23a` sí existen en DTS de placa |
| `iommus` Wi-Fi | Ausente |
| IRQs 358-369 | No asociadas a un nodo Wi-Fi |

## Veredicto

El nodo Wi-Fi no fue eliminado durante la compilación: no existe en el DTS de
placa 6.1 ni en `sm6125.dtsi` del commit fijado. La reserva de memoria WLAN sí
existe, pero está huérfana. No se debe activar ninguno de los dos MMC como
solución alternativa: la evidencia del transporte SNOC es superior, aunque
pendiente de probe físico.
