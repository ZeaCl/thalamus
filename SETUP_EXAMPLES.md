# Setup Examples - Quick Guide

This guide will help you set up the OAuth2 clients needed to test the SDK examples.

## Step 1: Start Thalamus Server

```bash
# In the Thalamus root directory
mix phx.server
```

Or in IEx for interactive mode:

```bash
iex -S mix phx.server
```

Wait for the server to start. You should see:
```
[info] Running ThalamusWeb.Endpoint with Bandit 1.x.x at 127.0.0.1:4000 (http)
```

## Step 2: Create OAuth2 Clients

Open another terminal and start an IEx session connected to the running server:

```bash
iex -S mix
```

Then paste the following code in the IEx console:

```elixir
# Import required modules
alias Thalamus.Repo
alias Thalamus.Infrastructure.Persistence.{OAuth2ClientSchema, UserSchema, OrganizationSchema}

# Create test organization
{:ok, org} = %OrganizationSchema{
  id: Ecto.UUID.generate(),
  name: "Example Organization",
  plan: "professional",
  is_active: true,
  inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
  updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
} |> Repo.insert()

IO.puts("✅ Organization created: #{org.id}")

# Create test user
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

# Create Next.js Example OAuth2 Client
nextjs_client_id = "nextjs_example_" <> Base.url_encode64(:crypto.strong_rand_bytes(16), padding: false) |> String.slice(0, 24)
nextjs_client_secret = "secret_" <> Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)

{:ok, nextjs_client} = %OAuth2ClientSchema{
  id: Ecto.UUID.generate(),
  name: "Next.js Example App",
  client_id: nextjs_client_id,
  client_secret: Bcrypt.hash_pwd_salt(nextjs_client_secret),
  client_type: "confidential",
  redirect_uris: ["http://localhost:3000/auth/callback"],
  allowed_grant_types: ["authorization_code", "refresh_token"],
  allowed_scopes: ["openid", "profile", "email"],
  organization_id: org.id,
  is_active: true,
  inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
  updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
} |> Repo.insert()

IO.puts("\n✅ Next.js OAuth2 Client Created!")
IO.puts("Client ID: #{nextjs_client_id}")
IO.puts("Client Secret: #{nextjs_client_secret}")

# Create Direct API Example OAuth2 Client
directapi_client_id = "directapi_example_" <> Base.url_encode64(:crypto.strong_rand_bytes(16), padding: false) |> String.slice(0, 24)
directapi_client_secret = "secret_" <> Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)

{:ok, directapi_client} = %OAuth2ClientSchema{
  id: Ecto.UUID.generate(),
  name: "Direct API Example",
  client_id: directapi_client_id,
  client_secret: Bcrypt.hash_pwd_salt(directapi_client_secret),
  client_type: "confidential",
  redirect_uris: ["http://localhost:3001/auth/callback"],
  allowed_grant_types: ["authorization_code", "refresh_token"],
  allowed_scopes: ["openid", "profile", "email"],
  organization_id: org.id,
  is_active: true,
  inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
  updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
} |> Repo.insert()

IO.puts("\n✅ Direct API OAuth2 Client Created!")
IO.puts("Client ID: #{directapi_client_id}")
IO.puts("Client Secret: #{directapi_client_secret}")

IO.puts("\n📝 SAVE THESE CREDENTIALS - YOU WILL NEED THEM!\n")
```

**IMPORTANT:** Copy the client IDs and secrets that are printed. You'll need them in the next step.

## Step 3: Configure Next.js Example

Create `examples/nextjs-app-router/.env.local`:

```bash
THALAMUS_CLIENT_ID=<nextjs_client_id_from_step_2>
THALAMUS_CLIENT_SECRET=<nextjs_client_secret_from_step_2>
THALAMUS_BASE_URL=http://localhost:4000
NEXTAUTH_URL=http://localhost:3000
```

## Step 4: Configure Direct API Example

Create `examples/direct-api/.env`:

```bash
THALAMUS_CLIENT_ID=<directapi_client_id_from_step_2>
THALAMUS_CLIENT_SECRET=<directapi_client_secret_from_step_2>
THALAMUS_BASE_URL=http://localhost:4000
APP_URL=http://localhost:3001
PORT=3001
SESSION_SECRET=<random_secret_here>
```

Generate a random session secret:
```bash
openssl rand -base64 32
```

## Step 5: Test Next.js Example

```bash
cd examples/nextjs-app-router
npm install
npm run dev
```

Open http://localhost:3000 and click "Sign In with Thalamus"

Login credentials:
- Email: `developer@example.com`
- Password: `password123`

## Step 6: Test Direct API Example

```bash
cd examples/direct-api
npm install
npm run dev
```

Open http://localhost:3001 and click "Sign In with Thalamus"

Login credentials (same as above):
- Email: `developer@example.com`
- Password: `password123`

## Troubleshooting

### "Invalid client" error
- Verify the client_id and client_secret are correct
- Make sure you copied them exactly from Step 2

### "Invalid redirect_uri" error
- Check that the redirect URI matches exactly:
  - Next.js: `http://localhost:3000/auth/callback`
  - Direct API: `http://localhost:3001/auth/callback`

### "Connection refused" to Thalamus
- Ensure Thalamus is running on port 4000
- Check `http://localhost:4000` in your browser

### Port already in use
- Next.js: Change PORT in package.json
- Direct API: Change PORT in .env file

## Quick Setup Script (Alternative)

If you prefer, run these commands to set up everything automatically:

```bash
# In Thalamus root directory
iex -S mix

# Then in IEx, load the setup script:
```elixir
Code.eval_file("scripts/create_example_oauth2_client.exs")
```

This will create all clients and generate the .env files automatically.
