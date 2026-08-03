# Fix: zea-thalamus login usa puerto aleatorio → invalid redirect_uri

- **Issue**: #147
- **Rama**: main (fix directo)
- **Estado**: ✅ fix aplicado, pendiente code review

## Qué se hizo
- Cambiar `server.listen(0)` → `server.listen(4005)` en `cli/src/lib/client.js`
- El puerto 4005 ya está registrado en la whitelist de redirect URIs del client "Thalamus CLI" en Thalamus

## Decisiones clave
- Se usa puerto fijo 4005 en vez de aleatorio, que ya está en la whitelist: `{http://localhost:4005/callback, http://localhost:3000/callback}`
- No se requiere migración ni cambio en Thalamus — solo en el CLI

## Archivos modificados
- `cli/src/lib/client.js` — línea 201: `server.listen(0, ...)` → `server.listen(4005, ...)`

## Errores encontrados
- `server.listen(0)` → puerto aleatorio → redirect_uri no registrada → `{"error":"invalid_request","error_description":"Invalid redirect_uri"}`

## Referencias
- Reportado originalmente en [zea-cli#28](https://github.com/ZeaCl/zea-cli/issues/28) (mal direccionado)
- Fix en [thalamus#147](https://github.com/ZeaCl/thalamus/issues/147)
