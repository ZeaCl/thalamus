#!/usr/bin/env elixir
# Script to create OAuth2 clients for SDK examples

alias Thalamus.Repo
alias Thalamus.Infrastructure.Persistence.OAuth2ClientSchema
alias Thalamus.Infrastructure.Persistence.UserSchema
alias Thalamus.Infrastructure.Persistence.OrganizationSchema

# Ensure we're in the Thalamus app context
IO.puts("\n🔧 Creating OAuth2 clients for SDK examples...\n")

# Find or create test organization
org = case Repo.get_by(OrganizationSchema, name: "Example Organization") do
  nil ->
    IO.puts("📁 Creating test organization...")
    {:ok, org} = %OrganizationSchema{
      id: Ecto.UUID.generate(),
      name: "Example Organization",
      plan: "professional",
      is_active: true,
      inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
      updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    } |> Repo.insert()
    IO.puts("✅ Organization created: #{org.id}")
    org
  org ->
    IO.puts("✅ Organization found: #{org.id}")
    org
end

# Find or create test user
user = case Repo.get_by(UserSchema, email: "developer@example.com") do
  nil ->
    IO.puts("👤 Creating test user...")
    {:ok, user} = %UserSchema{
      id: Ecto.UUID.generate(),
      email: "developer@example.com",
      password_hash: Bcrypt.hash_pwd_salt("password123"),
      name: "Example Developer",
      email_verified: true,
      is_active: true,
      organization_id: org.id,
      inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
      updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    } |> Repo.insert()
    IO.puts("✅ User created: developer@example.com / password123")
    user
  user ->
    IO.puts("✅ User found: #{user.email}")
    user
end

# Create OAuth2 client for Next.js example
nextjs_client = case Repo.get_by(OAuth2ClientSchema, name: "Next.js Example App") do
  nil ->
    IO.puts("🔑 Creating OAuth2 client for Next.js example...")
    client_id = "nextjs_example_" <> Base.url_encode64(:crypto.strong_rand_bytes(16), padding: false) |> String.slice(0, 24)
    client_secret = "secret_" <> Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)

    {:ok, client} = %OAuth2ClientSchema{
      id: Ecto.UUID.generate(),
      name: "Next.js Example App",
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
    } |> Repo.insert()

    IO.puts("✅ Next.js OAuth2 client created!")
    IO.puts("   Client ID: #{client_id}")
    IO.puts("   Client Secret: #{client_secret}")
    IO.puts("   Redirect URI: http://localhost:3000/auth/callback")

    # Store for .env file
    {client, client_id, client_secret}
  client ->
    IO.puts("✅ Next.js client already exists")
    {client, nil, nil}
end

# Create OAuth2 client for Direct API example
direct_api_client = case Repo.get_by(OAuth2ClientSchema, name: "Direct API Example") do
  nil ->
    IO.puts("🔑 Creating OAuth2 client for Direct API example...")
    client_id = "directapi_example_" <> Base.url_encode64(:crypto.strong_rand_bytes(16), padding: false) |> String.slice(0, 24)
    client_secret = "secret_" <> Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)

    {:ok, client} = %OAuth2ClientSchema{
      id: Ecto.UUID.generate(),
      name: "Direct API Example",
      client_id: client_id,
      client_secret: Bcrypt.hash_pwd_salt(client_secret),
      client_type: "confidential",
      redirect_uris: ["http://localhost:3001/auth/callback"],
      allowed_grant_types: ["authorization_code", "refresh_token"],
      allowed_scopes: ["openid", "profile", "email"],
      organization_id: org.id,
      is_active: true,
      inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
      updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    } |> Repo.insert()

    IO.puts("✅ Direct API OAuth2 client created!")
    IO.puts("   Client ID: #{client_id}")
    IO.puts("   Client Secret: #{client_secret}")
    IO.puts("   Redirect URI: http://localhost:3001/auth/callback")

    # Store for .env file
    {client, client_id, client_secret}
  client ->
    IO.puts("✅ Direct API client already exists")
    {client, nil, nil}
end

IO.puts("\n📝 Summary:")
IO.puts("============================================")
IO.puts("\n✅ Test User:")
IO.puts("   Email: developer@example.com")
IO.puts("   Password: password123")

{_, nextjs_id, nextjs_secret} = nextjs_client
if nextjs_id do
  IO.puts("\n✅ Next.js Example (.env.local):")
  IO.puts("   THALAMUS_CLIENT_ID=#{nextjs_id}")
  IO.puts("   THALAMUS_CLIENT_SECRET=#{nextjs_secret}")
  IO.puts("   THALAMUS_BASE_URL=http://localhost:4000")
  IO.puts("   NEXTAUTH_URL=http://localhost:3000")

  # Write to .env.local
  nextjs_env = """
  THALAMUS_CLIENT_ID=#{nextjs_id}
  THALAMUS_CLIENT_SECRET=#{nextjs_secret}
  THALAMUS_BASE_URL=http://localhost:4000
  NEXTAUTH_URL=http://localhost:3000
  """
  File.write!("examples/nextjs-app-router/.env.local", nextjs_env)
  IO.puts("\n   ✅ Written to examples/nextjs-app-router/.env.local")
end

{_, direct_id, direct_secret} = direct_api_client
if direct_id do
  IO.puts("\n✅ Direct API Example (.env):")
  IO.puts("   THALAMUS_CLIENT_ID=#{direct_id}")
  IO.puts("   THALAMUS_CLIENT_SECRET=#{direct_secret}")
  IO.puts("   THALAMUS_BASE_URL=http://localhost:4000")
  IO.puts("   APP_URL=http://localhost:3001")
  IO.puts("   PORT=3001")
  IO.puts("   SESSION_SECRET=#{Base.url_encode64(:crypto.strong_rand_bytes(32))}")

  # Write to .env
  session_secret = Base.url_encode64(:crypto.strong_rand_bytes(32))
  direct_env = """
  THALAMUS_CLIENT_ID=#{direct_id}
  THALAMUS_CLIENT_SECRET=#{direct_secret}
  THALAMUS_BASE_URL=http://localhost:4000
  APP_URL=http://localhost:3001
  PORT=3001
  SESSION_SECRET=#{session_secret}
  """
  File.write!("examples/direct-api/.env", direct_env)
  IO.puts("\n   ✅ Written to examples/direct-api/.env")
end

IO.puts("\n🎉 All clients created successfully!")
IO.puts("\n📚 Next steps:")
IO.puts("   1. Start Thalamus: mix phx.server")
IO.puts("   2. Test Next.js: cd examples/nextjs-app-router && npm install && npm run dev")
IO.puts("   3. Test Direct API: cd examples/direct-api && npm install && npm run dev")
IO.puts("\n============================================\n")
