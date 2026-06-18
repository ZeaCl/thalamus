defmodule Thalamus.Domain.ValueObjects.PlanTest do
  use ExUnit.Case, async: false

  alias Thalamus.Domain.ValueObjects.Plan

  describe "new/1" do
    test "creates valid free plan" do
      assert {:ok, %Plan{type: :free}} = Plan.new(:free)
    end

    test "creates valid starter plan" do
      assert {:ok, %Plan{type: :basic}} = Plan.new(:basic)
    end

    test "creates valid professional plan" do
      assert {:ok, %Plan{type: :standard}} = Plan.new(:standard)
    end

    test "creates valid enterprise plan" do
      assert {:ok, %Plan{type: :enterprise}} = Plan.new(:enterprise)
    end

    test "fails with invalid plan type" do
      assert {:error, :invalid_plan_type} = Plan.new(:invalid)
      assert {:error, :invalid_plan_type} = Plan.new("free")
      assert {:error, :invalid_plan_type} = Plan.new(nil)
    end
  end

  describe "plan features" do
    test "free plan has correct limits" do
      {:ok, plan} = Plan.free()

      assert plan.max_users == 5
      assert plan.max_api_calls_per_month == 10_000
      assert plan.mfa_required == false
      assert plan.sso_enabled == false
      assert plan.audit_logs_retention_days == 7
      assert plan.support_level == :community
    end

    test "basic plan has correct limits" do
      {:ok, plan} = Plan.basic()

      assert plan.max_users == 25
      assert plan.max_api_calls_per_month == 100_000
      assert plan.mfa_required == false
      assert plan.sso_enabled == false
      assert plan.audit_logs_retention_days == 30
      assert plan.support_level == :email
    end

    test "standard plan has correct limits" do
      {:ok, plan} = Plan.standard()

      assert plan.max_users == 100
      assert plan.max_api_calls_per_month == 500_000
      assert plan.mfa_required == true
      assert plan.sso_enabled == true
      assert plan.audit_logs_retention_days == 90
      assert plan.support_level == :priority
    end

    test "premium plan has correct limits" do
      {:ok, plan} = Plan.premium()

      assert plan.max_users == 500
      assert plan.max_api_calls_per_month == 2_000_000
      assert plan.mfa_required == true
      assert plan.sso_enabled == true
      assert plan.audit_logs_retention_days == 180
      assert plan.support_level == :priority
    end

    test "enterprise plan has unlimited resources" do
      {:ok, plan} = Plan.enterprise()

      assert plan.max_users == :unlimited
      assert plan.max_api_calls_per_month == :unlimited
      assert plan.mfa_required == true
      assert plan.sso_enabled == true
      assert plan.audit_logs_retention_days == 365
      assert plan.support_level == :dedicated
    end
  end

  describe "allows_users?/2" do
    test "free plan allows up to 5 users" do
      {:ok, plan} = Plan.free()

      assert Plan.allows_users?(plan, 1)
      assert Plan.allows_users?(plan, 5)
      refute Plan.allows_users?(plan, 6)
      refute Plan.allows_users?(plan, 100)
    end

    test "enterprise plan allows unlimited users" do
      {:ok, plan} = Plan.enterprise()

      assert Plan.allows_users?(plan, 1)
      assert Plan.allows_users?(plan, 1000)
      assert Plan.allows_users?(plan, 1_000_000)
    end
  end

  describe "allows_api_calls?/2" do
    test "free plan allows up to 10k API calls" do
      {:ok, plan} = Plan.free()

      assert Plan.allows_api_calls?(plan, 1)
      assert Plan.allows_api_calls?(plan, 10_000)
      refute Plan.allows_api_calls?(plan, 10_001)
      refute Plan.allows_api_calls?(plan, 100_000)
    end

    test "enterprise plan allows unlimited API calls" do
      {:ok, plan} = Plan.enterprise()

      assert Plan.allows_api_calls?(plan, 1)
      assert Plan.allows_api_calls?(plan, 10_000_000)
      assert Plan.allows_api_calls?(plan, 1_000_000_000)
    end
  end

  describe "requires_mfa?/1" do
    test "free and basic do not require MFA" do
      {:ok, free} = Plan.free()
      {:ok, basic} = Plan.basic()

      refute Plan.requires_mfa?(free)
      refute Plan.requires_mfa?(basic)
    end

    test "standard, premium and enterprise require MFA" do
      {:ok, standard} = Plan.standard()
      {:ok, premium} = Plan.premium()
      {:ok, enterprise} = Plan.enterprise()

      assert Plan.requires_mfa?(standard)
      assert Plan.requires_mfa?(premium)
      assert Plan.requires_mfa?(enterprise)
    end
  end

  describe "sso_enabled?/1" do
    test "free and basic do not have SSO" do
      {:ok, free} = Plan.free()
      {:ok, basic} = Plan.basic()

      refute Plan.sso_enabled?(free)
      refute Plan.sso_enabled?(basic)
    end

    test "standard, premium and enterprise have SSO" do
      {:ok, standard} = Plan.standard()
      {:ok, premium} = Plan.premium()
      {:ok, enterprise} = Plan.enterprise()

      assert Plan.sso_enabled?(standard)
      assert Plan.sso_enabled?(premium)
      assert Plan.sso_enabled?(enterprise)
    end
  end

  describe "upgrade/1" do
    test "can upgrade from free to basic" do
      {:ok, plan} = Plan.free()
      assert {:ok, %Plan{type: :basic}} = Plan.upgrade(plan)
    end

    test "can upgrade from basic to standard" do
      {:ok, plan} = Plan.basic()
      assert {:ok, %Plan{type: :standard}} = Plan.upgrade(plan)
    end

    test "can upgrade from standard to premium" do
      {:ok, plan} = Plan.standard()
      assert {:ok, %Plan{type: :premium}} = Plan.upgrade(plan)
    end

    test "can upgrade from premium to enterprise" do
      {:ok, plan} = Plan.premium()
      assert {:ok, %Plan{type: :enterprise}} = Plan.upgrade(plan)
    end

    test "cannot upgrade from enterprise" do
      {:ok, plan} = Plan.enterprise()
      assert {:error, :already_highest_tier} = Plan.upgrade(plan)
    end
  end

  describe "downgrade/1" do
    test "can downgrade from enterprise to premium" do
      {:ok, plan} = Plan.enterprise()
      assert {:ok, %Plan{type: :premium}} = Plan.downgrade(plan)
    end

    test "can downgrade from premium to standard" do
      {:ok, plan} = Plan.premium()
      assert {:ok, %Plan{type: :standard}} = Plan.downgrade(plan)
    end

    test "can downgrade from standard to basic" do
      {:ok, plan} = Plan.standard()
      assert {:ok, %Plan{type: :basic}} = Plan.downgrade(plan)
    end

    test "can downgrade from basic to free" do
      {:ok, plan} = Plan.basic()
      assert {:ok, %Plan{type: :free}} = Plan.downgrade(plan)
    end

    test "cannot downgrade from free" do
      {:ok, plan} = Plan.free()
      assert {:error, :already_lowest_tier} = Plan.downgrade(plan)
    end
  end

  describe "protocols" do
    test "implements String.Chars protocol" do
      {:ok, plan} = Plan.free()
      assert to_string(plan) == "Plan:free"
    end

    test "implements Jason.Encoder protocol" do
      {:ok, plan} = Plan.standard()
      json = Jason.encode!(plan)

      assert String.contains?(json, "standard")
      assert String.contains?(json, "\"max_users\":100")
      assert String.contains?(json, "\"mfa_required\":true")
    end
  end
end
