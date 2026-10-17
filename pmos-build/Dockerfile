# Licencia: GPL-3.0-or-later
#
# Imagen de construcción postmarketOS para xiaomi-laurel (Xiaomi Mi A3).
# Se usa SOLO desde GitHub Actions. Adaptada del recetario probado de
# philipplinux/mia3-postmarketos (simple-install/Dockerfile).
#
# alpine:edge fijado por digest (manifest list multi-arquitectura).
FROM alpine:edge@sha256:020dfcbaaf4cc1078bf2d9c7ba31a8466e334061dcd2f248001d68f79e52c000

RUN apk add --no-cache \
        pmbootstrap git sudo bash util-linux e2fsprogs e2fsprogs-extra parted \
        openssl curl tar xz android-tools android-tools-avbtool pil-squasher \
        python3 openssh-client rsync iproute2 clang lld llvm make flex bison \
        openssl-dev bc perl elfutils-dev diffutils linux-headers musl-dev gcc \
        libgcc pahole dtc qemu-user-static \
    && git config --system safe.directory '*' \
    && adduser -D build \
    && printf 'build ALL=(ALL) NOPASSWD: ALL\n' > /etc/sudoers.d/build

# /dev en Docker es un tmpfs que nunca recibe los nodos loopNpM que crea
# `losetup -P`; con un devtmpfs real pmbootstrap deja de generar una imagen
# vacía. También expone /dev/bus/usb si en el futuro se conecta hardware.
RUN printf '#!/bin/sh\nmount -t devtmpfs devtmpfs /dev 2>/dev/null || true\nexec "$@"\n' \
        > /entrypoint.sh \
    && chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
