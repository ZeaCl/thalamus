# OAuth2 Client Secret Rotation

**Guía para rotar secrets de OAuth2 clients**

---

## 🔍 Problema Común

Si creaste un OAuth2 client con `client_secret` en texto plano en la base de datos, tendrás errores 401 porque Thalamus espera que el secret esté **hasheado con Bcrypt**.

**Síntoma:**
```json
{
  "error": "invalid_client",
  "error_description": "Client authentication failed"
}
```

---

## ✅ Solución Rápida: UPDATE en BD

Si ya tienes un cliente con secret en texto plano, usa este UPDATE:

### Paso 1: Generar el hash Bcrypt

**Opción A: Usar IEx (Elixir)**

```bash
# Conectar a IEx en el servidor de Thalamus
iex -S mix

# Hashear el secret
iex> Bcrypt.hash_pwd_salt("tu_secret_actual")
"$2b$12$<tu_hash_generado>"
```

**Opción B: Usar Python**

```python
import bcrypt

secret = b"tu_secret_actual"
hash = bcrypt.hashpw(secret, bcrypt.gensalt(rounds=12))
print(hash.decode('utf-8'))
# $2b$12$<tu_hash_generado>
```

**Opción C: Usar Node.js**

```javascript
const bcrypt = require('bcrypt');

const secret = "tu_secret_actual";
const hash = bcrypt.hashSync(secret, 12);
console.log(hash);
// $2b$12$<tu_hash_generado>
```

### Paso 2: UPDATE en PostgreSQL

```sql
-- Reemplaza <tu_hash_generado> con el hash del Paso 1
UPDATE oauth2_clients
SET client_secret = '$2b$12$<tu_hash_generado>'
WHERE client_id_string = 'tu_client_id';

-- Verificar
SELECT client_id_string,
       LEFT(client_secret, 20) as secret_prefix,
       LENGTH(client_secret) as secret_length
FROM oauth2_clients
WHERE client_id_string = 'tu_client_id';
```

**El hash Bcrypt debe:**
- Empezar con `$2b$12$`
- Tener ~60 caracteres de longitud
- Ser diferente cada vez que hasheas el mismo secret

### Paso 3: Verificar

```bash
curl -X POST http://localhost:4000/oauth/token \
  -H "Content-Type: application/json" \
  -d '{
    "grant_type": "authorization_code",
    "code": "<authorization_code>",
    "client_id": "tu_client_id",
    "client_secret": "tu_secret_actual",
    "redirect_uri": "https://tu-app.com/callback"
  }'
```

---

## 🔄 Rotar Secret via API (Implementación Futura)

**Estado actual:** ❌ No implementado

### Implementación Propuesta

**Endpoint:** `POST /api/clients/:id/rotate-secret`

**Request:**
```bash
curl -X POST http://localhost:4000/api/clients/<client_id>/rotate-secret \
  -H "Authorization: Bearer <admin_jwt_token>" \
  -H "Content-Type: application/json"
```

**Response:**
```json
{
  "data": {
    "client_id": "client_abc123",
    "client_secret": "<nuevo_secret_en_texto_plano>",
    "message": "⚠️ Save the new client_secret securely. It cannot be retrieved later."
  }
}
```

**Código de implementación:**

```elixir
# En lib/thalamus_web/router.ex
scope "/api", ThalamusWeb.API do
  pipe_through :authenticated_api

  resources "/clients", OAuth2ClientController, except: [:new, :edit] do
    post "/rotate-secret", OAuth2ClientController, :rotate_secret
  end
end

# En lib/thalamus_web/controllers/api/oauth2_client_controller.ex
def rotate_secret(conn, %{"client_id" => id}) do
  with {:ok, client_id} <- ClientId.from_string(id),
       {:ok, client} <- PostgreSQLOAuth2ClientRepository.find_by_id(client_id),
       {:ok, updated_client} <- OAuth2Client.rotate_secret(client),
       # Capturar el secret ANTES de guardarlo (se hashea al guardar)
       plain_secret <- extract_plain_secret(updated_client.client_secret),
       {:ok, saved_client} <- PostgreSQLOAuth2ClientRepository.save(updated_client) do

    conn
    |> put_status(:ok)
    |> json(%{
      data: %{
        client_id: ClientId.to_string(saved_client.id),
        client_secret: plain_secret,
        rotated_at: DateTime.utc_now()
      },
      message: "⚠️ Save the new client_secret securely. It cannot be retrieved later."
    })
  else
    {:error, :cannot_rotate_public_client_secret} ->
      conn
      |> put_status(:bad_request)
      |> json(%{error: "Public clients do not have secrets"})

    {:error, :not_found} ->
      conn
      |> put_status(:not_found)
      |> json(%{error: "Client not found"})

    {:error, reason} ->
      conn
      |> put_status(:internal_server_error)
      |> json(%{error: "Failed to rotate secret", details: inspect(reason)})
  end
end

defp extract_plain_secret(%ClientSecret{} = secret) do
  # El secret ya está generado pero aún no hasheado
  # Necesitamos extraer el plain secret antes de que se hashee
  # NOTA: Esta función necesita implementación en ClientSecret VO
  ClientSecret.get_plain(secret)
end
```

**Nota:** La implementación completa requiere modificar `ClientSecret` value object para exponer el secret en texto plano antes del hashing.

---

## 🔐 Seguridad

### ⚠️ Advertencias

1. **NUNCA** guardes secrets en texto plano en la BD
2. **NUNCA** commits secrets en git (usa `.env`)
3. **NUNCA** expongas el secret después de la creación inicial
4. **SIEMPRE** usa HTTPS en producción para transmitir secrets

### ✅ Mejores Prácticas

1. **Rotación regular:** Rota secrets cada 90 días
2. **Secrets manager:** Usa AWS Secrets Manager, HashiCorp Vault, etc.
3. **Auditoría:** Registra todas las rotaciones de secrets
4. **Revocación inmediata:** Si un secret se compromete, rótalo inmediatamente

---

## 📚 Referencias

- [OAuth2 Client Secret Hashing](../../lib/thalamus/domain/value_objects/client_secret.ex)
- [OAuth2 Client Repository](../../lib/thalamus/infrastructure/repositories/postgresql_oauth2_client_repository.ex)
- [OAuth2 Client Entity](../../lib/thalamus/domain/entities/oauth2_client.ex)

---

## 🆘 Troubleshooting

### Error: "Client authentication failed"

**Causa:** El `client_secret` en la BD está en texto plano, no hasheado.

**Solución:** Ejecuta el UPDATE en BD con el hash Bcrypt del secret.

### Error: "Invalid hash"

**Causa:** El hash Bcrypt es inválido o está corrupto.

**Solución:** Regenera el hash usando Bcrypt con rounds=12.

### Pregunta: "¿Puedo usar el mismo secret después de rotarlo?"

**Respuesta:** No. Cuando rotas el secret, el anterior se invalida. Debes actualizar todas las aplicaciones que usen ese client.

---

## 📞 Soporte

- **Issues:** [GitHub Issues](https://github.com/zea/thalamus/issues)
- **Discussions:** [GitHub Discussions](https://github.com/zea/thalamus/discussions)
