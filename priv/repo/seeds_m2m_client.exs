# Seeds file for creating Machine-to-Machine OAuth2 client
#
# This creates an OAuth2 client configured for server-to-server authentication
# using the Client Credentials grant type.
#
# Usage:
#   mix run priv/repo/seeds_m2m_client.exs
#
# ⚠️  IMPORTANT: Save the client_secret output - it cannot be retrieved later!

alias Thalamus.Repo
alias Thalamus.Infrastructure.Persistence.Schemas.{
  OAuth2ClientSchema,
  OrganizationSchema
}

# Configuration - Customize these values
config = %{
  client_name: "My Backend Service",
  client_description: "Backend service for API integration",
  organization_name: "System Services",
  allowed_scopes: [
    "campaigns:read",
    "campaigns:write",
    "leads:read",
    "leads:write",
    "organizations:read",
    "users:read"
  ]
}

IO.puts("\n========================================")
IO.puts("Creating M2M OAuth2 Client")
IO.puts("========================================\n")

# Step 1: Get or create organization
IO.puts("1. Looking for organization '#{config.organization_name}'...")

organization = case Repo.get_by(OrganizationSchema, name: config.organization_name) do
  nil ->
    IO.puts("   Organization not found. Creating new organization...")
    org = %OrganizationSchema{
      id: Ecto.UUID.generate(),
      name: config.organization_name,
      slug: String.downcase(config.organization_name) |> String.replace(" ", "-"),
      plan: "enterprise",
      is_active: true
    }
    |> Repo.insert!()

    IO.puts("   ✓ Created organization: #{org.name} (#{org.id})")
    org

  org ->
    IO.puts("   ✓ Found organization: #{org.name} (#{org.id})")
    org
end

# Step 2: Generate client credentials
IO.puts("\n2. Generating OAuth2 client credentials...")

client_id = Ecto.UUID.generate()
client_secret = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)

# Hash the secret for storage
client_secret_hash = Bcrypt.hash_pwd_salt(client_secret)

IO.puts("   ✓ Generated client_id")
IO.puts("   ✓ Generated client_secret")
IO.puts("   ✓ Hashed secret for storage")

# Step 3: Create OAuth2 client
IO.puts("\n3. Creating OAuth2 client in database...")

client = %OAuth2ClientSchema{
  id: Ecto.UUID.generate(),
  client_id_string: client_id,
  client_secret_hash: client_secret_hash,
  name: config.client_name,
  description: config.client_description,
  organization_id: organization.id,
  client_type: "confidential",
  allowed_grant_types: ["client_credentials"],
  allowed_scopes: config.allowed_scopes,
  redirect_uris: [],  # Not needed for M2M
  is_active: true,
  token_endpoint_auth_method: "client_secret_post"
}
|> Repo.insert!()

IO.puts("   ✓ Client created successfully")

# Step 4: Display credentials
IO.puts("\n========================================")
IO.puts("✓ M2M OAuth2 Client Created Successfully!")
IO.puts("========================================")
IO.puts("\nClient Details:")
IO.puts("  Name:          #{client.name}")
IO.puts("  Type:          #{client.client_type}")
IO.puts("  Organization:  #{organization.name}")
IO.puts("  Status:        #{if client.is_active, do: "Active", else: "Inactive"}")
IO.puts("\nCredentials:")
IO.puts("  Client ID:     #{client_id}")
IO.puts("  Client Secret: #{client_secret}")
IO.puts("\nGrant Types:")
IO.puts("  - client_credentials")
IO.puts("\nAllowed Scopes:")
for scope <- config.allowed_scopes do
  IO.puts("  - #{scope}")
end

IO.puts("\n⚠️  IMPORTANT: Save these credentials now!")
IO.puts("   The client_secret cannot be retrieved later.")
IO.puts("   Store them securely in your environment variables.")

IO.puts("\nEnvironment Variables:")
IO.puts("  THALAMUS_CLIENT_ID=#{client_id}")
IO.puts("  THALAMUS_CLIENT_SECRET=#{client_secret}")

IO.puts("\nTest the client:")
IO.puts(~s"""
  curl -X POST http://localhost:4000/oauth/token \\
    -H "Content-Type: application/json" \\
    -d '{
      "grant_type": "client_credentials",
      "client_id": "#{client_id}",
      "client_secret": "#{client_secret}",
      "scope": "campaigns:read campaigns:write"
    }'
""")

IO.puts("========================================\n")
