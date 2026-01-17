# System Architecture
## Thalamus: Identity Server for the Agentic Economy

[← Back to Index](02-design-index.md)

---

## 1. High-Level Architecture

```mermaid
graph TB
    subgraph "Client Layer"
        A[AI Agent]
        B[Human User Browser]
        C[External Service]
    end

    subgraph "Presentation Layer (ThalamusWeb)"
        D[OAuth2 Controllers]
        E[Agent Token Controller]
        F[Dashboard LiveView]
        G[API Controllers]
        H[Session Controller]
    end

    subgraph "Application Layer"
        I[GenerateTokens UseCase]
        J[GenerateAgentToken UseCase]
        K[ValidateToken UseCase]
        L[CachedValidateToken UseCase]
        M[RevokeToken UseCase]
        N[AuthenticateUser UseCase]
    end

    subgraph "Domain Layer"
        O[OAuth2Client Entity]
        P[User Entity]
        Q[Organization Entity]
        R[Token Value Objects]
        S[Agent Value Objects]
    end

    subgraph "Infrastructure Layer"
        T[PostgresqlTokenRepository]
        U[PostgresqlAgentTokenRepository]
        V[RedisCacheAdapter]
        W[ETSCacheAdapter]
        X[AuditLoggerImpl]
    end

    subgraph "Data Layer"
        Y[(PostgreSQL 16)]
        Z[(ETS Cache)]
        AA[(Redis - Optional)]
    end

    A --> E
    B --> F
    B --> H
    C --> D

    D --> I
    E --> J
    D --> K
    D --> M
    H --> N
    F --> G

    I --> O
    I --> R
    J --> S
    J --> R
    K --> L
    L --> W

    T --> Y
    U --> Y
    W --> Z
    V --> AA
    X --> Y

    I -.->|depends on port| T
    J -.->|depends on port| U
    L -.->|depends on port| W
```

---

## 2. Request Flow: M2M Token Generation (<5ms p99)

```mermaid
sequenceDiagram
    participant Agent
    participant Controller as OAuth2TokenController
    participant UseCase as GenerateTokens
    participant Cache as ETSCacheAdapter
    participant Repo as PostgresqlTokenRepository
    participant DB as PostgreSQL
    participant Audit as AuditLogger

    Agent->>Controller: POST /oauth/token<br/>(client_credentials)
    activate Controller

    Controller->>Cache: get_client(client_id)
    activate Cache
    Cache-->>Controller: {:ok, cached_client} [~0.5ms]
    deactivate Cache

    Controller->>UseCase: execute(request, deps)
    activate UseCase

    UseCase->>UseCase: validate_client_secret<br/>(constant-time compare)
    UseCase->>UseCase: generate_access_token<br/>(:crypto.strong_rand_bytes)

    UseCase->>Repo: save_token(token)
    activate Repo
    Repo->>DB: INSERT INTO tokens
    DB-->>Repo: {:ok, token} [~2ms]
    deactivate Repo

    UseCase->>Cache: put_token(token)
    activate Cache
    Cache-->>UseCase: :ok [~0.1ms]
    deactivate Cache

    UseCase-->>Controller: {:ok, token_response}
    deactivate UseCase

    Controller->>Audit: log_event(:token_issued)
    Note over Audit: Async, non-blocking

    Controller-->>Agent: 200 OK<br/>{access_token, expires_in}
    deactivate Controller

    Note over Agent,Controller: Total latency: ~3ms (p50), ~5ms (p99)
```

---

## 3. Request Flow: Agent Token with Delegation Chain

```mermaid
sequenceDiagram
    participant Agent as AI Agent
    participant Controller as AgentTokenController
    participant UseCase as GenerateAgentToken
    participant Validator as DelegationChainValidator
    participant Cache as ETSCacheAdapter
    participant Repo as AgentTokenRepository
    participant Audit as AuditLogger

    Agent->>Controller: POST /oauth/agent-token<br/>{agent_type, task_id,<br/>parent_agent_id, scopes, reason}
    activate Controller

    Controller->>UseCase: execute(request, deps)
    activate UseCase

    alt Has parent_agent_id
        UseCase->>Validator: validate_delegation(parent_agent_id)
        activate Validator
        Validator->>Cache: get_token(parent_agent_id)
        Cache-->>Validator: {:ok, parent_token}
        Validator->>Validator: check_active?
        Validator->>Validator: check_delegation_depth < 5
        Validator-->>UseCase: {:ok, validated}
        deactivate Validator
    end

    UseCase->>UseCase: validate_scopes(requested, allowed)
    UseCase->>UseCase: generate_agent_token<br/>(embed: agent_type, task_id,<br/>delegation_chain)

    UseCase->>Repo: save_agent_token(token)
    Repo-->>UseCase: {:ok, token} [~2ms]

    UseCase->>Cache: put_token(token)
    Cache-->>UseCase: :ok [~0.1ms]

    UseCase-->>Controller: {:ok, token_response}
    deactivate UseCase

    Controller->>Audit: log_event(:agent_token_issued,<br/>%{reason: reason, task_id: task_id})

    Controller-->>Agent: 200 OK<br/>{access_token, agent_metadata}
    deactivate Controller

    Note over Agent,Controller: Latency: ~4ms (p50), ~6ms (p99)<br/>Slightly higher due to delegation validation
```

---

## 4. Clean Architecture Layer Mapping

```mermaid
graph LR
    subgraph "Domain Layer (Pure Business Logic)"
        D1[Entities/<br/>AgentToken]
        D2[Value Objects/<br/>AgentType]
        D3[Value Objects/<br/>DelegationChain]
        D4[Value Objects/<br/>TaskId]
    end

    subgraph "Application Layer (Use Cases)"
        A1[Ports/<br/>AgentTokenRepository]
        A2[Use Cases/<br/>GenerateAgentToken]
        A3[Use Cases/<br/>RevokeDelegationChain]
        A4[DTOs/<br/>AgentTokenRequest]
    end

    subgraph "Infrastructure Layer (Adapters)"
        I1[Repositories/<br/>PostgresqlAgentTokenRepo]
        I2[Adapters/<br/>ETSCacheAdapter]
        I3[Persistence/<br/>AgentTokenSchema]
    end

    subgraph "Presentation Layer (Web)"
        P1[Controllers/<br/>AgentTokenController]
        P2[Plugs/<br/>ValidateAgentAuth]
    end

    P1 -->|calls| A2
    P2 -->|calls| A2
    A2 -->|uses| D1
    A2 -->|uses| D2
    A2 -->|depends on port| A1
    A1 -.->|implemented by| I1
    I1 -->|uses| I3
    A2 -->|uses| I2

    style D1 fill:#e1f5e1
    style D2 fill:#e1f5e1
    style A1 fill:#fff4e1
    style A2 fill:#fff4e1
    style I1 fill:#e1f0ff
    style P1 fill:#ffe1f0
```

---

## 5. MCP Gateway Architecture

### 5.1 MCP Gateway Flow (Confused Deputy Protection)

```mermaid
sequenceDiagram
    participant Agent as AI Agent
    participant Gateway as Thalamus MCP Gateway
    participant MCP as MCP Server (Gmail)
    participant User as Human User
    participant OAuth as Thalamus OAuth2

    Agent->>Gateway: Connect to MCP Server<br/>(stdio transport)
    Gateway->>Gateway: Intercept connection

    alt First Connection (No Token)
        Gateway->>Agent: Authorization Required
        Gateway->>User: Display consent UI<br/>(scopes: gmail:read)
        User->>OAuth: Authorize via browser<br/>(OAuth2 Authorization Code + PKCE)
        OAuth-->>Gateway: Authorization Code
        Gateway->>OAuth: Exchange code for token
        OAuth-->>Gateway: Access Token (gmail:read)
        Gateway->>Gateway: Store token (agent_id -> token)
    end

    Agent->>Gateway: MCP tool invocation<br/>(read_email)
    Gateway->>Gateway: Load token for agent_id
    Gateway->>Gateway: Validate scope (gmail:read)
    Gateway->>MCP: Forward request with token<br/>(Authorization: Bearer ...)
    MCP-->>Gateway: Email data
    Gateway-->>Agent: Email data

    Note over Agent,Gateway: Token is scoped per agent<br/>No shared credentials
    Note over Gateway,MCP: MCP server never receives<br/>root credentials
```

---

[← Back to Index](02-design-index.md) | [Next: Components →](02-design-components.md)
