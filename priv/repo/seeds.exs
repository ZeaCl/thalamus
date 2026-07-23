alias Thalamus.Repo

alias Thalamus.Infrastructure.Persistence.Schemas.{
  UserSchema,
  OrganizationSchema,
  OAuth2ClientSchema,
  UserDomainRoleSchema
}

import Ecto.Query
require Logger

Logger.info("Starting ZEA database seeding...")

# 1. Organizations
zea_org_id = "ea7b11ea-852c-44e5-aee1-a761ec76eaea"
sudlich_org_id = "5fd11ea0-852c-44e5-aee1-a761ec76eaea"

# Create zea org
zea_org =
  case Repo.get(OrganizationSchema, zea_org_id) do
    nil ->
      org_attrs = %{
        id: zea_org_id,
        name: "ZEA",
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

# Create sudlich org
sudlich_org =
  case Repo.get(OrganizationSchema, sudlich_org_id) do
    nil ->
      org_attrs = %{
        id: sudlich_org_id,
        name: "Südlich",
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
ccerda_user_id = "c0000001-852c-44e5-aee1-a761ec76eaea"

c_pass_hash = Bcrypt.hash_pwd_salt("GusVicentAnto1.")
ccerda_pass_hash = Bcrypt.hash_pwd_salt("GusVicentAnto1.")

c_user =
  case Repo.get(UserSchema, c_user_id) || Repo.get_by(UserSchema, email: "c@zea.cl") do
    nil ->
      user_attrs = %{
        id: c_user_id,
        email: "c@zea.cl",
        name: "Carlos Hinostroza",
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

ccerda_user =
  case Repo.get(UserSchema, ccerda_user_id) || Repo.get_by(UserSchema, email: "ccerda@sudlich.cl") do
    nil ->
      user_attrs = %{
        id: ccerda_user_id,
        email: "ccerda@sudlich.cl",
        name: "Camila Cerda",
        password_hash: ccerda_pass_hash,
        organization_id: sudlich_org_id,
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
        name: "Admin Local",
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

# Update organization members arrays
# zea members
zea_members = [
  %{
    "user_id" => c_user_id,
    "email" => "c@zea.cl",
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

# sudlich members: includes ccerda@sudlich.cl (owner) and c@zea.cl (admin)
sudlich_members = [
  %{
    "user_id" => ccerda_user_id,
    "email" => "ccerda@sudlich.cl",
    "role" => "owner",
    "joined_at" => DateTime.to_iso8601(DateTime.utc_now())
  },
  %{
    "user_id" => c_user_id,
    "email" => "c@zea.cl",
    "role" => "admin",
    "joined_at" => DateTime.to_iso8601(DateTime.utc_now())
  }
]

sudlich_org
|> Ecto.Changeset.change(%{members: sudlich_members, current_user_count: 2})
|> Repo.update!()

# 3. OAuth Clients
platform_web_client_id = "59991e63-852c-44e5-aee1-a761ec76eaea"
thalamus_cli_client_id = "c1111111-852c-44e5-aee1-a761ec76eaea"

platform_web_uris = [
  "http://localhost:4000/auth/callback",
  "http://localhost:4001/auth/callback",
  "http://zea.localhost/auth/callback",
  "http://zea.localhost:3000/auth/callback",
  "http://sudlich.zea.localhost/auth/callback",
  "http://sudlich-soma.zea.localhost/auth/callback",
  "http://zea.localhost:4001/auth/callback",
  "http://sudlich.zea.localhost:4001/auth/callback",
  "https://zea.cl/auth/callback",
  "https://sudlich.zea.cl/auth/callback",
  # NextAuth callback URLs (provider-specific path)
  "http://localhost:3000/api/auth/callback/thalamus",
  "http://app.zea.localhost/api/auth/callback/thalamus"
]

case Repo.get(OAuth2ClientSchema, platform_web_client_id) ||
       Repo.get_by(OAuth2ClientSchema, client_id_string: "platform_web") do
  nil ->
    hashed_secret = Bcrypt.hash_pwd_salt("sq3Wafxd70wpqqVNrecK6zAYOYXggwb_kFgpuEWi4lE")

    client_attrs = %{
      id: platform_web_client_id,
      client_id_string: "platform_web",
      name: "ZEA Platform",
      client_type: :public,
      client_secret: hashed_secret,
      organization_id: zea_org_id,
      redirect_uris: platform_web_uris,
      allowed_grant_types: ["authorization_code", "refresh_token"],
      allowed_scopes: ["openid", "profile", "email", "zea:read", "zea:write"],
      pkce_required: true
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
      :pkce_required
    ])
    |> Repo.insert!()

  existing ->
    existing
    |> Ecto.Changeset.change(%{redirect_uris: platform_web_uris})
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
      client_secret: "cli_secret_does_not_matter_pkce_public_client",
      organization_id: zea_org_id,
      redirect_uris: cli_uris,
      allowed_grant_types: ["authorization_code", "refresh_token"],
      allowed_scopes: ["openid", "profile", "email", "zea:read", "zea:write"],
      pkce_required: true
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
      :pkce_required
    ])
    |> Repo.insert!()

  existing ->
    existing
    |> Ecto.Changeset.change(%{redirect_uris: cli_uris})
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
      allowed_grant_types: ["authorization_code", "refresh_token", "client_credentials", "password"],
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

  _existing ->
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

  _existing ->
    :ok
end

# 4. Domain Roles (required by subdomain services: fm_funds, fm_investors, fm_commitments, fm_capital_calls)
# Services validate JWT claims.expect non-empty domain_roles
# Without these, all real-mode services return 401

domain_roles = [
  # c@zea.cl — GP admin on ZEA org
  %{
    user_id: c_user_id,
    organization_id: zea_org_id,
    domain: "fund_management",
    role: "gp_admin",
    scopes: ["read", "write"]
  },
  # c@zea.cl — also admin on Südlich org (cross-org access)
  %{
    user_id: c_user_id,
    organization_id: sudlich_org_id,
    domain: "fund_management",
    role: "gp_admin",
    scopes: ["read", "write"]
  },
  # ccerda@sudlich.cl — GP admin on Südlich org
  %{
    user_id: ccerda_user_id,
    organization_id: sudlich_org_id,
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

Logger.info("ZEA database seeding completed successfully!")
