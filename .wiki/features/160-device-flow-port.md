# Device flow — verification_uri con :80 (#160)

- **Issue**: #160
- **Rama**: fix/issue-160-device-flow-port
- **PR**: #161
- **Estado**: ✅ PR abierto (fix síntoma) / ⏳ pendiente fix raíz en infra

## Qué se hizo
- `build_verification_uri/1` ahora omite el puerto cuando `public_port` (o `conn.port`) es 80/443.
- Tests de regresión nuevos para el device flow (`device_controller_test.exs`, no existía).

## Decisiones clave
- El fix defensivo (capa código) ya estaba aplicado sin commitear en el working tree; se formalizó con test + PR.
- No se cambió `runtime.exs` porque su lógica es correcta: el fix raíz es setear `FORCE_SSL=true` en prod (infra), no tocar el default.

## Causa raíz
- `config/runtime.exs` calcula `public_port=80` y `scheme=http` cuando `FORCE_SSL` no está en el env de prod.
- El device controller detecta `https` vía `x-forwarded-proto` pero usaba ese `public_port=80` → `https://auth.zea.cl:80`.

## Archivos modificados
- `lib/thalamus_web/controllers/oauth2/device_controller.ex`
- `test/thalamus_web/controllers/oauth2/device_controller_test.exs` (nuevo)

## Pendiente (fix raíz, fuera de este repo)
- Setear `FORCE_SSL=true` en el env de prod de Thalamus (zea-cicd/infra).
- Ver `skill/SKILL.md` → checklist pre-deploy.

## Referencias
- [Issue #160](https://github.com/ZeaCl/thalamus/issues/160)
- [PR #161](https://github.com/ZeaCl/thalamus/pull/161)
