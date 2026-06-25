# Implementation Tasks — Auto CORS/CSP al Registrar Cliente

Este documento lista las tareas a implementar, basadas en los documentos de requerimientos y de diseño (02-design.md) actualizados para soportar millones de clientes (ETS + CSP Dinámico).

## Fase 1: Creación de Registro CORS (ETS en Memoria)

- [ ] **1.1 Implementar `Thalamus.CORSRegistry`**
  - Crear archivo `lib/thalamus/application/cors_registry.ex`.
  - Implementar `GenServer` que inicialice la tabla ETS `:cors_origins` en su callback `init/1`.
  - Implementar función `add/1` para agregar un origen con `:ets.insert`.
  - Implementar función hiperrápida `member?/1` que utilice `:ets.lookup` para devolver true/false.
  - Implementar función `all/0`.
  - Implementar función privada `load_origins_from_db/0`.
  - Implementar función `rebuild_from_clients/0`.
  - Actualizar pruebas unitarias (`cors_registry_test.exs` ya completado al 100%).
  
> *(Nota: La tarea 1.2 CSPRegistry ha sido eliminada por diseño).*

## Fase 2: Integración CORS en el Flujo de la Aplicación

- [ ] **2.1 Modificar `Thalamus.Application`**
  - Editar `lib/thalamus/application.ex`.
  - Agregar **solo** `Thalamus.CORSRegistry` al árbol de supervisión.
  - Al arrancar la aplicación, invocar en una `Task` el `rebuild_from_clients/0`.

- [ ] **2.2 Actualizar `OAuth2ClientController`**
  - Editar `lib/thalamus_web/controllers/api/oauth2_client_controller.ex`.
  - Implementar función auxiliar para extraer orígenes y registrarlos.
  - Llamar a la función al crear un cliente con éxito (`create/2`) o agregar redirect URI (`add_redirect_uri/2`).

- [ ] **2.3 Actualizar CORS Plug**
  - Editar `lib/thalamus_web/plugs/cors.ex`.
  - Modificar la evaluación para que primero busque en el entorno estático y, si no lo encuentra, llame a `Thalamus.CORSRegistry.member?(origen_request)`.

## Fase 3: Implementación de CSP Dinámico (Per-Request)

- [ ] **3.1 Actualizar SecurityHeaders Plug**
  - Editar `lib/thalamus_web/plugs/security_headers.ex`.
  - Crear función pública `add_form_action(conn, host)`.
  - La función debe leer el `content-security-policy` existente en el `conn`, insertar `http://{host}:* https://{host}:*` en la directiva `form-action` y actualizar el `conn`.

- [ ] **3.2 Actualizar AuthorizationController**
  - Editar `lib/thalamus_web/controllers/oauth2/authorization_controller.ex`.
  - Crear función privada `extract_host(uri_str)`.
  - En la función `render_consent_screen/2`, extraer el host del `data.redirect_uri`.
  - Llamar a `ThalamusWeb.Plugs.SecurityHeaders.add_form_action(conn, host)`.
  - Renderizar la vista usando el `conn` modificado.

## Fase 4: Pruebas y Validación

- [ ] **4.1 Pruebas de Integración**
  - Escribir pruebas del controlador para validar que al crear un cliente se agreguen correctamente los orígenes CORS.
  - Escribir prueba para el `AuthorizationController` validando la cabecera CSP.

- [ ] **4.2 Validación Manual (E2E)**
  - Levantar el entorno de pruebas local.
  - Verificar respuesta CORS al hacer una solicitud `OPTIONS`.
  - Ingresar a la pantalla de autorización y revisar las cabeceras HTTP para confirmar el `form-action` dinámico.
