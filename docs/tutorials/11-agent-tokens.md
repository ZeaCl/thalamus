# Tutorial: Agent Tokens para Agentes de IA

**Basado en el código real de Thalamus** | Última actualización: 2026-01-23

Los Agent Tokens son tokens OAuth2 especializados para agentes de IA con características avanzadas de seguridad, trazabilidad y compliance.

---

## 📋 Tabla de Contenidos

1. [¿Qué son los Agent Tokens?](#1-qué-son-los-agent-tokens)
2. [Análisis del Código Real](#2-análisis-del-código-real)
3. [Casos de Uso](#3-casos-de-uso)
4. [Implementación Paso a Paso](#4-implementación-paso-a-paso)
5. [Características Avanzadas](#5-características-avanzadas)
6. [Validación y Monitoreo](#6-validación-y-monitoreo)
7. [Compliance y Auditoría](#7-compliance-y-auditoría)
8. [Ejemplos Prácticos](#8-ejemplos-prácticos)

---

## 1. ¿Qué son los Agent Tokens?

### 1.1 Definición

Agent Tokens son tokens OAuth2 especializados que añaden:

✅ **Task-Scoping**: Tokens limitados a tareas específicas
✅ **Delegation Tracking**: Cadena completa de autorización humano → agente
✅ **Operation Limits**: Máximo número de operaciones permitidas
✅ **Auto-Revocación**: Se revocan automáticamente al completar la tarea
✅ **Compliance**: Audit trails completos (EU AI Act Article 13)
✅ **Performance**: Caché Redis con latencia < 3ms

### 1.2 Diferencias con Tokens Normales

| Característica | Token OAuth2 Normal | Agent Token |
|----------------|---------------------|-------------|
| Scopes | Global del cliente | Task-scoped (subset) |
| Delegación | No rastreada | Cadena completa |
| Límites | Solo tiempo | Tiempo + operaciones |
| Auto-revocación | No | Sí (opcional) |
| Auditoría | Básica | Completa (compliance) |
| Usuario | Humano | Agente de IA |

### 1.3 Tipos de Agentes

**Del código:** `lib/thalamus/domain/value_objects/agent_type.ex`

```elixir
@valid_types [:autonomous, :supervisor, :tool]

# autonomous - Opera independientemente sin aprobación humana por acción
# supervisor - Requiere aprobación humana para acciones críticas
# tool - Herramienta de corta duración para ejecución de tarea única
```

---

## 2. Análisis del Código Real

### 2.1 Endpoint del Agent Token

**Archivo:** `lib/thalamus_web/controllers/oauth2/agent_token_controller.ex`

```elixir
# POST /oauth/agent-token

def create(conn, params) do
  # 1. Verifica que la feature esté habilitada (feature flag)
  if FeatureFlags.agent_tokens_enabled?() do
    # 2. Construye AgentTokenRequest desde params
    request = build_request(params)

    # 3. Ejecuta el use case GenerateAgentToken
    case GenerateAgentToken.execute(request, @deps) do
      {:ok, response} ->
        # Retorna token con metadata adicional
        json(response)

      {:error, error} ->
        # Manejo de errores específicos de agentes
        handle_error(conn, error)
    end
  else
    # Feature deshabilitada - retorna 404
    json(%{error: "not_found"})
  end
end
```

### 2.2 Use Case: GenerateAgentToken

**Archivo:** `lib/thalamus/application/use_cases/generate_agent_token.ex`

```elixir
def execute(%AgentTokenRequest{} = request, deps) do
  with :ok <- AgentTokenRequest.validate(request),
       # 1. Autentica el cliente OAuth2
       {:ok, client} <- authenticate_client(request, deps),

       # 2. Valida que el delegator (humano) existe y está activo
       {:ok, delegator} <- validate_delegator(request, deps),

       # 3. Parsea y valida agent_type
       {:ok, agent_type} <- parse_agent_type(request),

       # 4. Valida task_scopes son subset de client.allowed_scopes
       {:ok, task_scopes} <- validate_task_scopes(request, client),

       # 5. Verifica que el delegator tiene los scopes solicitados
       :ok <- validate_delegator_has_scopes(delegator, task_scopes, deps),

       # 6. Construye la delegation chain
       {:ok, delegation_chain} <- build_delegation_chain(delegator),

       # 7. Genera el token con toda la metadata
       {:ok, token_data} <- build_token_data(...),

       # 8. Guarda en BD
       :ok <- deps.token_repository.store(token_data),

       # 9. Log de auditoría
       :ok <- log_agent_token_creation(token_data, deps) do

    # Retorna respuesta
    {:ok, %AgentTokenResponse{...}}
  end
end
```

### 2.3 Campos Adicionales en la Base de Datos

**Migración:** `priv/repo/migrations/*_add_agent_token_fields.exs`

```elixir
alter table(:tokens) do
  # Identidad del Agente
  add :agent_type, :string                              # "autonomous" | "supervisor" | "tool"
  add :delegated_by_user_id, references(:users)         # Quién autorizó
  add :delegation_chain, {:array, :binary_id}           # Cadena completa

  # Task Scoping
  add :task_id, :string                                 # ID de la tarea
  add :task_type, :string                               # Tipo de tarea
  add :task_scopes, {:array, :string}                   # Scopes específicos
  add :max_operations, :integer                         # Límite de operaciones
  add :operations_count, :integer, default: 0           # Contador actual
  add :expires_on_completion, :boolean                  # Auto-revocar

  # Compliance
  add :intent_description, :text                        # Descripción del intent
  add :orchestrator_id, :string                         # ID del orchestrator
  add :environment, :string                             # "production" | "staging"
end
```

### 2.4 Validación de Scopes

**Del código real:**

```elixir
defp validate_task_scopes(%{task_scopes: task_scopes}, client) do
  # Los task_scopes DEBEN ser un subset de client.allowed_scopes
  allowed_scope_strings = Enum.map(client.allowed_scopes, &to_string/1)

  # Valida cada scope
  invalid = Enum.filter(task_scopes, fn scope ->
    scope not in allowed_scope_strings
  end)

  if Enum.empty?(invalid) do
    {:ok, task_scopes}
  else
    {:error, {:invalid_task_scopes, invalid}}
  end
end
```

---

## 3. Casos de Uso

### 3.1 Agente Autónomo con Límite de Operaciones

**Escenario:** Un agente de IA que procesa facturas automáticamente, máximo 100 facturas por sesión.

```json
{
  "client_id": "invoice_processor_client",
  "client_secret": "secret_xyz",
  "delegated_by_user_id": "user_admin_123",
  "agent_type": "autonomous",
  "task_id": "process_invoices_batch_456",
  "task_type": "invoice_processing",
  "scope": "invoices:read invoices:update",
  "max_operations": 100,
  "expires_on_completion": true,
  "intent_description": "Process pending invoices for Q1 2026"
}
```

### 3.2 Agente Supervisor (Requiere Aprobación)

**Escenario:** Un agente que puede leer datos pero requiere aprobación humana para modificar.

```json
{
  "client_id": "data_agent_client",
  "client_secret": "secret_abc",
  "delegated_by_user_id": "user_supervisor_789",
  "agent_type": "supervisor",
  "task_id": "data_analysis_task_123",
  "scope": "data:read",
  "max_operations": 50,
  "intent_description": "Analyze customer data for marketing campaign"
}
```

### 3.3 Tool Agent (Efímero)

**Escenario:** Una herramienta de corta duración para ejecutar una tarea específica.

```json
{
  "client_id": "tool_client",
  "client_secret": "secret_def",
  "delegated_by_user_id": "user_developer_456",
  "agent_type": "tool",
  "task_id": "export_report_789",
  "scope": "reports:read",
  "expires_in": 300,
  "expires_on_completion": true,
  "intent_description": "Export monthly sales report"
}
```

---

## 4. Implementación Paso a Paso

### 4.1 Verificar Feature Flag

**Del código:**

```elixir
# lib/thalamus/feature_flags.ex
def agent_tokens_enabled?() do
  Application.get_env(:thalamus, :enable_agent_tokens, false)
end
```

**Activar en config:**

```elixir
# config/dev.exs
config :thalamus,
  enable_agent_tokens: true
```

### 4.2 Crear OAuth2 Client para Agentes

```bash
curl -X POST http://localhost:4000/api/clients \
  -H "Authorization: Bearer YOUR_ADMIN_JWT" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "AI Agent Service",
    "organization_id": "org_uuid",
    "client_type": "confidential",
    "redirect_uris": [],
    "grant_types": ["client_credentials"],
    "scopes": ["api:read", "api:write", "data:read", "data:write"]
  }'
```

**Guarda el `client_id` y `client_secret`**

### 4.3 Obtener Agent Token

```bash
curl -X POST http://localhost:4000/oauth/agent-token \
  -H "Content-Type: application/json" \
  -d '{
    "client_id": "agent_client_abc123",
    "client_secret": "secret_xyz789",
    "delegated_by_user_id": "user_admin_uuid",
    "agent_type": "autonomous",
    "task_id": "task_20260123_001",
    "task_type": "data_processing",
    "scope": "api:read data:read",
    "max_operations": 100,
    "expires_on_completion": true,
    "intent_description": "Process customer data for ML training",
    "orchestrator_id": "orchestrator_prod_01",
    "expires_in": 3600
  }'
```

**Respuesta:**

```json
{
  "access_token": "at_agent_abc123def456xyz789...",
  "token_type": "Bearer",
  "expires_in": 3600,
  "scope": "api:read data:read",
  "agent_type": "autonomous",
  "task_id": "task_20260123_001",
  "max_operations": 100,
  "expires_on_completion": true
}
```

### 4.4 Usar el Agent Token

```bash
curl -H "Authorization: Bearer at_agent_abc123def456xyz789..." \
  http://localhost:4000/api/data
```

**Cada request incrementa `operations_count`**

### 4.5 Validar Agent Token

```bash
curl -X POST http://localhost:4000/oauth/introspect \
  -H "Content-Type: application/json" \
  -d '{
    "token": "at_agent_abc123def456xyz789..."
  }'
```

**Respuesta incluye metadata del agente:**

```json
{
  "active": true,
  "scope": "api:read data:read",
  "client_id": "agent_client_abc123",
  "user_id": "user_admin_uuid",
  "sub": "user_admin_uuid",
  "token_type": "Bearer",
  "exp": 1706000000,
  "iat": 1705996400,

  // Metadata del Agente
  "agent_type": "autonomous",
  "delegated_by": "user_admin_uuid",
  "delegation_chain": ["user_admin_uuid"],
  "delegation_depth": 1,
  "task_id": "task_20260123_001",
  "task_type": "data_processing",
  "task_scopes": ["api:read", "data:read"],
  "max_operations": 100,
  "operations_remaining": 73,
  "expires_on_completion": true,
  "intent_description": "Process customer data for ML training",
  "orchestrator_id": "orchestrator_prod_01",
  "environment": "production"
}
```

---

## 5. Características Avanzadas

### 5.1 Auto-Revocación al Completar Tarea

**Del código:**

```elixir
# Cuando operations_count >= max_operations
if token.expires_on_completion and token.operations_count >= token.max_operations do
  # Auto-revocar el token
  revoke_token(token)

  # Log de auditoría
  log_auto_revocation(token, "max_operations_reached")
end
```

**En tu aplicación:**

```javascript
async function processWithAgentToken(token, items) {
  let processed = 0;

  for (const item of items) {
    try {
      await processItem(item, token);
      processed++;
    } catch (error) {
      if (error.status === 401 && error.message.includes('operations_remaining: 0')) {
        console.log('Token auto-revoked after completing max operations');
        break;
      }
      throw error;
    }
  }

  return processed;
}
```

### 5.2 Delegation Chain

**Del código:**

```elixir
# Construye la cadena de delegación
defp build_delegation_chain(delegator) do
  # [user_admin] -> [user_supervisor] -> [agent]
  chain = [delegator.id]

  # Validar profundidad máxima
  if length(chain) > @max_delegation_depth do
    {:error, :delegation_chain_too_deep}
  else
    {:ok, DelegationChain.new(chain)}
  end
end
```

**Uso en multi-agent:**

```
Human (user_admin)
  ↓ delega a
Supervisor Agent (agent_supervisor_01)
  ↓ delega a
Worker Agent (agent_worker_01)

delegation_chain: [user_admin, agent_supervisor_01, agent_worker_01]
delegation_depth: 3
```

### 5.3 Caché de Validaciones

**Del código:** `lib/thalamus/application/use_cases/cached_validate_token.ex`

```elixir
# Usa Redis para cachear validaciones
# Cache key: "token_validation:#{token_hash}"
# TTL: hasta expiración del token
# Reduce latencia: 10-20ms → < 3ms (85% reducción)

def execute(token, deps) do
  cache_key = "token_validation:#{hash(token)}"

  case deps.cache_service.get(cache_key) do
    {:ok, cached_result} ->
      # Hit de caché - retorno inmediato
      {:ok, cached_result}

    {:error, :not_found} ->
      # Miss de caché - validar y cachear
      case validate_token(token, deps) do
        {:ok, result} ->
          deps.cache_service.set(cache_key, result, ttl: result.ttl)
          {:ok, result}

        error -> error
      end
  end
end
```

---

## 6. Validación y Monitoreo

### 6.1 Verificar Estado del Token

```javascript
async function checkAgentTokenStatus(token) {
  const response = await fetch('http://localhost:4000/oauth/introspect', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ token })
  });

  const data = await response.json();

  if (data.active) {
    console.log('Token activo');
    console.log('Operaciones restantes:', data.operations_remaining);
    console.log('Expira en:', new Date(data.exp * 1000));
    console.log('Tipo de agente:', data.agent_type);
    console.log('Tarea:', data.task_id);
  } else {
    console.log('Token inactivo o revocado');
  }

  return data;
}
```

### 6.2 Monitorear Uso de Operaciones

```javascript
class AgentTokenManager {
  constructor(token) {
    this.token = token;
    this.operationsUsed = 0;
    this.maxOperations = null;
  }

  async initialize() {
    const status = await this.checkStatus();
    this.maxOperations = status.max_operations;
    this.operationsUsed = status.max_operations - status.operations_remaining;
  }

  async checkStatus() {
    const response = await fetch('http://localhost:4000/oauth/introspect', {
      method: 'POST',
      body: JSON.stringify({ token: this.token })
    });
    return response.json();
  }

  async executeOperation(operation) {
    if (this.operationsUsed >= this.maxOperations) {
      throw new Error('Max operations reached');
    }

    try {
      const result = await operation(this.token);
      this.operationsUsed++;
      return result;
    } catch (error) {
      if (error.status === 401) {
        // Token revocado
        console.log('Token revoked');
      }
      throw error;
    }
  }

  getRemainingOperations() {
    return this.maxOperations - this.operationsUsed;
  }
}
```

---

## 7. Compliance y Auditoría

### 7.1 Audit Logs Automáticos

**Del código:**

```elixir
defp log_agent_token_creation(token_data, deps) do
  deps.audit_logger.log(%{
    event_type: "agent_token_created",
    user_id: token_data.delegated_by_user_id,
    resource_type: "agent_token",
    resource_id: token_data.token_id,
    metadata: %{
      agent_type: token_data.agent_type,
      task_id: token_data.task_id,
      task_scopes: token_data.task_scopes,
      max_operations: token_data.max_operations,
      intent_description: token_data.intent_description,
      orchestrator_id: token_data.orchestrator_id
    },
    timestamp: DateTime.utc_now()
  })
end
```

### 7.2 EU AI Act Compliance

Los Agent Tokens cumplen con **EU AI Act Article 13** (transparencia):

✅ **Identificación**: `agent_type`, `task_id`
✅ **Trazabilidad**: `delegation_chain`, `delegated_by`
✅ **Propósito**: `intent_description`, `task_type`
✅ **Límites**: `max_operations`, `task_scopes`
✅ **Auditoría**: Logs inmutables de creación y uso

### 7.3 Consultar Audit Logs

```bash
# Ver todos los agent tokens creados por un usuario
curl -X GET "http://localhost:4000/api/audit-logs?event_type=agent_token_created&user_id=user_admin_uuid" \
  -H "Authorization: Bearer ADMIN_JWT"
```

---

## 8. Ejemplos Prácticos

### 8.1 Ejemplo Completo: Python con LangChain

```python
import requests
from typing import Optional

class ThalamusAgentAuth:
    def __init__(self, base_url: str, client_id: str, client_secret: str):
        self.base_url = base_url
        self.client_id = client_id
        self.client_secret = client_secret
        self.current_token: Optional[str] = None
        self.max_operations: Optional[int] = None
        self.operations_used: int = 0

    def get_agent_token(
        self,
        delegated_by_user_id: str,
        agent_type: str,
        task_id: str,
        scopes: list[str],
        max_operations: int = 100,
        intent: str = ""
    ) -> str:
        """Obtiene un agent token de Thalamus."""

        response = requests.post(
            f"{self.base_url}/oauth/agent-token",
            json={
                "client_id": self.client_id,
                "client_secret": self.client_secret,
                "delegated_by_user_id": delegated_by_user_id,
                "agent_type": agent_type,
                "task_id": task_id,
                "scope": " ".join(scopes),
                "max_operations": max_operations,
                "expires_on_completion": True,
                "intent_description": intent
            }
        )
        response.raise_for_status()

        data = response.json()
        self.current_token = data["access_token"]
        self.max_operations = data["max_operations"]
        self.operations_used = 0

        return self.current_token

    def execute_with_token(self, operation_func):
        """Ejecuta una operación con el token, incrementando el contador."""

        if not self.current_token:
            raise ValueError("No token available. Call get_agent_token first.")

        if self.operations_used >= self.max_operations:
            raise ValueError("Max operations reached")

        try:
            result = operation_func(self.current_token)
            self.operations_used += 1
            return result
        except requests.HTTPError as e:
            if e.response.status_code == 401:
                print("Token revoked or expired")
            raise

    def get_remaining_operations(self) -> int:
        """Retorna operaciones restantes."""
        return self.max_operations - self.operations_used

# Uso
auth = ThalamusAgentAuth(
    base_url="http://localhost:4000",
    client_id="agent_client_123",
    client_secret="secret_xyz"
)

# Obtener token para el agente
token = auth.get_agent_token(
    delegated_by_user_id="user_admin_uuid",
    agent_type="autonomous",
    task_id="ml_training_batch_456",
    scopes=["data:read", "models:write"],
    max_operations=50,
    intent="Train ML model on customer data"
)

# Ejecutar operaciones
for i in range(50):
    def fetch_data(token):
        response = requests.get(
            "http://localhost:4000/api/data",
            headers={"Authorization": f"Bearer {token}"}
        )
        return response.json()

    data = auth.execute_with_token(fetch_data)
    print(f"Operation {i+1}/50 - Remaining: {auth.get_remaining_operations()}")

print("All operations completed. Token auto-revoked.")
```

### 8.2 Ejemplo: Node.js con Express

```javascript
const express = require('express');
const axios = require('axios');

class AgentTokenService {
  constructor(thalamusUrl, clientId, clientSecret) {
    this.thalamusUrl = thalamusUrl;
    this.clientId = clientId;
    this.clientSecret = clientSecret;
  }

  async createAgentToken({
    delegatedByUserId,
    agentType,
    taskId,
    scopes,
    maxOperations,
    intent
  }) {
    const response = await axios.post(
      `${this.thalamusUrl}/oauth/agent-token`,
      {
        client_id: this.clientId,
        client_secret: this.clientSecret,
        delegated_by_user_id: delegatedByUserId,
        agent_type: agentType,
        task_id: taskId,
        scope: scopes.join(' '),
        max_operations: maxOperations,
        expires_on_completion: true,
        intent_description: intent
      }
    );

    return response.data;
  }

  async validateAgentToken(token) {
    const response = await axios.post(
      `${this.thalamusUrl}/oauth/introspect`,
      { token }
    );

    return response.data;
  }
}

// Express app
const app = express();
app.use(express.json());

const agentService = new AgentTokenService(
  'http://localhost:4000',
  process.env.CLIENT_ID,
  process.env.CLIENT_SECRET
);

// Endpoint para crear tarea de agente
app.post('/api/agent-tasks', async (req, res) => {
  const { userId, taskDescription, maxOps } = req.body;

  try {
    const agentToken = await agentService.createAgentToken({
      delegatedByUserId: userId,
      agentType: 'autonomous',
      taskId: `task_${Date.now()}`,
      scopes: ['api:read', 'data:process'],
      maxOperations: maxOps || 100,
      intent: taskDescription
    });

    res.json({
      token: agentToken.access_token,
      taskId: agentToken.task_id,
      maxOperations: agentToken.max_operations,
      expiresIn: agentToken.expires_in
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.listen(3000);
```

---

## 📚 Próximos Pasos

- **Performance**: Los agent tokens usan caché Redis (< 3ms latency)
- **Seguridad**: Delegation chain previene escalación de privilegios
- **Compliance**: Audit logs listos para EU AI Act
- **Monitoreo**: Telemetry events para observabilidad

## 🔗 Referencias del Código

- `lib/thalamus_web/controllers/oauth2/agent_token_controller.ex`
- `lib/thalamus/application/use_cases/generate_agent_token.ex`
- `lib/thalamus/domain/value_objects/agent_type.ex`
- `lib/thalamus/domain/value_objects/delegation_chain.ex`
- `docs/AGENT_TOKEN_TECHNICAL_SPEC.md`

**Última revisión del código:** 2026-01-23
