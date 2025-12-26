# Admin API Key Seed Script
#
# This script creates the first Admin API Key for development/testing purposes.
# Run this script with: mix run priv/repo/seeds_admin_api_key.exs
#
# ⚠️ IMPORTANT: The API key will be displayed ONCE. Save it securely!

alias Thalamus.Domain.Services.AdminApiKeyGenerator
alias Thalamus.Domain.Entities.AdminApiKey
alias Thalamus.Infrastructure.Repositories.PostgreSQLAdminApiKeyRepository

# Clear existing admin API keys in development
if Mix.env() == :dev do
  IO.puts("🧹 Clearing existing Admin API Keys in development...")

  case PostgreSQLAdminApiKeyRepository.list(%{}) do
    {:ok, existing_keys} ->
      Enum.each(existing_keys, fn key ->
        PostgreSQLAdminApiKeyRepository.delete(key.id)
        IO.puts("  ✓ Deleted Admin API Key: #{key.name}")
      end)

    _ ->
      :ok
  end
end

IO.puts("\n🔑 Creating Admin API Key...")

# Generate API key
%{api_key: api_key, key_prefix: key_prefix, key_hash: key_hash} =
  AdminApiKeyGenerator.generate()

# Create AdminApiKey entity
{:ok, admin_api_key} =
  AdminApiKey.new(%{
    id: Ecto.UUID.generate(),
    key_hash: key_hash,
    key_prefix: key_prefix,
    name: "Development Admin API Key",
    description: "API Key for development and testing - DO NOT USE IN PRODUCTION",
    scopes: [
      "clients:read",
      "clients:write",
      "clients:delete",
      "users:read",
      "users:write",
      "organizations:read",
      "organizations:write",
      "corpus:read",
      "corpus:write"
    ],
    # Expires in 1 year
    expires_at: DateTime.add(DateTime.utc_now(), 365 * 24 * 60 * 60, :second),
    created_by_user_id: nil
  })

# Save to database
case PostgreSQLAdminApiKeyRepository.save(admin_api_key) do
  {:ok, saved_key} ->
    IO.puts("✅ Admin API Key created successfully!\n")
    IO.puts("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    IO.puts("⚠️  SAVE THIS INFORMATION - IT WILL NOT BE SHOWN AGAIN!")
    IO.puts("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

    IO.puts("📋 Admin API Key Details:")
    IO.puts("   ID:          #{saved_key.id}")
    IO.puts("   Name:        #{saved_key.name}")
    IO.puts("   Key Prefix:  #{saved_key.key_prefix}")
    IO.puts("   Scopes:      #{Enum.join(saved_key.scopes, ", ")}")
    IO.puts("   Expires At:  #{saved_key.expires_at}")
    IO.puts("   Is Active:   #{saved_key.is_active}")
    IO.puts("\n🔐 API KEY (⚠️ SAVE THIS NOW!):")
    IO.puts("   #{api_key}\n")

    IO.puts("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

    IO.puts("📝 Usage Instructions:\n")
    IO.puts("1️⃣  Save the API key to your environment:")
    IO.puts("   export THALAMUS_API_KEY=\"#{api_key}\"\n")

    IO.puts("2️⃣  Test authentication:")
    IO.puts(
      "   curl -X POST http://localhost:4000/api/clients \\\n     -H \"Authorization: ApiKey $THALAMUS_API_KEY\" \\\n     -H \"Content-Type: application/json\" \\\n     -d '{\n       \"name\": \"Test Client\",\n       \"organization_id\": \"<your-org-id>\",\n       \"client_type\": \"confidential\",\n       \"redirect_uris\": [\"http://localhost:3000/callback\"],\n       \"grant_types\": [\"authorization_code\", \"refresh_token\"],\n       \"scopes\": [\"openid\", \"profile\", \"email\"]\n     }'\n"
    )

    IO.puts("3️⃣  Manage API keys:")
    IO.puts("   • List:   GET    /api/admin/api-keys")
    IO.puts("   • Show:   GET    /api/admin/api-keys/:id")
    IO.puts("   • Revoke: DELETE /api/admin/api-keys/:id")
    IO.puts("   • Rotate: POST   /api/admin/api-keys/:id/rotate\n")

    IO.puts("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

    IO.puts("⚠️  SECURITY WARNINGS:")
    IO.puts("   • This key has ALL scopes - use only for development/testing")
    IO.puts("   • NEVER commit this key to version control")
    IO.puts("   • NEVER use this key in production")
    IO.puts("   • Store securely in environment variables or secrets manager")
    IO.puts("   • Rotate keys regularly (every 90 days recommended)\n")

    IO.puts("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

  {:error, reason} ->
    IO.puts("❌ Failed to create Admin API Key:")
    IO.inspect(reason)
end
