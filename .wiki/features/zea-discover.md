# --zea-discover CLI flag

- **Issue**: #42
- **Rama**: main (directo)
- **Estado**: ✅ merged

## Qué se hizo
- Agregado flag `--zea-discover` en `cli/bin/zea-thalamus.js` que expone todos los comandos CLI como JSON
- Recorre recursivamente `program.commands` (incluyendo subcomandos anidados)
- Expone 64 comandos con sus descripciones

## Decisiones clave
- Colocado justo antes de `program.parse()` para que todos los comandos ya estén registrados
- Usa `process.argv.includes()` en vez de `program.option()` para que sea un flag oculto (no aparece en `--help`)
- El output incluye `description: "Identity & Access Management"` para identificación por `zea-cli`

## Archivos modificados
- `cli/bin/zea-thalamus.js`

## Referencias
- Issue #42
- `zea-soma` — implementación de referencia
- `zea-cli/scripts/validate.sh` — consumidor (smoke test dinámico)
