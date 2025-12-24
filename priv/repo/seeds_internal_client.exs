# Script para crear el cliente OAuth2 interno y organización de sistema

alias Thalamus.Repo  
alias Thalamus.Infrastructure.Persistence.Schemas.{OAuth2ClientSchema, OrganizationSchema}

# IDs fijos
system_org_uuid = "00000000-0000-0000-0000-000000000000"
internal_client_uuid = "00000000-0000-0000-0000-000000000001"

# Timestamp truncado para Ecto
now = DateTime.utc_now() |> DateTime.truncate(:second)

# Crear organización de sistema
case Repo.get(OrganizationSchema, system_org_uuid) do
  nil ->
    %OrganizationSchema{
      id: system_org_uuid,
      name: "System Organization",
      max_users: 9999,
      max_api_calls_per_month: 999999,
      api_calls_reset_at: now,
      inserted_at: now,
      updated_at: now
    }
    |> Repo.insert!()
    IO.puts("✓ Created system organization")
  _ ->
    IO.puts("✓ System organization already exists")
end

# Crear cliente interno
case Repo.get(OAuth2ClientSchema, internal_client_uuid) do
  nil ->
    %OAuth2ClientSchema{
      id: internal_client_uuid,
      organization_id: system_org_uuid,
      client_id_string: "thalamus_internal_api",
      client_secret: Bcrypt.hash_pwd_salt("internal_secret"),
      name: "Thalamus Internal API Client",
      client_type: :confidential,
      allowed_grant_types: ["password", "refresh_token"],
      redirect_uris: [],
      allowed_scopes: [
        "openid", "profile", "email",
        "campaigns:read", "campaigns:write", "campaigns:sync",
        "leads:read", "leads:write",
        "meta:read", "meta:write"
      ],
      is_active: true,
      pkce_required: false,
      inserted_at: now,
      updated_at: now
    }
    |> Repo.insert!()
    IO.puts("✓ Created internal OAuth2 client")
  _ ->
    IO.puts("✓ Internal OAuth2 client already exists")
end

IO.puts("\n✅ Internal client setup complete!")
