defmodule ThalamusWeb.Router do
  use ThalamusWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ThalamusWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug ThalamusWeb.Plugs.CORS
    plug ThalamusWeb.Plugs.SecurityHeaders
    plug ThalamusWeb.Plugs.RateLimiter, limit: 1000, window: 60_000, key: :ip_address
  end

  # OAuth2 Browser pipeline - for authorization endpoint (needs CSRF protection)
  pipeline :oauth2_browser do
    plug :accepts, ["html", "json"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ThalamusWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug ThalamusWeb.Plugs.CORS
    plug ThalamusWeb.Plugs.SecurityHeaders
    plug ThalamusWeb.Plugs.RateLimiter, limit: 20, window: 60_000, key: :ip_address
  end

  # OAuth2 API pipeline - for token/introspect/revoke endpoints (NO CSRF protection)
  pipeline :oauth2_api do
    plug :accepts, ["json"]
    plug ThalamusWeb.Plugs.CORS
    plug ThalamusWeb.Plugs.SecurityHeaders
    plug ThalamusWeb.Plugs.RateLimiter, limit: 1000, window: 60_000, key: :ip_address
  end

  # Authenticated API pipeline (JWT only)
  pipeline :authenticated_api do
    plug :accepts, ["json"]
    plug ThalamusWeb.Plugs.CORS
    plug ThalamusWeb.Plugs.SecurityHeaders
    plug ThalamusWeb.Plugs.AuthenticateToken
    plug ThalamusWeb.Plugs.RateLimiter, limit: 5000, window: 60_000, key: :user_id
  end

  # API Auth pipeline - accepts both JWT and API Keys
  pipeline :api_auth do
    plug :accepts, ["json"]
    plug ThalamusWeb.Plugs.CORS
    plug ThalamusWeb.Plugs.SecurityHeaders
    plug ThalamusWeb.Plugs.APIAuth
    plug ThalamusWeb.Plugs.RateLimiter, limit: 5000, window: 60_000, key: :user_id
  end

  # Super Admin pipeline - requires JWT auth + super_admin role
  pipeline :super_admin do
    plug :accepts, ["json"]
    plug ThalamusWeb.Plugs.CORS
    plug ThalamusWeb.Plugs.SecurityHeaders
    plug ThalamusWeb.Plugs.APIAuth
    plug ThalamusWeb.Plugs.RequireSuperAdmin
    plug ThalamusWeb.Plugs.RateLimiter, limit: 1000, window: 60_000, key: :user_id
  end

  # Internal API for Microservices (e.g., Glia)
  pipeline :internal_api do
    plug :accepts, ["json"]
    # In production, this would be protected by mTLS or a static internal token.
    # For now, we allow it internally.
  end

  scope "/", ThalamusWeb do
    pipe_through :browser

    get "/", PageController, :home

    # Session management
    get "/login", SessionController, :new
    post "/login", SessionController, :create
    get "/logout", SessionController, :delete
    post "/logout", SessionController, :delete

    # Registration (Sign Up)
    get "/register", RegisterController, :new
    post "/register", RegisterController, :create

    # Mock OAuth2 Social Login
    get "/auth/mock/:provider", SessionController, :mock_oauth
  end

  # OAuth2 Authorization Endpoints (Browser-based, needs CSRF protection)
  scope "/oauth", ThalamusWeb.OAuth2 do
    pipe_through :oauth2_browser

    # Authorization endpoint (RFC 6749 Section 3.1)
    get "/authorize", AuthorizationController, :new
    post "/authorize", AuthorizationController, :create
  end

  # OpenID Connect Discovery (public, no auth required)
  scope "/.well-known", ThalamusWeb.OAuth2 do
    pipe_through :api

    # OpenID Connect Discovery endpoint
    get "/openid-configuration", DiscoveryController, :show

    # JWKS endpoint for JWT signature verification
    get "/jwks.json", JwksController, :show
  end

  # OAuth2 Token Endpoints (API-based, NO CSRF protection)
  scope "/oauth", ThalamusWeb.OAuth2 do
    pipe_through :oauth2_api

    # Token endpoint - POST only
    post "/token", TokenController, :create

    # Agent token endpoint - POST only (NEW)
    post "/agent-token", AgentTokenController, :create

    # UserInfo endpoint (OpenID Connect)
    get "/userinfo", UserinfoController, :show

    # Token introspection endpoint (RFC 7662)
    post "/introspect", IntrospectionController, :create

    # Token revocation endpoint (RFC 7009)
    post "/revoke", RevocationController, :create
  end

  # SAML SSO Authentication — public endpoints
  scope "/auth/saml", ThalamusWeb do
    pipe_through :oauth2_api

    get "/init", SamlController, :init
    post "/acs", SamlController, :acs
    get "/metadata/:id", SamlController, :metadata
  end

  # Public API - no authentication required
  scope "/api/public", ThalamusWeb.API do
    pipe_through :api

    # Health check
    get "/health", HealthController, :index

    # Authentication
    post "/login", LoginController, :create

    # User registration
    post "/register", RegistrationController, :create
    post "/verify-email", RegistrationController, :verify_email
    post "/resend-verification", RegistrationController, :resend_verification

    # Password reset
    post "/password/reset", PasswordController, :reset
    post "/password/confirm-reset", PasswordController, :confirm_reset
  end

  # Management API - requires authentication (JWT only)
  scope "/api", ThalamusWeb.API do
    pipe_through :authenticated_api

    # Personal Access Tokens management
    resources "/personal-access-tokens", PersonalAccessTokenController,
      only: [:index, :create, :delete]

    # User management
    resources "/users", UserController, except: [:new, :edit]

    # Organization management
    resources "/organizations", OrganizationController, except: [:new, :edit]

    # Secrets management (UI)
    resources "/secrets", SecretController, only: [:index, :create, :delete]

    # Organization member management
    post "/organizations/:id/members", OrganizationController, :add_member
    delete "/organizations/:id/members/:user_id", OrganizationController, :remove_member

    # Domain management (generic, domain-agnostic)
    get "/domains", DomainController, :index
    post "/domains/register", DomainController, :register
    post "/domains/roles/grant", DomainController, :grant_role
    delete "/domains/roles/revoke", DomainController, :revoke_role
    get "/domains/roles", DomainController, :list_roles

    # Password change (requires authentication)
    put "/password/change", PasswordController, :change

    # Avatar management (requires authentication)
    post "/avatar", AvatarController, :upload
    delete "/avatar", AvatarController, :delete

    # MFA (Multi-Factor Authentication) management
    post "/mfa/totp/setup", MFAController, :setup_totp
    post "/mfa/totp/verify", MFAController, :verify_totp
    post "/mfa/verify", MFAController, :verify_mfa_code
    delete "/mfa/disable", MFAController, :disable_mfa
    post "/mfa/backup-codes/regenerate", MFAController, :regenerate_backup_codes

    # RBAC - Role management
    resources "/roles", RoleController, except: [:new, :edit]

    # RBAC - User-role assignments
    post "/users/:user_id/roles", UserRoleController, :assign
    delete "/users/:user_id/roles/:role_id", UserRoleController, :revoke
    get "/users/:user_id/roles", UserRoleController, :index
    get "/users/:user_id/effective-scopes", UserRoleController, :effective_scopes

    # Audit Logs - Compliance exports
    get "/audit-logs/export", AuditLogController, :export
  end

  # OAuth2 Client Management API - accepts both JWT and API Keys
  scope "/api", ThalamusWeb.API do
    pipe_through :api_auth

    # OAuth2 Client management (now accepts API Key authentication)
    resources "/clients", OAuth2ClientController, except: [:new, :edit]

    # Rotate OAuth2 client secret
    post "/clients/:client_id/rotate-secret", OAuth2ClientController, :rotate_secret

    # Add dynamic redirect URI for subdomains
    post "/clients/:client_id/add-redirect-uri", OAuth2ClientController, :add_redirect_uri
  end

  # SAML Configuration Management — admin, JWT + API Key auth
  scope "/api", ThalamusWeb.API do
    pipe_through :api_auth

    get "/organizations/:id/saml-config", OrganizationController, :show_saml_config
    put "/organizations/:id/saml-config", OrganizationController, :update_saml_config
    delete "/organizations/:id/saml-config", OrganizationController, :delete_saml_config
  end

  # Admin API - requires super_admin role
  scope "/api/admin", ThalamusWeb.Admin do
    pipe_through :super_admin

    # Admin API Key management
    resources "/api-keys", AdminApiKeyController, only: [:index, :create, :show, :delete]
    post "/api-keys/:id/rotate", AdminApiKeyController, :rotate
  end

  # Internal Microservices API
  scope "/api/internal", ThalamusWeb.API do
    pipe_through :internal_api

    get "/secrets/resolve", SecretController, :resolve
    post "/agent-token", AgentTokenController, :create
    get "/users/:id/agent-config", InternalAgentConfigController, :show
  end

  # Enable LiveDashboard in development
  if Application.compile_env(:thalamus, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: ThalamusWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
