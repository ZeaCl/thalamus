# Seeds for Platform integration
alias Thalamus.Repo
alias Thalamus.Accounts.{Organization, User}
alias Thalamus.OAuth.OAuth2Client
import Ecto.Query

# Check if organization exists
org = case Repo.get_by(Organization, slug: "acme") do
  nil ->
    IO.puts("Creating ACME organization...")
    {:ok, org} = Repo.insert(%Organization{
      id: Ecto.UUID.generate(),
      name: "ACME Corporation",
      slug: "acme",
      settings: %{},
      inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
      updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    })
    IO.puts("✅ Organization created: #{org.name}")
    org
  org ->
    IO.puts("✅ Organization already exists: #{org.name}")
    org
end

# Check if admin user exists
user = case Repo.get_by(User, email: "admin@acme.com") do
  nil ->
    IO.puts("Creating admin user...")
    {:ok, user} = Repo.insert(%User{
      id: Ecto.UUID.generate(),
      email: "admin@acme.com",
      name: "Admin User",
      password_hash: Bcrypt.hash_pwd_salt("Admin123!"),
      organization_id: org.id,
      inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
      updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    })
    IO.puts("✅ User created: #{user.email}")
    user
  user ->
    IO.puts("✅ User already exists: #{user.email}")
    user
end

# Check if platform_web OAuth2 client exists
client = case Repo.get_by(OAuth2Client, client_id_string: "platform_web") do
  nil ->
    IO.puts("Creating platform_web OAuth2 client...")
    {:ok, client} = Repo.insert(%OAuth2Client{
      id: Ecto.UUID.generate(),
      client_id_string: "platform_web",
      name: "ZEA Platform",
      client_type: "confidential",
      client_secret: "dev_secret_change_in_production",
      is_active: true,
      allowed_grant_types: ["authorization_code", "refresh_token"],
      allowed_scopes: ["openid", "profile", "email", "org:read"],
      redirect_uris: ["http://localhost:4001/auth/callback"],
      organization_id: org.id,
      inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
      updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    })
    IO.puts("✅ OAuth2 client created: #{client.client_id_string}")
    IO.puts("   Redirect URIs: #{inspect(client.redirect_uris)}")
    client
  client ->
    IO.puts("Updating platform_web OAuth2 client redirect URIs...")
    {:ok, client} = client
    |> Ecto.Changeset.change(%{redirect_uris: ["http://localhost:4001/auth/callback"]})
    |> Repo.update()
    IO.puts("✅ OAuth2 client updated: #{client.client_id_string}")
    IO.puts("   Redirect URIs: #{inspect(client.redirect_uris)}")
    client
end

IO.puts("\n🎉 Seeds completed!")
IO.puts("\nYou can now:")
IO.puts("  1. Start Thalamus: mix phx.server (port 4004)")
IO.puts("  2. Start Platform: mix phx.server (port 4001)")
IO.puts("  3. Login at http://localhost:4001 with:")
IO.puts("     Email: admin@acme.com")
IO.puts("     Password: Admin123!")
