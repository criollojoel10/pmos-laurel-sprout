# Audio

Estado: **integrado en el build** (altavoz inferior). Pendiente de prueba
física del artefacto de `26-build-kupfer`; el procedimiento se validó sobre
hardware el 2026-10-13 en el port de referencia
(`philipplinux/mia3-postmarketos`, GPL-2.0).

## Qué funciona (altavoz inferior)

- **ADSP (LPASS)** arrancado en runtime con el overlay `mia3-adsp.dtbo`
  (`qcom,sm6115-adsp-pas`, glink `lpass`, smp2p).
- **APR/Q6**: `q6core`, `q6afe` (+clocks), `q6asm`, `q6adm`, `q6routing`
  (`CONFIG_SND_SOC_QDSP6=m`), cargados tras aplicar `mia3-apr.dtbo`.
- **Tarjeta `Mi-A3`**: machine driver `snd-soc-sm8250`
  (`qcom,qrb4210-rb2-sndcard`), enlace `SEC_MI2S_RX` (GPIO125-128) a un codec
  dummy `linux,spdif-dit` (`CONFIG_SND_SOC_SPDIF=m`).
- **Amplificador MAX98937** en `i2c-1` @ `0x3a`: no hay driver mainline; se
  programa desde userspace (`max98937-init.sh`, `i2c-tools`). El DT stock lo
  llama `max98927`, pero el driver de mainline escribe registros incorrectos.
- **Volumen/ganancia**: `/var/lib/mia3-audio/{volume,gain}` (0..127 =
  -16..+15.75 dB; ganancia del altavoz en pasos de 3 dB).

## Dónde vive

| Pieza | Ruta |
|---|---|
| Overlays (`dtc`, sin `-@`) | `kupfer-overlay/device/mia3-support/mia3-{adsp,apr,speaker}.dts` |
| Cargador de overlays + módulo ADSP | `kupfer-overlay/linux/sm61x5/mia3_{dtbo,adsp}.c` (en `linux-sm61x5`) |
| Secuencia y amp | `kupfer-overlay/device/mia3-support/{bringup.sh,max98937-init.sh}` |
| Unidad | `mia3-audio.service` (oneshot, tras `mia3-qg.service`) |

## Orden que no se puede alterar

1. `mia3_adsp.ko` aplica `mia3-adsp.dtbo` y crea `smp2p-adsp`.
2. `mia3-apr.dtbo` añade el bus APR; se cargan los módulos Q6; se **reinicia**
   el ADSP para que exponga `apr_audio_svc`.
3. `mia3-speaker.dtbo` crea la tarjeta y el codec dummy; se carga
   `snd-soc-sm8250`; `max98937-init.sh` programa el amp.

Gotchas (heredados y verificados): un overlay solo se aplica una vez por
arranque; el SMMU del `q6asm` usa el stream **0x41** (no el 0x1c1 de sm6115);
las rutas de q6routing van después de los widgets de q6asm; el enable global
del amp solo engancha mientras corre BCLK (se hace durante 1 s de silencio).

## Pendiente

- Auricular y micrófonos: WCD937x + LPASS RX/TX + SoundWire, **not-targeted**.
- Cámara, módem/llamadas: prioridad secundaria.
