# Auditoría DTB final v7.1 — USB/display/ramoops

Fuente: DTB de kernel run `31513653872`, validado también al extraer boot v3.
La inspección usa `fdtget` sobre el DTB binario; no depende solo de labels de
la descompilación.

## USB

- PHY real: `/soc@0/phy@1613000`, compatible `qcom,msm8996-qusb2-phy`,
  status okay, clocks/resets y tres supplies presentes.
- Wrapper real: `/soc@0/usb@4ef8800`, compatibles
  `qcom,sm6125-dwc3`/`qcom,dwc3`, status okay, clocks, assigned-clocks,
  interrupts y power-domain presentes.
- Core real: `/soc@0/usb@4ef8800/usb@4e00000`, compatible `snps,dwc3`,
  `phys`→QUSB2, `phy-names=usb2-phy`, `maximum-speed=high-speed`,
  `dr_mode=peripheral`, extcon phandle presente.
- Extcon: `/usb-id`, compatible `linux,extcon-usb-gpio`, `id-gpios` GPIO 102.
- El label downstream `hsusb_phy1` no existe en el DTB final; su equivalente
  efectivo es `phy@1613000`. No es un defecto por sí mismo.
- No hay `vbus-gpios` ni `usb-role-switch`; el objetivo actual es gadget
  periférico, no OTG host.

## Supplies QUSB2

Phandles del PHY resueltos:

- `vdd-supply` → L7A, 872000–976000 uV.
- `vdda-pll-supply` → L10A, 1800000–1896000 uV.
- `vdda-phy-dpdm-supply` → L15A, 3104000–3232000 uV.

La descompilación textual antigua mostró strings corruptos para L15A; `fdtget`

## Display y ramoops

- `chosen/framebuffer@5c000000`: simple-framebuffer 720x1560, stride 2880,
  `a8r8g8b8`.
- `memory@5c000000`: región reservada de 0xf00000; cubre el framebuffer.
- `ramoops@ffc00000`: reg 0xffc40000/0xc0000, record-size 0x1000,
  console-size 0x40000, pmsg-size 0x20000; sin solapamiento conocido.
- Falta `stdout-path`; la consola depende del cmdline.

## Veredicto

El DTB contiene la cadena USB necesaria para gadget periférico. La causa física
de ausencia de UDC sigue pendiente de runtime: el v3 debe distinguir PHY/DWC3
probe, UDC vacío y bind/configfs. No se declara USB ni pantalla `working`.
