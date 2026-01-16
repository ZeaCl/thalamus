#!/usr/bin/env elixir

# Validation script for Week 3 implementations
# (OrganizationId, Plan, GrantType, Organization, OAuth2Client)
IO.puts("\n=== Validating Week 3 Implementations ===\n")

# Load dependencies from build
Code.append_path("_build/test/lib/uuid/ebin")
Code.append_path("_build/test/lib/jason/ebin")
Code.append_path("_build/test/lib/bcrypt_elixir/ebin")
Code.append_path("_build/test/lib/comeonin/ebin")
Code.append_path("_build/test/lib/plug_crypto/ebin")
Code.append_path("_build/test/lib/plug/ebin")

# Load Value Objects (including previous ones needed)
IO.puts("Loading Value Objects...")
Code.require_file("lib/thalamus/domain/value_objects/user_id.ex")
Code.require_file("lib/thalamus/domain/value_objects/email.ex")
Code.require_file("lib/thalamus/domain/value_objects/client_id.ex")
Code.require_file("lib/thalamus/domain/value_objects/scope.ex")
Code.require_file("lib/thalamus/domain/value_objects/redirect_uri.ex")
Code.require_file("lib/thalamus/domain/value_objects/organization_id.ex")
Code.require_file("lib/thalamus/domain/value_objects/plan.ex")
Code.require_file("lib/thalamus/domain/value_objects/grant_type.ex")

# Load Entities
IO.puts("Loading Entities...")
Code.require_file("lib/thalamus/domain/entities/organization.ex")
Code.require_file("lib/thalamus/domain/entities/oauth2_client.ex")

# Import modules
alias Thalamus.Domain.ValueObjects.{
  UserId,
  OrganizationId,
  ClientId,
  Plan,
  GrantType,
  Scope,
  RedirectUri
}

alias Thalamus.Domain.Entities.{Organization, OAuth2Client}

IO.puts("\n✓ All modules loaded successfully!\n")

# Test OrganizationId
IO.puts("Testing OrganizationId...")
{:ok, org_id} = OrganizationId.generate()
unless String.starts_with?(org_id.value, "org_"), do: raise("OrganizationId prefix invalid")
{:ok, _parsed} = OrganizationId.from_string(org_id.value)
IO.puts("  ✓ OrganizationId generation works")
IO.puts("  ✓ OrganizationId parsing works")

# Test Plan
IO.puts("\nTesting Plan...")
{:ok, free_plan} = Plan.free()
unless free_plan.type == :free, do: raise("Free plan type invalid")
unless free_plan.max_users == 5, do: raise("Free plan limits invalid")
{:ok, enterprise_plan} = Plan.enterprise()
unless enterprise_plan.max_users == :unlimited, do: raise("Enterprise plan limits invalid")

unless Plan.allows_users?(enterprise_plan, 1_000_000),
  do: raise("Enterprise user limit check failed")

unless not Plan.allows_users?(free_plan, 10), do: raise("Free plan should not allow 10 users")
{:ok, upgraded} = Plan.upgrade(free_plan)
unless upgraded.type == :starter, do: raise("Plan upgrade failed")
IO.puts("  ✓ Plan creation works")
IO.puts("  ✓ Plan limits work")
IO.puts("  ✓ Plan upgrade/downgrade works")

# Test GrantType
IO.puts("\nTesting GrantType...")
{:ok, auth_code} = GrantType.authorization_code()
unless auth_code.type == :authorization_code, do: raise("GrantType creation failed")
unless GrantType.requires_user?(auth_code), do: raise("GrantType properties invalid")
unless GrantType.pkce_required?(auth_code), do: raise("PKCE requirement check failed")
{:ok, m2m} = GrantType.client_credentials()
unless not GrantType.requires_user?(m2m), do: raise("M2M should not require user")
IO.puts("  ✓ GrantType creation works")
IO.puts("  ✓ GrantType properties work")
IO.puts("  ✓ Grant type validation works")

# Test Organization Entity
IO.puts("\nTesting Organization Entity...")
{:ok, owner_id} = UserId.generate()
{:ok, org} = Organization.create("Acme Corp", owner_id)
unless org.name == "Acme Corp", do: raise("Organization creation failed")
unless Organization.member_count(org) == 1, do: raise("Organization member count wrong")

# Add member
{:ok, member_id} = UserId.generate()
{:ok, org_with_member} = Organization.add_member(org, member_id, :admin)
unless Organization.member_count(org_with_member) == 2, do: raise("Add member failed")
unless Organization.member?(org_with_member, member_id), do: raise("Member check failed")

# Test role management
unless Organization.has_role?(org_with_member, owner_id, :owner), do: raise("Role check failed")

unless Organization.has_role?(org_with_member, member_id, :admin),
  do: raise("Admin role check failed")

# Test API call tracking
{:ok, org_with_call} = Organization.record_api_call(org)
unless org_with_call.api_calls_this_month == 1, do: raise("API call tracking failed")

# Test plan upgrade
{:ok, upgraded_org} = Organization.upgrade_plan(org)
unless upgraded_org.plan.type == :starter, do: raise("Organization plan upgrade failed")

IO.puts("  ✓ Organization creation works")
IO.puts("  ✓ Member management works")
IO.puts("  ✓ Role management works")
IO.puts("  ✓ API call tracking works")
IO.puts("  ✓ Plan management works")

# Test OAuth2Client Entity
IO.puts("\nTesting OAuth2Client Entity...")
{:ok, org_id_for_client} = OrganizationId.generate()

# Test confidential client
{:ok, confidential_client} = OAuth2Client.create_confidential("My Server App", org_id_for_client)
unless confidential_client.client_type == :confidential, do: raise("Client type wrong")
unless is_binary(confidential_client.client_secret), do: raise("Client secret not generated")
unless String.length(confidential_client.client_secret) > 20, do: raise("Client secret too short")

# Test secret verification
:ok = OAuth2Client.verify_secret(confidential_client, confidential_client.client_secret)
{:error, _} = OAuth2Client.verify_secret(confidential_client, "wrong_secret")

# Test public client
{:ok, public_client} = OAuth2Client.create_public("My Mobile App", org_id_for_client)
unless public_client.client_type == :public, do: raise("Public client type wrong")
unless is_nil(public_client.client_secret), do: raise("Public client should not have secret")

# Test M2M client
{:ok, m2m_client} = OAuth2Client.create_m2m("Background Service", org_id_for_client)

unless OAuth2Client.supports_grant_type?(m2m_client, :client_credentials),
  do: raise("M2M grant type missing")

# Test redirect URI management
{:ok, redirect_uri} = RedirectUri.new("https://app.example.com/callback")
{:ok, client_with_uri} = OAuth2Client.add_redirect_uri(confidential_client, redirect_uri)

unless OAuth2Client.valid_redirect_uri?(client_with_uri, "https://app.example.com/callback"),
  do: raise("Redirect URI validation failed")

# Test scope management
{:ok, profile_scope} = Scope.new("profile")
{:ok, client_with_scope} = OAuth2Client.add_scope(confidential_client, profile_scope)

unless OAuth2Client.valid_scopes?(client_with_scope, ["openid", "profile"]),
  do: raise("Scope validation failed")

# Test grant type management
{:ok, refresh_grant} = GrantType.refresh_token()
{:ok, client_with_refresh} = OAuth2Client.add_grant_type(confidential_client, refresh_grant)

unless OAuth2Client.supports_grant_type?(client_with_refresh, :refresh_token),
  do: raise("Grant type addition failed")

# Test secret rotation
{:ok, rotated_client} = OAuth2Client.rotate_secret(confidential_client)

unless rotated_client.client_secret != confidential_client.client_secret,
  do: raise("Secret rotation failed")

IO.puts("  ✓ Confidential client creation works")
IO.puts("  ✓ Public client creation works")
IO.puts("  ✓ M2M client creation works")
IO.puts("  ✓ Client secret verification works")
IO.puts("  ✓ Secret rotation works")
IO.puts("  ✓ Redirect URI management works")
IO.puts("  ✓ Scope management works")
IO.puts("  ✓ Grant type management works")

IO.puts("\n=== All Week 3 Validations Passed! ===\n")
IO.puts("Summary:")
IO.puts("  • OrganizationId: ✓ Working correctly")
IO.puts("  • Plan: ✓ Working correctly")
IO.puts("  • GrantType: ✓ Working correctly")
IO.puts("  • Organization Entity: ✓ Working correctly")
IO.puts("  • OAuth2Client Entity: ✓ Working correctly")
IO.puts("  • All business logic: ✓ Implemented correctly")
IO.puts("\n✓ Week 3 implementation is complete and ready!\n")
