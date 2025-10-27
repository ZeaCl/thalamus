# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Thalamus.Repo.insert!(%Thalamus.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Thalamus.Repo
alias Thalamus.Domain.Entities.{User, Organization, OAuth2Client}
alias Thalamus.Infrastructure.Repositories.{
  PostgreSQLUserRepository,
  PostgreSQLOrganizationRepository,
  PostgreSQLOAuth2ClientRepository
}

require Logger

Logger.info("Starting database seeding...")

# ============================================================================
# ORGANIZATIONS
# ============================================================================

Logger.info("Creating organizations...")

{:ok, acme_org} =
  case Organization.new("Acme Corporation", "owner@acme.com", :professional) do
    {:ok, org} ->
      verified_org = %{org | verified_at: DateTime.utc_now(), status: :active}
      PostgreSQLOrganizationRepository.save(verified_org)
  end

Logger.info("Created #{1} organizations")

# ============================================================================
# USERS
# ============================================================================

Logger.info("Creating users...")

{:ok, admin_user} =
  case User.register("admin@thalamus.dev", "AdminPassword123!") do
    {:ok, user} ->
      {:ok, verified_user} = User.verify_email(user)
      PostgreSQLUserRepository.save(verified_user)
  end

Logger.info("Created admin user: admin@thalamus.dev / AdminPassword123!")

Logger.info("")
Logger.info("Database seeding completed successfully!")
Logger.info("")
