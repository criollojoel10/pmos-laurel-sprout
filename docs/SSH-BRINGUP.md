# Guía de bring-up SSH — rootfs histórico 6.1 (M6)

Objetivo: acceso remoto `ssh` al Xiaomi Mi A3 `laurel_sprout` arrancado desde
`system_b` con el rootfs histórico 6.1 endurecido (workflow
`11-build-historical-ssh-rootfs`), a través del gadget USB RNDIS. Es la única
red disponible hoy (sin WiFi/BT funcionales).

Pendiente de autorización FASE 8: ver `docs/PREFLIGHT-M6-SSH-FLASH.md`.

## Requisitos previos

- `xiaomi-laurel-ssh.img` flasheado en `system_b` (slot b) y verificado por
  SHA-256.
- Dispositivo arrancado: consola pmOS en pantalla (getty) y gadget RNDIS
  enumerado (`PMOS_CONSOLE_6_1_BOOTED` ya demostró que el rootfs monta y el
  gadget sale en `172.16.42.1`).
- Clave privada local: `local-private/ssh-laurel/id_ed25519` (NUNCA al repo).

## Clave e identidad (referencia)

- Tipo: `ssh-ed25519`
- Fingerprint (local, = la inyectada en la imagen):
  `SHA256:yXbMctxhVMzfEq40J1Wmb48IXTRvbGLn/ZMohLP7EEM`
- Host user (config pmbootstrap): `pmos`; root: `root` (auth solo por clave).

## Red del host (RNDIS)

En el host Fedora/Ubuntu la interfaz aparece como `enp4s0f3u2` (u2 = puerto).
El teléfono ofrece DHCP (`unudhcpd`) con `172.16.42.1`:

```sh
ip link set enp4s0f3u2 up
ip addr add 172.16.42.2/24 dev enp4s0f3u2 2>/dev/null || true
# o dejar que dhcpcd/NetworkManager configure la interfaz (preferible)
ping -c3 172.16.42.1
```

## Conexión

```sh
ssh -i local-private/ssh-laurel/id_ed25519 \
    -o IdentitiesOnly=yes \
    -o StrictHostKeyChecking=accept-new \
    -o UserKnownHostsFile=/tmp/known_hosts-laurel \
    root@172.16.42.1
```

La primera conexión pedirá confirmar la huella del host. Verificar que la
huella del `authorized_keys` dentro del rootfs coincide con la local (arriba).

## Verificación post-conexión (evidencia esperada)

```sh
id                      # uid=0(root)
hostname                # laziel (config pmbootstrap)
uname -a                # Linux ... 6.1.0-sm6125 ... aarch64
grep -c '^ssh-ed25519' /root/.ssh/authorized_keys
dmesg | grep -iE 'panic|error' | tail -30
tail -20 /var/log/messages
```

Guardar la evidencia en `reports/physical-tests/SSH-M6-BRINGUP/result.md`
siguiendo el patrón de `reports/physical-tests/PMOS-CONSOLE-6_1-BOOTED/`.

## Diagnóstico de fallos esperados

| Síntoma | Causa probable | Acción |
|---|---|---|
| Sin `ping 172.16.42.1` | gadget RNDIS no enumeró / initramfs no trajo la config | reboot; `dmesg` del host (`lsusb`, `dmesg | grep -i rndis`) |
| `Connection refused` | sshd no levantó (red antes que sshd, o falló el endurecido) | verificar `rc-status` de sshd; reintentar tras 30 s |
| `Permission denied (publickey)` | clave no coincide / `authorized_keys` no inyectado | `ssh-keygen -lf` de la pub local vs `grep` en la imagen; re-falshear |
| Huella de host inesperada | la imagen regeneró claves de host | aceptar y documentar (rootfs desechable) |

## Notas de seguridad

- Solo clave pública; `PasswordAuthentication no`,
  `PermitRootLogin prohibit-password` (sshd_config endurecido en el workflow).
- La clave privada vive únicamente en `local-private/ssh-laurel/`. No se
  sube, no se imprime, no se documenta.
