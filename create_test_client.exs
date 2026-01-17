#!/usr/bin/env elixir

# Script to create OAuth2 test client and user

alias Thalamus.Repo
alias Thalamus.Infrastructure.Persistence.{OAuth2ClientSchema, UserSchema, OrganizationSchema}

IO.puts("\n🔧 Creating test OAuth2 client and user...\n")

# Create or find organization
org =
  case Repo.get_by(OrganizationSchema, name: "Test Organization") do
    nil ->
      IO.puts("📁 Creating test organization...")

      %OrganizationSchema{
        id: Ecto.UUID.generate(),
        name: "Test Organization",
        plan: "professional",
        is_active: true,
        inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
        updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      }
      |> Repo.insert!()

    org ->
      IO.puts("✅ Using existing organization: #{org.name}")
      org
  end

# Create or find test user
user =
  case Repo.get_by(UserSchema, email: "test@example.com") do
    nil ->
      IO.puts("👤 Creating test user...")

      %UserSchema{
        id: Ecto.UUID.generate(),
        email: "test@example.com",
        password_hash: Bcrypt.hash_pwd_salt("test123"),
        name: "Test User",
        email_verified: true,
        is_active: true,
        organization_id: org.id,
        inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
        updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      }
      |> Repo.insert!()

    user ->
      IO.puts("✅ Using existing user: #{user.email}")
      user
  end

# Generate credentials
client_id = "test_nextjs_" <> Base.url_encode64(:crypto.strong_rand_bytes(12), padding: false)
client_secret = "secret_" <> Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)

# Create OAuth2 client
IO.puts("🔑 Creating OAuth2 client...")

client =
  %OAuth2ClientSchema{
    id: Ecto.UUID.generate(),
    name: "Test Next.js App",
    client_id: client_id,
    client_secret: Bcrypt.hash_pwd_salt(client_secret),
    client_type: "confidential",
    redirect_uris: ["http://localhost:3000/auth/callback"],
    allowed_grant_types: ["authorization_code", "refresh_token"],
    allowed_scopes: ["openid", "profile", "email"],
    organization_id: org.id,
    is_active: true,
    inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
    updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
  }
  |> Repo.insert!()

IO.puts("\n✅ OAuth2 Client Created Successfully!\n")
IO.puts("═══════════════════════════════════════════════════════════")
IO.puts("Client ID:     #{client_id}")
IO.puts("Client Secret: #{client_secret}")
IO.puts("Redirect URI:  http://localhost:3000/auth/callback")
IO.puts("═══════════════════════════════════════════════════════════")
IO.puts("\n📧 Test User Credentials:")
IO.puts("Email:    test@example.com")
IO.puts("Password: test123")
IO.puts("═══════════════════════════════════════════════════════════\n")

# Write .env.local for Next.js
env_content = """
THALAMUS_CLIENT_ID=#{client_id}
THALAMUS_CLIENT_SECRET=#{client_secret}
THALAMUS_BASE_URL=http://localhost:4000
NEXTAUTH_URL=http://localhost:3000
"""

File.write!("examples/nextjs-app-router/.env.local", env_content)
IO.puts("✅ Created examples/nextjs-app-router/.env.local")

IO.puts("\n🚀 Ready to test! Run:")
IO.puts("   cd examples/nextjs-app-router")
IO.puts("   npm install")
IO.puts("   npm run dev\n")
