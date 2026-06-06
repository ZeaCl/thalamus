# Exclude rate limit tests when rate limiting is disabled
exclude_tags =
  if Application.get_env(:thalamus, :rate_limiting_enabled, true) do
    []
  else
    [:rate_limit]
  end

ExUnit.start(exclude: exclude_tags)

# Define global mocks for use cases
# Define mocks WITHOUT prefix (used by existing OAuth2 tests)
Mox.defmock(MockOAuth2ClientRepository, for: Thalamus.Application.Ports.OAuth2ClientRepository)
Mox.defmock(MockUserRepository, for: Thalamus.Application.Ports.UserRepository)
Mox.defmock(MockTokenRepository, for: Thalamus.Application.Ports.TokenRepository)
Mox.defmock(MockRoleRepository, for: Thalamus.Application.Ports.RoleRepository)
Mox.defmock(MockAuditLogger, for: Thalamus.Application.Ports.AuditLogger)
Mox.defmock(MockCacheService, for: Thalamus.Application.Ports.CacheService)

Mox.defmock(MockSamlIdentityProviderRepository,
  for: Thalamus.Application.Ports.SamlIdentityProviderRepository
)

Mox.defmock(MockSamlService, for: Thalamus.Application.Services.SamlService)

# Define SAME mocks WITH Thalamus. prefix (used by RBAC tests)
# This allows both MockUserRepository and Thalamus.MockUserRepository to work
Mox.defmock(Thalamus.MockOAuth2ClientRepository,
  for: Thalamus.Application.Ports.OAuth2ClientRepository
)

Mox.defmock(Thalamus.MockUserRepository, for: Thalamus.Application.Ports.UserRepository)
Mox.defmock(Thalamus.MockTokenRepository, for: Thalamus.Application.Ports.TokenRepository)
Mox.defmock(Thalamus.MockRoleRepository, for: Thalamus.Application.Ports.RoleRepository)
Mox.defmock(Thalamus.MockAuditLogger, for: Thalamus.Application.Ports.AuditLogger)
Mox.defmock(Thalamus.MockCacheService, for: Thalamus.Application.Ports.CacheService)

# Only setup database for integration tests, not unit tests
if System.get_env("SKIP_DB_SETUP") != "true" do
  try do
    Ecto.Adapters.SQL.Sandbox.mode(Thalamus.Repo, :manual)
  rescue
    _ ->
      IO.puts("Database not available - skipping database setup for unit tests")
  end
end
