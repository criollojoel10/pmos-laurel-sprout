# Último resultado físico display/USB v7.1

## Identidad de imagen

El repositorio contiene preflights para v2 y v3, pero no una anotación física
contemporánea que vincule inequívocamente el resultado más reciente con un
SHA/artefacto concreto. Por tanto, el resultado físico es aplicable como mínimo
a v2; queda pendiente confirmar si v3 fue la imagen probada.

## Resultado confirmado

- Se observaron logs largos del kernel.
- La pantalla terminó negra.
- Fedora no detectó dispositivo USB, `usb0` ni `rndis0`.
- `172.16.42.1`, telnet y SSH no respondieron.
- No existe evidencia suficiente de panic/oops ni de que `/init` haya sido
  alcanzado.

## Interpretación

El ramdisk pmOS histórico usado por el boot shell sí tenía módulos 6.1 y
redirigía la mayor parte del log a `/pmOS_init.log`; eso está demostrado en
`reports/v71-failed-boot-initramfs-audit.md`. La v3 separó el initramfs y la
v4 añade checkpoints visuales directos, `panic=0`, buffers de color y
heartbeat antes de USB. Ninguna imagen se clasifica `working` sin prueba.
