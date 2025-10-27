defmodule Thalamus.Domain.Entities.OrganizationTest do
  use ExUnit.Case, async: true

  alias Thalamus.Domain.Entities.Organization
  alias Thalamus.Domain.ValueObjects.{OrganizationId, UserId, Plan}

  describe "new/1" do
    test "creates valid organization with required fields" do
      {:ok, org_id} = OrganizationId.generate()
      {:ok, user_id} = UserId.generate()
      {:ok, plan} = Plan.free()

      assert {:ok, %Organization{} = org} =
               Organization.new(%{
                 id: org_id,
                 name: "Acme Corp",
                 owner_id: user_id,
                 plan: plan
               })

      assert org.id == org_id
      assert org.name == "Acme Corp"
      assert org.plan == plan
      assert length(org.members) == 1
      assert hd(org.members).role == :owner
      assert org.api_calls_this_month == 0
      assert org.is_active == true
    end

    test "fails with missing required fields" do
      assert {:error, :missing_required_fields} = Organization.new(%{})
    end

    test "fails with name too short" do
      {:ok, org_id} = OrganizationId.generate()
      {:ok, user_id} = UserId.generate()
      {:ok, plan} = Plan.free()

      assert {:error, :name_too_short} =
               Organization.new(%{
                 id: org_id,
                 name: "A",
                 owner_id: user_id,
                 plan: plan
               })
    end

    test "fails with name too long" do
      {:ok, org_id} = OrganizationId.generate()
      {:ok, user_id} = UserId.generate()
      {:ok, plan} = Plan.free()

      long_name = String.duplicate("A", 101)

      assert {:error, :name_too_long} =
               Organization.new(%{
                 id: org_id,
                 name: long_name,
                 owner_id: user_id,
                 plan: plan
               })
    end
  end

  describe "create/3" do
    test "creates organization with default free plan" do
      {:ok, user_id} = UserId.generate()
      assert {:ok, %Organization{} = org} = Organization.create("Acme Corp", user_id)

      assert org.name == "Acme Corp"
      assert org.plan.type == :free
      assert length(org.members) == 1
    end

    test "creates organization with specified plan" do
      {:ok, user_id} = UserId.generate()
      assert {:ok, %Organization{} = org} = Organization.create("Acme Corp", user_id, :enterprise)

      assert org.plan.type == :enterprise
    end
  end

  describe "add_member/3" do
    test "successfully adds member to organization" do
      {:ok, user_id} = UserId.generate()
      {:ok, org} = Organization.create("Acme", user_id)
      {:ok, new_member_id} = UserId.generate()

      assert {:ok, updated_org} = Organization.add_member(org, new_member_id, :member)
      assert length(updated_org.members) == 2
      assert Organization.member?(updated_org, new_member_id)
    end

    test "fails when adding duplicate member" do
      {:ok, user_id} = UserId.generate()
      {:ok, org} = Organization.create("Acme", user_id)

      assert {:error, :member_already_exists} = Organization.add_member(org, user_id, :admin)
    end

    test "fails when member limit reached" do
      {:ok, user_id} = UserId.generate()
      {:ok, org} = Organization.create("Acme", user_id, :free)

      # Free plan allows 5 users, owner is already there, so add 4 more
      org =
        Enum.reduce(1..4, org, fn _, acc ->
          {:ok, member_id} = UserId.generate()
          {:ok, updated} = Organization.add_member(acc, member_id, :member)
          updated
        end)

      assert length(org.members) == 5

      # Try to add 6th member
      {:ok, extra_member} = UserId.generate()
      assert {:error, :member_limit_reached} = Organization.add_member(org, extra_member, :member)
    end

    test "fails when trying to add another owner" do
      {:ok, user_id} = UserId.generate()
      {:ok, org} = Organization.create("Acme", user_id)
      {:ok, new_member_id} = UserId.generate()

      assert {:error, :cannot_add_owner} = Organization.add_member(org, new_member_id, :owner)
    end

    test "allows adding members with different roles" do
      {:ok, user_id} = UserId.generate()
      {:ok, org} = Organization.create("Acme", user_id, :enterprise)

      {:ok, admin_id} = UserId.generate()
      {:ok, billing_id} = UserId.generate()
      {:ok, member_id} = UserId.generate()

      {:ok, org} = Organization.add_member(org, admin_id, :admin)
      {:ok, org} = Organization.add_member(org, billing_id, :billing)
      {:ok, org} = Organization.add_member(org, member_id, :member)

      assert {:ok, :admin} = Organization.get_member_role(org, admin_id)
      assert {:ok, :billing} = Organization.get_member_role(org, billing_id)
      assert {:ok, :member} = Organization.get_member_role(org, member_id)
    end
  end

  describe "remove_member/2" do
    test "successfully removes member from organization" do
      {:ok, user_id} = UserId.generate()
      {:ok, org} = Organization.create("Acme", user_id)
      {:ok, member_id} = UserId.generate()

      {:ok, org} = Organization.add_member(org, member_id, :member)
      assert {:ok, updated_org} = Organization.remove_member(org, member_id)
      assert length(updated_org.members) == 1
      refute Organization.member?(updated_org, member_id)
    end

    test "fails when removing non-existent member" do
      {:ok, user_id} = UserId.generate()
      {:ok, org} = Organization.create("Acme", user_id)
      {:ok, non_member_id} = UserId.generate()

      assert {:error, :member_not_found} = Organization.remove_member(org, non_member_id)
    end

    test "fails when trying to remove owner" do
      {:ok, user_id} = UserId.generate()
      {:ok, org} = Organization.create("Acme", user_id)

      assert {:error, :cannot_remove_owner} = Organization.remove_member(org, user_id)
    end
  end

  describe "update_member_role/3" do
    test "successfully updates member role" do
      {:ok, user_id} = UserId.generate()
      {:ok, org} = Organization.create("Acme", user_id)
      {:ok, member_id} = UserId.generate()

      {:ok, org} = Organization.add_member(org, member_id, :member)
      assert {:ok, updated_org} = Organization.update_member_role(org, member_id, :admin)
      assert {:ok, :admin} = Organization.get_member_role(updated_org, member_id)
    end

    test "fails when updating non-existent member" do
      {:ok, user_id} = UserId.generate()
      {:ok, org} = Organization.create("Acme", user_id)
      {:ok, non_member_id} = UserId.generate()

      assert {:error, :member_not_found} =
               Organization.update_member_role(org, non_member_id, :admin)
    end

    test "fails when trying to change owner role" do
      {:ok, user_id} = UserId.generate()
      {:ok, org} = Organization.create("Acme", user_id)

      assert {:error, :cannot_change_owner_role} =
               Organization.update_member_role(org, user_id, :admin)
    end

    test "fails when trying to promote to owner" do
      {:ok, user_id} = UserId.generate()
      {:ok, org} = Organization.create("Acme", user_id)
      {:ok, member_id} = UserId.generate()

      {:ok, org} = Organization.add_member(org, member_id, :admin)

      assert {:error, :cannot_promote_to_owner} =
               Organization.update_member_role(org, member_id, :owner)
    end
  end

  describe "has_role?/3" do
    test "checks role hierarchy correctly" do
      {:ok, owner_id} = UserId.generate()
      {:ok, org} = Organization.create("Acme", owner_id)
      {:ok, admin_id} = UserId.generate()
      {:ok, member_id} = UserId.generate()

      {:ok, org} = Organization.add_member(org, admin_id, :admin)
      {:ok, org} = Organization.add_member(org, member_id, :member)

      # Owner has all roles
      assert Organization.has_role?(org, owner_id, :owner)
      assert Organization.has_role?(org, owner_id, :admin)
      assert Organization.has_role?(org, owner_id, :member)

      # Admin has admin and member roles
      refute Organization.has_role?(org, admin_id, :owner)
      assert Organization.has_role?(org, admin_id, :admin)
      assert Organization.has_role?(org, admin_id, :member)

      # Member only has member role
      refute Organization.has_role?(org, member_id, :owner)
      refute Organization.has_role?(org, member_id, :admin)
      assert Organization.has_role?(org, member_id, :member)
    end
  end

  describe "upgrade_plan/1" do
    test "successfully upgrades from free to starter" do
      {:ok, user_id} = UserId.generate()
      {:ok, org} = Organization.create("Acme", user_id, :free)

      assert {:ok, upgraded_org} = Organization.upgrade_plan(org)
      assert upgraded_org.plan.type == :starter
    end

    test "fails when already at highest tier" do
      {:ok, user_id} = UserId.generate()
      {:ok, org} = Organization.create("Acme", user_id, :enterprise)

      assert {:error, :already_highest_tier} = Organization.upgrade_plan(org)
    end
  end

  describe "downgrade_plan/1" do
    test "successfully downgrades when within limits" do
      {:ok, user_id} = UserId.generate()
      {:ok, org} = Organization.create("Acme", user_id, :starter)

      assert {:ok, downgraded_org} = Organization.downgrade_plan(org)
      assert downgraded_org.plan.type == :free
    end

    test "fails when too many members for target plan" do
      {:ok, user_id} = UserId.generate()
      {:ok, org} = Organization.create("Acme", user_id, :enterprise)

      # Add 10 members (free plan only allows 5)
      org =
        Enum.reduce(1..10, org, fn _, acc ->
          {:ok, member_id} = UserId.generate()
          {:ok, updated} = Organization.add_member(acc, member_id, :member)
          updated
        end)

      # Try to downgrade to professional (100 users) - should work
      {:ok, org} = Organization.downgrade_plan(org)
      assert org.plan.type == :professional

      # Try to downgrade to starter (25 users) - should work
      {:ok, org} = Organization.downgrade_plan(org)
      assert org.plan.type == :starter

      # Try to downgrade to free (5 users) - should fail
      assert {:error, :too_many_members_for_plan} = Organization.downgrade_plan(org)
    end

    test "fails when already at lowest tier" do
      {:ok, user_id} = UserId.generate()
      {:ok, org} = Organization.create("Acme", user_id, :free)

      assert {:error, :already_lowest_tier} = Organization.downgrade_plan(org)
    end
  end

  describe "API call tracking" do
    test "records API calls" do
      {:ok, user_id} = UserId.generate()
      {:ok, org} = Organization.create("Acme", user_id)

      assert {:ok, updated_org} = Organization.record_api_call(org)
      assert updated_org.api_calls_this_month == 1

      assert {:ok, updated_org2} = Organization.record_api_call(updated_org)
      assert updated_org2.api_calls_this_month == 2
    end

    test "fails when API call limit exceeded" do
      {:ok, user_id} = UserId.generate()
      {:ok, org} = Organization.create("Acme", user_id, :free)

      # Free plan allows 10k calls
      org_with_calls = %{org | api_calls_this_month: 10_000}

      assert {:error, :api_call_limit_exceeded} =
               Organization.record_api_call(org_with_calls)
    end

    test "resets API call counter" do
      {:ok, user_id} = UserId.generate()
      {:ok, org} = Organization.create("Acme", user_id)
      {:ok, org} = Organization.record_api_call(org)
      {:ok, org} = Organization.record_api_call(org)

      assert org.api_calls_this_month == 2

      assert {:ok, reset_org} = Organization.reset_api_calls(org)
      assert reset_org.api_calls_this_month == 0
    end
  end

  describe "settings management" do
    test "updates organization settings" do
      {:ok, user_id} = UserId.generate()
      {:ok, org} = Organization.create("Acme", user_id)

      new_settings = %{
        require_mfa: true,
        allowed_domains: ["example.com"],
        session_timeout_minutes: 30
      }

      assert {:ok, updated_org} = Organization.update_settings(org, new_settings)
      assert updated_org.settings.require_mfa == true
      assert updated_org.settings.allowed_domains == ["example.com"]
      assert updated_org.settings.session_timeout_minutes == 30
    end

    test "fails with invalid session timeout" do
      {:ok, user_id} = UserId.generate()
      {:ok, org} = Organization.create("Acme", user_id)

      assert {:error, :invalid_session_timeout} =
               Organization.update_settings(org, %{session_timeout_minutes: 2})
    end
  end

  describe "activation/deactivation" do
    test "activates organization" do
      {:ok, user_id} = UserId.generate()
      {:ok, org} = Organization.create("Acme", user_id)

      {:ok, deactivated} = Organization.deactivate(org)
      assert {:ok, activated} = Organization.activate(deactivated)
      assert activated.is_active == true
    end

    test "deactivates organization" do
      {:ok, user_id} = UserId.generate()
      {:ok, org} = Organization.create("Acme", user_id)

      assert {:ok, deactivated} = Organization.deactivate(org)
      assert deactivated.is_active == false
    end
  end

  describe "protocols" do
    test "implements String.Chars protocol" do
      {:ok, user_id} = UserId.generate()
      {:ok, org} = Organization.create("Acme Corp", user_id)

      assert to_string(org) == "Organization<Acme Corp>"
    end

    test "implements Jason.Encoder protocol with safe serialization" do
      {:ok, user_id} = UserId.generate()
      {:ok, org} = Organization.create("Acme Corp", user_id)

      json = Jason.encode!(org)

      assert String.contains?(json, "Acme Corp")
      assert String.contains?(json, "\"member_count\":1")
      # Should not expose individual member details in summary
    end
  end
end
