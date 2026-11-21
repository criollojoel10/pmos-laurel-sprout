# SSH en la tailnet (begonia ↔ laurel ↔ cachyos)

Estado medido el **2026-11-21** tras recuperar laurel:

| nodo | IP Tailscale | usuario | OpenSSH | Tailscale SSH |
|---|---|---|---|---|
| begonia | `100.64.98.119` | `alarm` | ✅ | ✅ |
| laurel | `100.88.248.79` | `user` | ✅ | ✅ |
| cachyos | `100.111.14.21` | `joel` | alias listo | nodo **offline** (última vez hace 1 día) |

## OpenSSH

Claves (solo públicas; las privadas no salen de cada equipo):

- begonia → laurel: `~/.ssh/id_ed25519.pub` de begonia en
  `/home/user/.ssh/authorized_keys` de laurel.
- laurel → begonia: clave ed25519 de laurel en
  `/home/alarm/.ssh/authorized_keys` de begonia.
- `sshd` habilitado en begonia y laurel.

Alias en `~/.ssh/config`:

```sshconfig
# begonia
Host laurel laurel.taile971a.ts.net
    HostName 100.88.248.79
    User user
    IdentityFile ~/.ssh/id_ed25519
    StrictHostKeyChecking accept-new

# laurel
Host begonia begonia.taile971a.ts.net
    HostName 100.64.98.119
    User alarm
    IdentityFile ~/.ssh/id_ed25519
    StrictHostKeyChecking accept-new
```

Uso:

```sh
ssh laurel          # desde begonia
ssh begonia         # desde laurel
```

## Tailscale SSH

`RunSSH` activo en begonia y laurel (`tailscale set --ssh`). No usa claves ni
`sshd`; autentica con la identidad de la tailnet y la ACL.

```sh
# desde begonia
tailscale ssh user@laurel
tailscale ssh user@100.88.248.79

# desde laurel
tailscale ssh alarm@begonia
tailscale ssh alarm@100.64.98.119
```

Verificado en ambos sentidos. Si la ACL de la tailnet no lo permite, el
cliente devuelve `access denied`; se ajusta en el panel de Tailscale
(`ssh` rule).

## cachyos (cuando esté online)

El alias ya está en ambos equipos (`User joel`). Al encenderlo:

```sh
ssh cachyos                    # OpenSSH (requiere la clave pública en cachyos)
ssh-copy-id -i ~/.ssh/id_ed25519.pub cachyos
tailscale ssh joel@cachyos     # Tailscale SSH (si cachyos tiene --ssh activo)
```

No se pudo probar ni activar `tailscale set --ssh` en cachyos porque el nodo
está offline. `ruby` no aparece en `tailscale status`; se añade igual cuando
vuelva a la tailnet.

## Seguridad

- No hay claves privadas, contraseñas ni PSK en el repositorio.
- La contraseña local de laurel es la del perfil (`changeme`); cámbiala.
- `sudo` sin contraseña está activo en laurel por petición del operador.
