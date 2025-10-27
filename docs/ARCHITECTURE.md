# ZEA Thalamus - OAuth2 Enterprise Authentication Service

## 🧠 Overview

**ZEA Thalamus** is the central authentication and authorization service for the ZEA ecosystem. Named after the brain's thalamus that filters and processes all incoming information, this service handles all authentication, authorization, and security operations for the ZEA platform.

### Vision

- **Enterprise-grade OAuth2** server with OpenID Connect support
- **Multi-factor authentication** (TOTP, SMS, WebAuthn/FIDO2)
- **PCI-DSS, HIPAA, GDPR compliant** security architecture
- **Fraud detection** with machine learning
- **Hardware Security Module** integration
- **Clean Architecture** with SOLID principles

---

## 🏗️ System Architecture

### Clean Architecture Layers

```
┌─────────────────────────────────────────────────────────────┐
│                    Presentation Layer                        │
│  (Controllers - HTTP/API Interface)                          │
│  - OAuth2Controllers (Authorization, Token)                  │
│  - MFAControllers (TOTP, WebAuthn)                          │
│  - APIControllers (Management, Internal)                     │
└──────────────────┬──────────────────────────────────────────┘
                   │ Dependency Direction
                   ▼
┌─────────────────────────────────────────────────────────────┐
│                  Application Layer                           │
│  (Use Cases + DTOs - Business Workflows)                     │
│  - AuthenticateUser, GenerateTokens                         │
│  - ValidateAPIKey, CheckPermissions                         │
│  - SetupMFA, VerifyMFA                                      │
│  - DTOs: AuthRequest/Response, TokenRequest/Response        │
└──────────────────┬──────────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────────┐
│                   Domain Layer                               │
│  (Entities, Value Objects, Services)                         │
│  - User, Organization, Client (Entities)                     │
│  - AuthorizationCode, AccessToken (Value Objects)           │
│  - AuthenticationService, SecurityService (Domain Services) │
└──────────────────┬──────────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────────┐
│               Infrastructure Layer                           │
│  (Adapters, Database, External Services)                     │
│  - PostgreSQL Repositories                                  │
│  - Redis Cache Adapters                                     │
│  - HSM Cryptography Adapters                                │
│  - Rate Limiting Adapters                                   │
└─────────────────────────────────────────────────────────────┘
```

### OAuth2 Flow Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Client Applications                       │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐           │
│  │   Web App   │ │ Mobile App  │ │Service-to-  │           │
│  │(Auth Code)  │ │   (PKCE)    │ │Service(M2M) │           │
│  └─────────────┘ └─────────────┘ └─────────────┘           │
└────────────────────────┬────────────────────────────────────┘
                         │ HTTPS + mTLS
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                   ZEA Thalamus                              │
│                                                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              OAuth2 Authorization Server               │ │
│  │  - Authorization Code Flow + PKCE                      │ │
│  │  - Client Credentials Flow                             │ │
│  │  - Refresh Token Rotation                              │ │
│  │  - OpenID Connect (OIDC)                               │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              Security & Compliance                     │ │
│  │  - Multi-Factor Authentication                         │ │
│  │  - Fraud Detection (ML)                                │ │
│  │  - Rate Limiting (Adaptive)                            │ │
│  │  - Audit Logging (PCI-DSS/HIPAA)                       │ │
│  │  - Hardware Security Module                            │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

---

## 📊 Domain Model

### Core Entities

#### **User** (Aggregate Root)
```elixir
%User{
  id: UserId,
  email: Email,
  password_hash: PasswordHash,
  mfa_methods: [MFAMethod],
  security_profile: SecurityProfile,
  created_at: DateTime,
  verified_at: DateTime
}
```

#### **Organization** (Aggregate Root)
```elixir
%Organization{
  id: OrganizationId,
  name: String.t(),
  plan: Plan,
  settings: OrganizationSettings,
  members: [OrganizationMember]
}
```

#### **OAuth2Client** (Aggregate Root)
```elixir
%OAuth2Client{
  id: ClientId,
  client_secret: ClientSecret,
  organization_id: OrganizationId,
  grant_types: [GrantType],
  redirect_uris: [RedirectUri],
  scopes: [Scope]
}
```

### Value Objects

#### **AccessToken**
```elixir
%AccessToken{
  token: TokenString,
  expires_at: DateTime,
  scopes: [Scope],
  subject: UserId | ClientId
}
```

#### **AuthorizationCode**
```elixir
%AuthorizationCode{
  code: CodeString,
  client_id: ClientId,
  user_id: UserId,
  redirect_uri: RedirectUri,
  scopes: [Scope],
  pkce_challenge: PKCEChallenge,
  expires_at: DateTime
}
```

---

## 🔧 Implementation Details

### Use Cases (Application Layer)

#### **AuthenticateUser**
```elixir
defmodule Thalamus.Application.UseCases.AuthenticateUser do
  @moduledoc """
  Authenticates a user with credentials and optional MFA.

  SOLID Principles Applied:
  - Single Responsibility: Only handles user authentication
  - Dependency Inversion: Depends on ports (interfaces)
  """

  alias Thalamus.Application.Ports.{UserRepository, SecurityService, AuditLogger}
  alias Thalamus.Application.DTOs.{AuthenticationRequest, AuthenticationResponse}

  def execute(%AuthenticationRequest{} = request) do
    with {:ok, user} <- UserRepository.find_by_email(request.email),
         :ok <- SecurityService.verify_password(request.password, user.password_hash),
         :ok <- check_account_status(user),
         {:ok, mfa_token} <- handle_mfa_if_required(user, request) do

      AuditLogger.log_authentication_success(user.id, request.context)
      {:ok, AuthenticationResponse.new(user, mfa_token)}
    else
      {:error, reason} ->
        AuditLogger.log_authentication_failure(request.email, reason, request.context)
        {:error, reason}
    end
  end
end
```

#### **GenerateTokens**
```elixir
defmodule Thalamus.Application.UseCases.GenerateTokens do
  @moduledoc """
  Generates OAuth2 tokens for authenticated users/clients.

  SOLID Principles Applied:
  - Open/Closed: Extensible for new token types
  - Interface Segregation: Separate ports for different concerns
  """

  alias Thalamus.Application.Ports.{TokenRepository, CryptographyService}
  alias Thalamus.Domain.Entities.{AccessToken, RefreshToken}

  def execute(grant_type, credentials, scopes) do
    case grant_type do
      :authorization_code -> handle_authorization_code_grant(credentials, scopes)
      :client_credentials -> handle_client_credentials_grant(credentials, scopes)
      :refresh_token -> handle_refresh_token_grant(credentials)
    end
  end
end
```

### Ports (Application Layer Interfaces)

#### **UserRepository**
```elixir
defmodule Thalamus.Application.Ports.UserRepository do
  @moduledoc """
  Port (interface) for user data access.
  Follows Interface Segregation Principle.
  """

  alias Thalamus.Domain.Entities.User
  alias Thalamus.Domain.ValueObjects.{UserId, Email}

  @callback find_by_id(UserId.t()) :: {:ok, User.t()} | {:error, :not_found}
  @callback find_by_email(Email.t()) :: {:ok, User.t()} | {:error, :not_found}
  @callback save(User.t()) :: {:ok, User.t()} | {:error, term()}
  @callback update_last_login(UserId.t(), DateTime.t()) :: :ok | {:error, term()}
end
```

#### **SecurityService**
```elixir
defmodule Thalamus.Application.Ports.SecurityService do
  @moduledoc """
  Port for security-related operations.
  """

  @callback verify_password(String.t(), String.t()) :: :ok | {:error, :invalid_password}
  @callback hash_password(String.t()) :: {:ok, String.t()}
  @callback generate_secure_token(pos_integer()) :: String.t()
  @callback calculate_risk_score(map()) :: 0..100
end
```

### Adapters (Infrastructure Layer)

#### **PostgreSQLUserRepository**
```elixir
defmodule Thalamus.Infrastructure.Adapters.PostgreSQLUserRepository do
  @moduledoc """
  PostgreSQL implementation of UserRepository port.
  Follows Dependency Inversion Principle.
  """

  @behaviour Thalamus.Application.Ports.UserRepository

  import Ecto.Query
  alias Thalamus.Infrastructure.Persistence.Schemas.UserSchema
  alias Thalamus.Domain.Entities.User

  @impl true
  def find_by_id(user_id) do
    case Repo.get(UserSchema, user_id) do
      nil -> {:error, :not_found}
      schema -> {:ok, UserSchema.to_domain(schema)}
    end
  end

  @impl true
  def find_by_email(email) do
    query = from u in UserSchema, where: u.email == ^email

    case Repo.one(query) do
      nil -> {:error, :not_found}
      schema -> {:ok, UserSchema.to_domain(schema)}
    end
  end
end
```

---

## 🧪 Testing Strategy

### Test Structure
```
test/
├── thalamus/
│   ├── domain/              # Unit tests for entities/value objects
│   │   ├── entities/
│   │   └── value_objects/
│   ├── application/         # Unit tests for use cases (with mocks)
│   │   ├── use_cases/
│   │   └── dtos/
│   └── infrastructure/      # Integration tests for adapters
│       └── adapters/
└── thalamus_web/           # Controller tests
    └── controllers/
```

### Unit Test Example (Domain)
```elixir
defmodule Thalamus.Domain.ValueObjects.AccessTokenTest do
  use ExUnit.Case
  alias Thalamus.Domain.ValueObjects.AccessToken

  describe "new/4" do
    test "creates valid access token with correct expiration" do
      token = AccessToken.new("token123", ["read", "write"], "user_123", 3600)

      assert token.token == "token123"
      assert token.scopes == ["read", "write"]
      assert token.subject == "user_123"
      assert DateTime.diff(token.expires_at, DateTime.utc_now()) == 3600
    end

    test "fails with invalid token" do
      assert {:error, :invalid_token} = AccessToken.new("", ["read"], "user_123", 3600)
    end
  end
end
```

### Use Case Test with Mox
```elixir
defmodule Thalamus.Application.UseCases.AuthenticateUserTest do
  use ExUnit.Case
  import Mox

  alias Thalamus.Application.UseCases.AuthenticateUser
  alias Thalamus.Application.DTOs.AuthenticationRequest

  # Setup mocks
  setup :verify_on_exit!

  test "successfully authenticates user with valid credentials" do
    user = build(:user)
    request = build(:authentication_request, email: user.email, password: "valid_password")

    # Mock expectations
    MockUserRepository
    |> expect(:find_by_email, fn email -> {:ok, user} end)

    MockSecurityService
    |> expect(:verify_password, fn _password, _hash -> :ok end)

    MockAuditLogger
    |> expect(:log_authentication_success, fn _user_id, _context -> :ok end)

    # Execute
    assert {:ok, response} = AuthenticateUser.execute(request)
    assert response.user_id == user.id
  end
end
```

### Integration Test Example
```elixir
defmodule Thalamus.Infrastructure.Adapters.PostgreSQLUserRepositoryTest do
  use Thalamus.DataCase

  alias Thalamus.Infrastructure.Adapters.PostgreSQLUserRepository

  test "finds user by email" do
    user = insert(:user, email: "test@example.com")

    assert {:ok, found_user} = PostgreSQLUserRepository.find_by_email("test@example.com")
    assert found_user.id == user.id
    assert found_user.email == user.email
  end
end
```

---

## 🔐 Security Features

### Multi-Factor Authentication
- **TOTP** (Time-based One-Time Password) via Google Authenticator
- **SMS/Email** OTP
- **WebAuthn/FIDO2** hardware security keys
- **Backup codes** for recovery

### Fraud Detection
- **Machine learning** risk scoring
- **Device fingerprinting**
- **Geo-location analysis**
- **Behavioral biometrics**

### Compliance Features
- **PCI-DSS** payment card industry compliance
- **HIPAA** healthcare data protection
- **GDPR** European data protection
- **SOX** financial reporting compliance

### Hardware Security Module
- **Key generation** and storage
- **Digital signing** operations
- **Encryption/decryption** with hardware keys
- **Key rotation** and management

---

## 📈 Performance & Scalability

### Performance Targets
- **< 50ms** p99 authentication latency
- **> 10,000 req/s** sustained throughput
- **99.9%** availability
- **< 0.01%** error rate

### Scalability Features
- **Horizontal scaling** with multiple instances
- **Database read replicas**
- **Redis clustering** for sessions
- **CDN integration** for static assets

### Monitoring
- **Prometheus** metrics collection
- **Grafana** dashboards
- **Distributed tracing** with OpenTelemetry
- **Real-time alerting** via PagerDuty

---

## 🚀 Deployment

### Container Security
- **Multi-stage** Docker builds
- **Non-root** container execution
- **Read-only** filesystem
- **Security scanning** with Trivy

### Kubernetes Security
- **Pod Security Standards**
- **Network Policies**
- **Resource quotas**
- **Admission controllers**

### Secrets Management
- **HashiCorp Vault** for secrets
- **Kubernetes secrets** for config
- **Automatic secret rotation**
- **Encrypted storage** at rest

---

## 📚 API Documentation

### OAuth2 Endpoints

#### Authorization Endpoint
```
GET /oauth2/authorize?
  response_type=code&
  client_id=CLIENT_ID&
  redirect_uri=REDIRECT_URI&
  scope=SCOPE&
  state=STATE&
  code_challenge=CHALLENGE&
  code_challenge_method=S256
```

#### Token Endpoint
```
POST /oauth2/token
Content-Type: application/x-www-form-urlencoded

grant_type=authorization_code&
code=AUTHORIZATION_CODE&
redirect_uri=REDIRECT_URI&
client_id=CLIENT_ID&
code_verifier=VERIFIER
```

### Internal APIs

#### API Key Validation
```
POST /internal/validate
Content-Type: application/json
Authorization: Bearer INTERNAL_TOKEN

{
  "api_key": "sk_live_abc123..."
}
```

#### Permission Check
```
POST /internal/permissions
Content-Type: application/json

{
  "user_id": "user_123",
  "resource": "synapse:events",
  "action": "write"
}
```

---

## 🔍 Metrics & Observability

### Key Metrics
- **Authentication success/failure rates**
- **Token generation latency**
- **MFA verification rates**
- **Fraud detection accuracy**
- **Rate limiting effectiveness**

### Audit Events
- **User authentication** (success/failure)
- **Token generation/validation**
- **MFA setup/verification**
- **Administrative actions**
- **Security violations**

### Dashboards
- **Real-time authentication metrics**
- **Security threat detection**
- **Performance monitoring**
- **Compliance reporting**

---

## 🎯 Future Roadmap

### Phase 1: Core OAuth2 (4-6 weeks)
- Basic OAuth2 flows
- User management
- PostgreSQL persistence
- Basic security

### Phase 2: Enhanced Security (4-6 weeks)
- Multi-factor authentication
- Fraud detection
- Rate limiting
- Audit logging

### Phase 3: Enterprise Features (8-12 weeks)
- Hardware Security Module
- Advanced compliance
- ML-powered security
- Advanced monitoring

### Phase 4: Ecosystem Integration (4-6 weeks)
- ZEA platform integration
- Client SDKs
- Documentation
- Performance optimization

---

## 🏆 Success Criteria

### Technical
- **All use cases** have 100% test coverage
- **Zero critical security** vulnerabilities
- **Sub-50ms latency** for 99% of requests
- **99.9% uptime** in production

### Business
- **Complete OAuth2** compliance
- **Enterprise security** certifications
- **Seamless integration** with ZEA ecosystem
- **Developer-friendly** APIs and documentation

---

**Created by**: Claude Code (Architectural Foundation)
**Date**: October 26, 2024
**Version**: 1.0.0
**Status**: Architecture Complete - Ready for Implementation