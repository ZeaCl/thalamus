ExUnit.start()

# Define global mocks for use cases
Mox.defmock(MockOAuth2ClientRepository, for: Thalamus.Application.Ports.OAuth2ClientRepository)
Mox.defmock(MockUserRepository, for: Thalamus.Application.Ports.UserRepository)
Mox.defmock(MockTokenRepository, for: Thalamus.Application.Ports.TokenRepository)
Mox.defmock(MockAgentTokenRepository, for: Thalamus.Application.Ports.AgentTokenRepository)
Mox.defmock(MockAuditLogger, for: Thalamus.Application.Ports.AuditLogger)
Mox.defmock(MockCacheService, for: Thalamus.Application.Ports.CacheService)
Mox.defmock(MockOrganizationRepository, for: Thalamus.Application.Ports.OrganizationRepository)

# Only setup database for integration tests, not unit tests
if System.get_env("SKIP_DB_SETUP") != "true" do
  try do
    Ecto.Adapters.SQL.Sandbox.mode(Thalamus.Repo, :manual)
  rescue
    _ ->
      IO.puts("Database not available - skipping database setup for unit tests")
  end
end
