# Licencia: GPL-3.0-or-later
#
# Imagen minima para extraer el firmware propietario del Mi A3 desde el ROM
# oficial: `android-tools` trae simg2img, `pil-squasher` reconstruye
# a610_zap.mbn y el extractor necesita python3 y montar las particiones stock en
# solo-lectura. Se usa SOLO desde GitHub Actions.
#
# alpine:edge fijado por digest (manifest list multi-arquitectura).
FROM alpine:edge@sha256:020dfcbaaf4cc1078bf2d9c7ba31a8466e334061dcd2f248001d68f79e52c000

RUN apk add --no-cache android-tools pil-squasher python3 util-linux

# /dev en Docker es un tmpfs que no recibe los nodos loopNpM que crea el
# montaje de una imagen por fichero; un devtmpfs real lo arregla.
RUN printf '#!/bin/sh\nmount -t devtmpfs devtmpfs /dev 2>/dev/null || true\nexec "$@"\n' \
        > /entrypoint.sh \
    && chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
