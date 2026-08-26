alias Thalamus.Repo

alias Thalamus.Infrastructure.Persistence.Schemas.{
  UserSchema,
  OrganizationSchema,
  OAuth2ClientSchema,
  UserDomainRoleSchema
}

import Ecto.Query
require Logger

Logger.info("Starting Thalamus database seeding...")

# 1. Organizations
zea_org_id = "ea7b11ea-852c-44e5-aee1-a761ec76eaea"
secondary_org_id = "5fd11ea0-852c-44e5-aee1-a761ec76eaea"

# Create zea org
zea_org =
  case Repo.get(OrganizationSchema, zea_org_id) do
    nil ->
      org_attrs = %{
        id: zea_org_id,
        name: "Default Org",
        plan_type: :enterprise,
        status: :active,
        verified: true,
        max_users: 999_999,
        max_api_calls_per_month: 999_999_999,
        mfa_required: true,
        sso_enabled: true,
        audit_logs_retention_days: 365,
        support_level: :dedicated,
        api_calls_reset_at: DateTime.truncate(DateTime.utc_now(), :second)
      }

      %OrganizationSchema{}
      |> Ecto.Changeset.cast(org_attrs, [
        :id,
        :name,
        :plan_type,
        :status,
        :verified,
        :max_users,
        :max_api_calls_per_month,
        :mfa_required,
        :sso_enabled,
        :audit_logs_retention_days,
        :support_level,
        :api_calls_reset_at
      ])
      |> Repo.insert!()

    existing ->
      existing
  end

# Create secondary org
secondary_org =
  case Repo.get(OrganizationSchema, secondary_org_id) do
    nil ->
      org_attrs = %{
        id: secondary_org_id,
        name: "Example Org",
        plan_type: :enterprise,
        status: :active,
        verified: true,
        max_users: 500,
        max_api_calls_per_month: 2_000_000,
        mfa_required: true,
        sso_enabled: true,
        audit_logs_retention_days: 180,
        support_level: :priority,
        api_calls_reset_at: DateTime.truncate(DateTime.utc_now(), :second)
      }

      %OrganizationSchema{}
      |> Ecto.Changeset.cast(org_attrs, [
        :id,
        :name,
        :plan_type,
        :status,
        :verified,
        :max_users,
        :max_api_calls_per_month,
        :mfa_required,
        :sso_enabled,
        :audit_logs_retention_days,
        :support_level,
        :api_calls_reset_at
      ])
      |> Repo.insert!()

    existing ->
      existing
  end

# 2. Users
c_user_id = "c0000000-852c-44e5-aee1-a761ec76eaea"
member_user_id = "c0000001-852c-44e5-aee1-a761ec76eaea"

c_pass_hash = Bcrypt.hash_pwd_salt("ExamplePass123!")
member_pass_hash = Bcrypt.hash_pwd_salt("ExamplePass123!")

c_user =
  case Repo.get(UserSchema, c_user_id) || Repo.get_by(UserSchema, email: "owner@example.com") do
    nil ->
      user_attrs = %{
        id: c_user_id,
        email: "owner@example.com",
        name: "Example User",
        password_hash: c_pass_hash,
        organization_id: zea_org_id,
        status: :active,
        verified_at: DateTime.truncate(DateTime.utc_now(), :second)
      }

      %UserSchema{}
      |> Ecto.Changeset.cast(user_attrs, [
        :id,
        :email,
        :name,
        :password_hash,
        :organization_id,
        :status,
        :verified_at
      ])
      |> Repo.insert!()

    existing ->
      existing
  end

member_user =
  case Repo.get(UserSchema, member_user_id) ||
         Repo.get_by(UserSchema, email: "member@example.com") do
    nil ->
      user_attrs = %{
        id: member_user_id,
        email: "member@example.com",
        name: "Example User 2",
        password_hash: member_pass_hash,
        organization_id: secondary_org_id,
        status: :active,
        verified_at: DateTime.truncate(DateTime.utc_now(), :second)
      }

      %UserSchema{}
      |> Ecto.Changeset.cast(user_attrs, [
        :id,
        :email,
        :name,
        :password_hash,
        :organization_id,
        :status,
        :verified_at
      ])
      |> Repo.insert!()

    existing ->
      existing
  end

# 2b. Admin user for CLI validation (used by zea-cli validate.sh)
admin_user_id = "a0000000-852c-44e5-aee1-a761ec76eaea"
admin_pass_hash = Bcrypt.hash_pwd_salt("Admin123!")

_admin_user =
  case Repo.get(UserSchema, admin_user_id) || Repo.get_by(UserSchema, email: "admin@zea.local") do
    nil ->
      user_attrs = %{
        id: admin_user_id,
        email: "admin@zea.local",
        name: "Local Admin",
        password_hash: admin_pass_hash,
        organization_id: zea_org_id,
        status: :active,
        verified_at: DateTime.truncate(DateTime.utc_now(), :second)
      }

      %UserSchema{}
      |> Ecto.Changeset.cast(user_attrs, [
        :id,
        :email,
        :name,
        :password_hash,
        :organization_id,
        :status,
        :verified_at
      ])
      |> Repo.insert!()

    existing ->
      existing
  end

# Update organization members arrays (only if empty — avoids overwriting members added via API)
if is_nil(zea_org.members) or zea_org.members == [] do
  zea_members = [
    %{
      "user_id" => c_user_id,
      "email" => "owner@example.com",
      "role" => "owner",
      "joined_at" => DateTime.to_iso8601(DateTime.utc_now())
    },
    %{
      "user_id" => admin_user_id,
      "email" => "admin@zea.local",
      "role" => "admin",
      "joined_at" => DateTime.to_iso8601(DateTime.utc_now())
    }
  ]

  zea_org
  |> Ecto.Changeset.change(%{members: zea_members, current_user_count: 2})
  |> Repo.update!()
end

if is_nil(secondary_org.members) or secondary_org.members == [] do
  secondary_members = [
    %{
      "user_id" => member_user_id,
      "email" => "member@example.com",
      "role" => "owner",
      "joined_at" => DateTime.to_iso8601(DateTime.utc_now())
    },
    %{
      "user_id" => c_user_id,
      "email" => "owner@example.com",
      "role" => "admin",
      "joined_at" => DateTime.to_iso8601(DateTime.utc_now())
    }
  ]

  secondary_org
  |> Ecto.Changeset.change(%{members: secondary_members, current_user_count: 2})
  |> Repo.update!()
end

# 3. OAuth Clients
platform_web_client_id = "59991e63-852c-44e5-aee1-a761ec76eaea"
thalamus_cli_client_id = "c1111111-852c-44e5-aee1-a761ec76eaea"

platform_web_uris = [
  "http://localhost:4000/auth/callback",
  "http://localhost:4001/auth/callback",
  "http://example.localhost/auth/callback",
  "http://example.localhost:3000/auth/callback",
  "http://client.localhost/auth/callback",
  "http://client-soma.localhost/auth/callback",
  "http://example.localhost:4001/auth/callback",
  "http://client.localhost:4001/auth/callback",
  "https://example.com/auth/callback",
  "https://client.example.com/auth/callback",
  # NextAuth callback URLs (provider-specific path)
  "http://localhost:3000/api/auth/callback/thalamus",
  "http://app.example.localhost/api/auth/callback/thalamus",
  # Puertos :8080 (docker compose local)
  "http://example.localhost:8080/auth/callback",
  "http://client.localhost:8080/auth/callback",
  "http://client-soma.localhost:8080/auth/callback",
  "http://app.example.localhost:8080/api/auth/callback/thalamus"
]

case Repo.get(OAuth2ClientSchema, platform_web_client_id) ||
       Repo.get_by(OAuth2ClientSchema, client_id_string: "platform_web") do
  nil ->
    hashed_secret = Bcrypt.hash_pwd_salt("example_client_secret_change_me")

    client_attrs = %{
      id: platform_web_client_id,
      client_id_string: "platform_web",
      name: "Web Platform",
      client_type: :public,
      client_secret: hashed_secret,
      organization_id: zea_org_id,
      redirect_uris: platform_web_uris,
      allowed_grant_types: ["authorization_code", "refresh_token"],
      allowed_scopes: ["openid", "profile", "email", "zea:read", "zea:write"],
      pkce_required: true,
      auto_approve: true
    }

    %OAuth2ClientSchema{}
    |> Ecto.Changeset.cast(client_attrs, [
      :id,
      :client_id_string,
      :name,
      :client_type,
      :client_secret,
      :organization_id,
      :redirect_uris,
      :allowed_grant_types,
      :allowed_scopes,
      :pkce_required,
      :auto_approve
    ])
    |> Repo.insert!()

  existing ->
    existing
    |> Ecto.Changeset.change(%{redirect_uris: platform_web_uris, auto_approve: true})
    |> Repo.update!()
end

cli_uris = [
  "http://localhost:4005/callback",
  "http://localhost:3000/callback"
]

case Repo.get(OAuth2ClientSchema, thalamus_cli_client_id) ||
       Repo.get_by(OAuth2ClientSchema, client_id_string: "thalamus_cli") do
  nil ->
    client_attrs = %{
      id: thalamus_cli_client_id,
      client_id_string: "thalamus_cli",
      name: "Thalamus CLI",
      client_type: :public,
      client_secret: nil,
      organization_id: zea_org_id,
      redirect_uris: cli_uris,
      allowed_grant_types: [
        "authorization_code",
        "refresh_token",
        "device_code"
      ],
      allowed_scopes: ["openid", "profile", "email", "zea:read", "zea:write"],
      pkce_required: true,
      auto_approve: true
    }

    %OAuth2ClientSchema{}
    |> Ecto.Changeset.cast(client_attrs, [
      :id,
      :client_id_string,
      :name,
      :client_type,
      :client_secret,
      :organization_id,
      :redirect_uris,
      :allowed_grant_types,
      :allowed_scopes,
      :pkce_required,
      :auto_approve
    ])
    |> Repo.insert!()

  existing ->
    existing
    |> Ecto.Changeset.change(%{
      redirect_uris: cli_uris,
      allowed_grant_types: [
        "authorization_code",
        "refresh_token",
        "device_code"
      ],
      auto_approve: true
    })
    |> Repo.update!()
end

# Internal login client (for zea auth login --email/--password)
internal_client_id = "00000000-0000-0000-0000-000000000001"

case Repo.get(OAuth2ClientSchema, internal_client_id) ||
       Repo.get_by(OAuth2ClientSchema, client_id_string: "internal_login") do
  nil ->
    internal_client_attrs = %{
      id: internal_client_id,
      client_id_string: "internal_login",
      name: "Internal Login",
      client_type: :confidential,
      client_secret: "internal_secret_do_not_expose",
      organization_id: zea_org_id,
      redirect_uris: [],
      allowed_grant_types: [
        "authorization_code",
        "refresh_token",
        "client_credentials",
        "password"
      ],
      allowed_scopes: ["openid", "profile", "email", "zea:read", "zea:write"],
      pkce_required: false
    }

    %OAuth2ClientSchema{}
    |> Ecto.Changeset.cast(internal_client_attrs, [
      :id,
      :client_id_string,
      :name,
      :client_type,
      :client_secret,
      :organization_id,
      :redirect_uris,
      :allowed_grant_types,
      :allowed_scopes,
      :pkce_required
    ])
    |> Repo.insert!()

  existing ->
    existing
    |> Ecto.Changeset.change(%{
      allowed_grant_types: [
        "authorization_code",
        "refresh_token",
        "client_credentials",
        "password"
      ]
    })
    |> Repo.update!()
end

# Example client 1
client_1_id = "04b857b6-8298-47a4-b93b-b7c4e0d01b14"

case Repo.get(OAuth2ClientSchema, client_1_id) do
  nil ->
    %OAuth2ClientSchema{}
    |> Ecto.Changeset.cast(
      %{
        id: client_1_id,
        client_id_string: "example_client_1",
        name: "Example Client",
        client_type: :public,
        client_secret: nil,
        organization_id: secondary_org_id,
        redirect_uris: [
          "https://client.example.com/auth/callback",
          "http://localhost:5173/auth/callback",
          "http://client.localhost:8080/auth/callback"
        ],
        allowed_grant_types: ["authorization_code", "refresh_token"],
        allowed_scopes: ["openid", "profile", "email"],
        pkce_required: true
      },
      [
        :id,
        :client_id_string,
        :name,
        :client_type,
        :client_secret,
        :organization_id,
        :redirect_uris,
        :allowed_grant_types,
        :allowed_scopes,
        :pkce_required
      ]
    )
    |> Repo.insert!()

  existing ->
    :ok
end

# Example client 2
client_2_id = "7ad26658-3099-4f2e-b4e4-128dc93d92ba"

case Repo.get(OAuth2ClientSchema, client_2_id) do
  nil ->
    %OAuth2ClientSchema{}
    |> Ecto.Changeset.cast(
      %{
        id: client_2_id,
        client_id_string: "example_client_2",
        name: "Example Client",
        client_type: :public,
        client_secret: nil,
        organization_id: secondary_org_id,
        redirect_uris: [
          "https://client.example.com/auth/callback",
          "http://localhost:5173/auth/callback",
          "http://client.localhost:8080/auth/callback"
        ],
        allowed_grant_types: ["authorization_code", "refresh_token"],
        allowed_scopes: [],
        pkce_required: true
      },
      [
        :id,
        :client_id_string,
        :name,
        :client_type,
        :client_secret,
        :organization_id,
        :redirect_uris,
        :allowed_grant_types,
        :allowed_scopes,
        :pkce_required
      ]
    )
    |> Repo.insert!()

  existing ->
    :ok
end

# Cerebelum service account (machine-to-machine, long-lived JWT)
cerebelum_service_id = "00000000-0000-0000-0000-000000000002"

case Repo.get(OAuth2ClientSchema, cerebelum_service_id) ||
       Repo.get_by(OAuth2ClientSchema, client_id_string: "cerebelum_service") do
  nil ->
    cerebelum_attrs = %{
      id: cerebelum_service_id,
      client_id_string: "cerebelum_service",
      name: "Cerebelum Workflow Engine",
      client_type: :confidential,
      client_secret: "cerebelum_service_secret_change_in_production",
      organization_id: zea_org_id,
      redirect_uris: [],
      allowed_grant_types: ["client_credentials"],
      allowed_scopes: [
        "openid",
        "venture:fund.read",
        "venture:fund.write",
        "venture:capital_call.read",
        "venture:capital_call.write",
        "venture:investor.read",
        "venture:investor.write",
        "venture:distribution.read",
        "venture:distribution.write",
        "venture:dashboard",
        "venture:transaction.read",
        "venture:transaction.write",
        "sport:read",
        "sport:write"
      ],
      pkce_required: false
    }

    %OAuth2ClientSchema{}
    |> Ecto.Changeset.cast(cerebelum_attrs, [
      :id,
      :client_id_string,
      :name,
      :client_type,
      :client_secret,
      :organization_id,
      :redirect_uris,
      :allowed_grant_types,
      :allowed_scopes,
      :pkce_required
    ])
    |> Repo.insert!()

  existing ->
    :ok
end

# 4. Domain Roles (for subdomain finance services — validates JWT domain_roles)
# Services validate JWT claims.expect non-empty domain_roles
# Without these, all real-mode services return 401

domain_roles = [
  # owner@example.com — admin on default org
  %{
    user_id: c_user_id,
    organization_id: zea_org_id,
    domain: "fund_management",
    role: "gp_admin",
    scopes: ["read", "write"]
  },
  # owner@example.com — also on secondary org (cross-org access)
  %{
    user_id: c_user_id,
    organization_id: secondary_org_id,
    domain: "fund_management",
    role: "gp_admin",
    scopes: ["read", "write"]
  },
  # member@example.com — on secondary org
  %{
    user_id: member_user_id,
    organization_id: secondary_org_id,
    domain: "fund_management",
    role: "gp_admin",
    scopes: ["read", "write"]
  }
]

Enum.each(domain_roles, fn attrs ->
  existing =
    Repo.get_by(UserDomainRoleSchema,
      user_id: attrs.user_id,
      organization_id: attrs.organization_id,
      domain: attrs.domain
    )

  if is_nil(existing) do
    %UserDomainRoleSchema{}
    |> Ecto.Changeset.cast(attrs, [:user_id, :organization_id, :domain, :role, :scopes])
    |> Repo.insert!()
  end
end)

Logger.info("Thalamus database seeding completed successfully!")
