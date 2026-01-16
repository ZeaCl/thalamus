# Script to create Admin API Key for Sport Backend
# Run with: mix run create_sport_api_key.exs

alias Thalamus.Domain.Entities.AdminApiKey
alias Thalamus.Domain.Services.AdminApiKeyGenerator
alias Thalamus.Infrastructure.Repositories.PostgreSQLAdminApiKeyRepository
alias Thalamus.Infrastructure.Persistence.Schemas.{UserSchema, OrganizationSchema}

IO.puts("\n" <> String.duplicate("=", 70))
IO.puts("Creating Admin API Key for Sport Backend")
IO.puts(String.duplicate("=", 70) <> "\n")

# Step 1: Create organization
IO.puts("📋 Step 1: Creating Organization")

# Create organization directly with Ecto using Sport's specific ID
sport_org_id = "85e2b88c-4567-4890-abcd-123456789012"

org_attrs = %{
  id: sport_org_id,
  name: "Sport Backend Organization",
  status: :trial,
  verified: false,
  plan_type: :enterprise,
  max_users: 999_999,
  max_api_calls_per_month: 999_999_999,
  mfa_required: true,
  sso_enabled: true,
  audit_logs_retention_days: 365,
  support_level: :dedicated,
  current_user_count: 0,
  api_calls_current_month: 0,
  api_calls_reset_at: DateTime.truncate(DateTime.utc_now(), :second),
  members: []
}

{:ok, saved_org} =
  struct(OrganizationSchema, org_attrs)
  |> Thalamus.Repo.insert()

IO.puts("✅ Organization created: #{saved_org.name}")
IO.puts("   ID: #{saved_org.id}")

# Step 2: Create super admin user
IO.puts("\n📋 Step 2: Creating Super Admin User")

# Create user with organization_id directly using Ecto
{:ok, password_hash} = Bcrypt.hash_pwd_salt("SuperAdmin123!@#") |> (&{:ok, &1}).()
# Already a UUID string
org_uuid = saved_org.id

admin_user_attrs = %{
  email: "sport-admin@zea.com",
  password_hash: password_hash,
  organization_id: org_uuid,
  status: :active,
  verified_at: DateTime.utc_now(),
  failed_login_attempts: 0
}

{:ok, admin_user} =
  admin_user_attrs
  |> UserSchema.create_changeset()
  |> Thalamus.Repo.insert()

IO.puts("✅ Admin user created: #{admin_user.email}")
IO.puts("   Password: SuperAdmin123!@#")
IO.puts("   ⚠️  SAVE THIS PASSWORD - needed for login")

# Step 3: Create Admin API Key for Sport
IO.puts("\n📋 Step 3: Creating Admin API Key for Sport Backend")

# Generate the API key
%{api_key: generated_api_key, key_prefix: key_prefix, key_hash: key_hash} =
  AdminApiKeyGenerator.generate()

# Create the Admin API Key entity
{:ok, api_key_entity} =
  AdminApiKey.new(%{
    id: Ecto.UUID.generate(),
    key_hash: key_hash,
    key_prefix: key_prefix,
    name: "Sport Backend Integration",
    description: "Admin API Key for Sport backend to auto-register OAuth2 M2M client",
    scopes: ["clients:write", "clients:read"],
    is_active: true,
    expires_at: ~U[2026-12-31 23:59:59Z],
    created_by_user_id: admin_user.id,
    created_at: DateTime.utc_now(),
    updated_at: DateTime.utc_now()
  })

# Save to database
{:ok, saved_key} = PostgreSQLAdminApiKeyRepository.save(api_key_entity)

IO.puts("✅ Admin API Key created successfully!")
IO.puts("\n" <> String.duplicate("=", 70))
IO.puts("ADMIN API KEY CREDENTIALS - SAVE THESE SECURELY!")
IO.puts(String.duplicate("=", 70))
IO.puts("\n📝 Configuration for Sport Backend:\n")
IO.puts("Add this to Sport's .env.local file:")
IO.puts("\n# Thalamus Configuration")
IO.puts("THALAMUS_URL=http://localhost:4000")
IO.puts("THALAMUS_API_KEY=#{generated_api_key}")
IO.puts("ORGANIZATION_ID=#{saved_org.id}")
IO.puts("\n" <> String.duplicate("=", 70))
IO.puts("\n⚠️  SECURITY WARNING:")
IO.puts("   - This API key will ONLY be shown once")
IO.puts("   - Store it in a secure secrets manager in production")
IO.puts("   - Never commit it to git")
IO.puts("\n📋 API Key Details:")
IO.puts("   Name: #{saved_key.name}")
IO.puts("   Prefix: #{saved_key.key_prefix}")
IO.puts("   Scopes: #{Enum.join(saved_key.scopes, ", ")}")
IO.puts("   Expires: #{saved_key.expires_at}")
IO.puts("   Active: #{saved_key.is_active}")
IO.puts("\n🚀 Next Steps for Sport Team:")
IO.puts("   1. Save the THALAMUS_API_KEY in Sport's .env.local")
IO.puts("   2. Run: python register_oauth2_client.py")
IO.puts("   3. This will auto-register Sport as OAuth2 M2M client")
IO.puts("   4. Use the returned client_id and client_secret for M2M auth")
IO.puts("\n📧 Email Response to Sport Team:")
IO.puts("\n" <> String.duplicate("-", 70))
IO.puts("Asunto: Re: Solicitud de Admin API Key para Sport Backend - COMPLETADO")
IO.puts(String.duplicate("-", 70))
IO.puts("\nHola equipo Sport,")
IO.puts("\n✅ El Admin API Key ha sido creado exitosamente.")
IO.puts("\nDatos de configuración:")
IO.puts("```")
IO.puts("THALAMUS_URL=http://localhost:4000")
IO.puts("THALAMUS_API_KEY=#{generated_api_key}")
IO.puts("ORGANIZATION_ID=#{saved_org.id}")
IO.puts("```")
IO.puts("\nEste API key tiene los siguientes permisos:")
IO.puts("- clients:write (crear clientes OAuth2)")
IO.puts("- clients:read (consultar clientes)")
IO.puts("\nPróximos pasos:")
IO.puts("1. Agregar las variables de entorno a Sport's .env.local")
IO.puts("2. Ejecutar register_oauth2_client.py para auto-registro")
IO.puts("3. El script retornará client_id y client_secret para M2M")
IO.puts("\n⚠️  IMPORTANTE: Este API key solo se muestra UNA VEZ.")
IO.puts("Guárdenlo en un gestor de secretos (no lo commiteen a git).")
IO.puts("\nSaludos,")
IO.puts("Equipo Thalamus")
IO.puts(String.duplicate("-", 70) <> "\n")
IO.puts("\n" <> String.duplicate("=", 70) <> "\n")

IO.puts("\n✨ Setup completed successfully!")
