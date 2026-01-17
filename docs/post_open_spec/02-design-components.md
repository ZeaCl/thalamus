# Component Design
## Thalamus: Identity Server for the Agentic Economy

[← Back to Index](02-design-index.md)

---

## Domain Layer Components

### AgentToken Entity

```elixir
defmodule Thalamus.Domain.Entities.AgentToken do
  @moduledoc """
  Domain entity representing an agent's access token with delegation metadata.

  SOLID Principles:
  - Single Responsibility: Only represents agent token state
  - Open/Closed: Extensible via protocols
  """

  alias Thalamus.Domain.ValueObjects.{AgentType, TaskId, DelegationChain, AccessToken, Scope}

  @type t :: %__MODULE__{
    id: String.t(),
    access_token: AccessToken.t(),
    agent_type: AgentType.t(),
    task_id: TaskId.t(),
    delegation_chain: DelegationChain.t() | nil,
    scopes: [Scope.t()],
    reason: String.t() | nil,
    expires_at: DateTime.t(),
    revoked_at: DateTime.t() | nil,
    organization_id: String.t(),
    client_id: String.t()
  }

  defstruct [:id, :access_token, :agent_type, :task_id, :delegation_chain, :scopes, :reason, :expires_at, :revoked_at, :organization_id, :client_id]

  def create(attrs), do: # Validation logic
  def revoke(%__MODULE__{} = token), do: %{token | revoked_at: DateTime.utc_now()}
  def active?(%__MODULE__{} = token), do: not revoked?(token) and not expired?(token)
end
```

### Value Objects

**AgentType** - Valid types: autonomous, supervisor, tool
```elixir
defmodule Thalamus.Domain.ValueObjects.AgentType do
  @valid_types ~w(autonomous supervisor tool)
  @type t :: %__MODULE__{value: String.t()}
  defstruct [:value]

  def new(type) when type in @valid_types, do: {:ok, %__MODULE__{value: type}}
  def new(_invalid), do: {:error, :invalid_agent_type}
end
```

**DelegationChain** - Tracks parent-child relationships
```elixir
defmodule Thalamus.Domain.ValueObjects.DelegationChain do
  @max_depth 5

  @type t :: %__MODULE__{
    parent_token_id: String.t() | nil,
    depth: non_neg_integer(),
    path: [String.t()]
  }

  defstruct [:parent_token_id, :depth, :path]

  def new(parent_token_id, parent_chain \\ nil) do
    # Validate depth < 5
  end

  def exceeds_max_depth?(%__MODULE__{depth: depth}), do: depth >= @max_depth
end
```

**TaskId** - UUID validation
```elixir
defmodule Thalamus.Domain.ValueObjects.TaskId do
  @type t :: %__MODULE__{value: String.t()}
  defstruct [:value]

  def new(value) do
    case Ecto.UUID.cast(value) do
      {:ok, uuid} -> {:ok, %__MODULE__{value: uuid}}
      :error -> {:error, :invalid_task_id}
    end
  end
end
```

---

## Application Layer Components

### GenerateAgentToken Use Case

```elixir
defmodule Thalamus.Application.UseCases.GenerateAgentToken do
  @moduledoc """
  Generates an ephemeral token for an AI agent with delegation chain tracking.

  SOLID Principles:
  - Single Responsibility: Only handles agent token generation workflow
  - Dependency Inversion: Depends on AgentTokenRepository port
  """

  @type deps :: %{
    agent_token_repository: module(),
    oauth2_client_repository: module(),
    delegation_validator: module(),
    cache_service: module(),
    audit_logger: module()
  }

  @spec execute(AgentTokenRequest.t(), deps()) :: {:ok, map()} | {:error, atom()}
  def execute(%AgentTokenRequest{} = request, deps) do
    with {:ok, client} <- fetch_client(request.client_id, deps),
         :ok <- validate_scopes(request.scopes, client.allowed_scopes),
         {:ok, delegation_chain} <- validate_delegation(request, deps),
         {:ok, agent_token} <- create_agent_token(request, delegation_chain, client),
         {:ok, saved_token} <- save_token(agent_token, deps),
         :ok <- cache_token(saved_token, deps),
         :ok <- log_token_issuance(saved_token, request.reason, deps) do
      {:ok, to_response(saved_token)}
    end
  end

  defp validate_delegation(%{parent_agent_id: nil}, _deps), do: {:ok, nil}
  defp validate_delegation(%{parent_agent_id: parent_id}, deps) do
    deps.delegation_validator.validate(parent_id)
  end
end
```

### AgentTokenRepository Port

```elixir
defmodule Thalamus.Application.Ports.AgentTokenRepository do
  @moduledoc """
  Port for agent token persistence operations.

  SOLID Principles:
  - Interface Segregation: Small, focused interface
  - Dependency Inversion: Application defines contract
  """

  @callback save(AgentToken.t()) :: {:ok, AgentToken.t()} | {:error, term()}
  @callback find_by_id(String.t()) :: {:ok, AgentToken.t()} | {:error, :not_found}
  @callback find_by_access_token(String.t()) :: {:ok, AgentToken.t()} | {:error, :not_found}
  @callback revoke(String.t()) :: {:ok, AgentToken.t()} | {:error, term()}
  @callback revoke_delegation_chain(String.t()) :: {:ok, non_neg_integer()} | {:error, term()}
  @callback find_by_organization(String.t(), keyword()) :: {:ok, [AgentToken.t()]} | {:error, term()}
end
```

---

## Infrastructure Layer Components

### PostgreSQL Agent Token Repository

```elixir
defmodule Thalamus.Infrastructure.Repositories.PostgresqlAgentTokenRepository do
  @moduledoc """
  PostgreSQL implementation of AgentTokenRepository port.

  SOLID Principles:
  - Single Responsibility: Only handles agent token persistence
  - Liskov Substitution: Honors AgentTokenRepository contract
  """

  @behaviour Thalamus.Application.Ports.AgentTokenRepository

  @impl true
  def save(%AgentToken{} = token) do
    changeset = to_changeset(token)
    case Repo.insert_or_update(changeset) do
      {:ok, schema} -> {:ok, to_domain(schema)}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @impl true
  def revoke_delegation_chain(parent_token_id) do
    # Uses PostgreSQL JSON operators for efficient querying
    query = """
    UPDATE agent_tokens
    SET revoked_at = NOW()
    WHERE metadata->>'delegation_chain'->>'parent_token_id' = $1
      AND revoked_at IS NULL
    """

    case Repo.query(query, [parent_token_id]) do
      {:ok, %{num_rows: count}} -> {:ok, count}
      {:error, reason} -> {:error, reason}
    end
  end
end
```

### ETS Cache Adapter (High Performance)

```elixir
defmodule Thalamus.Infrastructure.Adapters.ETSCacheAdapter do
  @moduledoc """
  ETS-based cache adapter for sub-millisecond token lookups.

  Performance: Read ~0.5ms (vs Redis ~3ms), Write ~0.1ms
  Trade-off: Cache invalidation requires Phoenix.PubSub for multi-node consistency
  """

  use GenServer

  @table_name :thalamus_token_cache
  @default_ttl :timer.minutes(5)

  def init(_) do
    :ets.new(@table_name, [:named_table, :set, :public, read_concurrency: true])
    {:ok, %{}}
  end

  @spec get(String.t()) :: {:ok, term()} | {:error, :not_found}
  def get(key) do
    case :ets.lookup(@table_name, key) do
      [{^key, value, expires_at}] ->
        if DateTime.compare(DateTime.utc_now(), expires_at) == :lt do
          {:ok, value}
        else
          :ets.delete(@table_name, key)
          {:error, :not_found}
        end
      [] -> {:error, :not_found}
    end
  end

  @spec put(String.t(), term(), non_neg_integer()) :: :ok
  def put(key, value, ttl \\ @default_ttl) do
    expires_at = DateTime.add(DateTime.utc_now(), ttl, :millisecond)
    :ets.insert(@table_name, {key, value, expires_at})
    :ok
  end

  @spec invalidate(String.t()) :: :ok
  def invalidate(key) do
    :ets.delete(@table_name, key)
    # Broadcast invalidation to other nodes via Phoenix.PubSub
    Phoenix.PubSub.broadcast(Thalamus.PubSub, "cache:invalidation", {:invalidate, key})
    :ok
  end
end
```

---

## Presentation Layer Components

### Agent Token Controller

```elixir
defmodule ThalamusWeb.OAuth2.AgentTokenController do
  use ThalamusWeb, :controller

  @deps %{
    agent_token_repository: Thalamus.Infrastructure.Repositories.PostgresqlAgentTokenRepository,
    oauth2_client_repository: Thalamus.Infrastructure.Repositories.PostgresqlOAuth2ClientRepository,
    delegation_validator: Thalamus.Application.Services.DelegationChainValidator,
    cache_service: Thalamus.Infrastructure.Adapters.ETSCacheAdapter,
    audit_logger: Thalamus.Infrastructure.Adapters.AuditLoggerImpl
  }

  def create(conn, params) do
    with {:ok, request} <- build_request(params),
         {:ok, response} <- GenerateAgentToken.execute(request, @deps) do
      conn
      |> put_status(:ok)
      |> json(response)
    else
      {:error, :invalid_scope} ->
        conn
        |> put_status(:forbidden)
        |> json(%{
          error: %{
            code: "invalid_scope",
            message: "The requested scopes exceed the client's allowed scopes",
            documentation_url: "https://docs.thalamus.io/errors/invalid_scope"
          }
        })

      {:error, :max_delegation_depth_exceeded} ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          error: %{
            code: "max_delegation_depth_exceeded",
            message: "Delegation chain cannot exceed 5 levels",
            documentation_url: "https://docs.thalamus.io/errors/delegation_depth"
          }
        })
    end
  end
end
```

### MCP Gateway Component

```elixir
defmodule Thalamus.MCP.Gateway do
  @moduledoc """
  MCP Gateway that intercepts agent-to-MCP connections and enforces OAuth2.

  Security Properties:
  1. No static API keys stored in MCP servers
  2. Scoped tokens per agent (isolation)
  3. Token revocation cascades to all MCP sessions
  4. Audit trail of all tool invocations
  """

  use GenServer

  def intercept_connection(agent_id, mcp_server_url) do
    GenServer.call(__MODULE__, {:intercept, agent_id, mcp_server_url})
  end

  @impl true
  def handle_call({:intercept, agent_id, mcp_server_url}, _from, state) do
    case fetch_token_for_agent(agent_id) do
      {:ok, token} ->
        {:reply, {:ok, proxy_connection(agent_id, mcp_server_url, token)}, state}
      {:error, :no_token} ->
        {:reply, {:error, :authorization_required}, state}
    end
  end

  defp proxy_connection(agent_id, mcp_server_url, token) do
    # Start proxy process that:
    # 1. Forwards MCP stdio messages
    # 2. Injects Authorization header on every request
    # 3. Validates scopes before forwarding tool invocations
  end
end
```

---

[← Back to Index](02-design-index.md) | [Next: Database →](02-design-database.md)
