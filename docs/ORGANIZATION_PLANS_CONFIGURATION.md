# Organization Plans Configuration Guide

**Date**: January 20, 2026
**Status**: Production-Ready
**Feature**: Configurable Organization Subscription Plans

---

## Overview

Thalamus supports fully configurable organization subscription plans. You can define your own plan types, limits, and features without modifying any code.

This makes Thalamus suitable for any SaaS business model:
- Freemium apps
- Tiered subscription services
- Enterprise licensing models
- Custom pricing tiers

---

## Quick Start

### Using Default Plans

If you don't provide any configuration, Thalamus uses these default plans:

| Plan | Max Users | API Calls/Month | MFA Required | SSO | Audit Logs | Support |
|------|-----------|----------------|--------------|-----|------------|---------|
| `free` | 5 | 10,000 | No | No | 7 days | Community |
| `starter` | 25 | 100,000 | No | No | 30 days | Email |
| `professional` | 100 | 1,000,000 | Yes | Yes | 90 days | Priority |
| `enterprise` | Unlimited | Unlimited | Yes | Yes | 365 days | Dedicated |

These defaults are backward-compatible with existing ZEA setup.

---

## Custom Configuration

### Configuration Location

Add your plan configuration to `config/runtime.exs` (or any config file):

```elixir
config :thalamus, :organization_plans,
  # List of available plan types
  available_plans: [:basic, :premium, :enterprise],

  # Default plan for new organizations
  default_plan: :basic,

  # Plan hierarchy for upgrades/downgrades (lowest to highest)
  plan_hierarchy: [:basic, :premium, :enterprise],

  # Plan configurations
  plan_configs: %{
    basic: %{
      max_users: 10,
      max_api_calls_per_month: 50_000,
      mfa_required: false,
      sso_enabled: false,
      audit_logs_retention_days: 30,
      support_level: :email
    },
    premium: %{
      max_users: 100,
      max_api_calls_per_month: 500_000,
      mfa_required: true,
      sso_enabled: true,
      audit_logs_retention_days: 90,
      support_level: :priority
    },
    enterprise: %{
      max_users: :unlimited,
      max_api_calls_per_month: :unlimited,
      mfa_required: true,
      sso_enabled: true,
      audit_logs_retention_days: 365,
      support_level: :dedicated
    }
  }
```

### Configuration Options

#### Top-Level Options

| Option | Type | Required | Description |
|--------|------|----------|-------------|
| `available_plans` | List of atoms | Yes | All plan types your app supports |
| `default_plan` | Atom | Yes | Default plan for new organizations |
| `plan_hierarchy` | List of atoms | Yes | Order of plans from lowest to highest (for upgrades/downgrades) |
| `plan_configs` | Map | Yes | Configuration for each plan type |

#### Plan Configuration Fields

Each plan in `plan_configs` supports:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `max_users` | Integer or `:unlimited` | Yes | Maximum users allowed |
| `max_api_calls_per_month` | Integer or `:unlimited` | Yes | Monthly API call limit |
| `mfa_required` | Boolean | No (default: false) | Whether MFA is mandatory |
| `sso_enabled` | Boolean | No (default: false) | Whether SSO is available |
| `audit_logs_retention_days` | Integer | No (default: 30) | Days to retain audit logs |
| `support_level` | Atom | No (default: :community) | Support tier (`:community`, `:email`, `:priority`, `:dedicated`) |

---

## Example Configurations

### Freemium SaaS

```elixir
config :thalamus, :organization_plans,
  available_plans: [:free, :pro, :business],
  default_plan: :free,
  plan_hierarchy: [:free, :pro, :business],
  plan_configs: %{
    free: %{
      max_users: 3,
      max_api_calls_per_month: 1_000,
      mfa_required: false,
      sso_enabled: false,
      audit_logs_retention_days: 7,
      support_level: :community
    },
    pro: %{
      max_users: 25,
      max_api_calls_per_month: 100_000,
      mfa_required: false,
      sso_enabled: false,
      audit_logs_retention_days: 30,
      support_level: :email
    },
    business: %{
      max_users: :unlimited,
      max_api_calls_per_month: :unlimited,
      mfa_required: true,
      sso_enabled: true,
      audit_logs_retention_days: 365,
      support_level: :priority
    }
  }
```

### Enterprise Only

```elixir
config :thalamus, :organization_plans,
  available_plans: [:standard, :enterprise],
  default_plan: :standard,
  plan_hierarchy: [:standard, :enterprise],
  plan_configs: %{
    standard: %{
      max_users: 50,
      max_api_calls_per_month: 500_000,
      mfa_required: true,
      sso_enabled: true,
      audit_logs_retention_days: 90,
      support_level: :priority
    },
    enterprise: %{
      max_users: :unlimited,
      max_api_calls_per_month: :unlimited,
      mfa_required: true,
      sso_enabled: true,
      audit_logs_retention_days: 730,  # 2 years
      support_level: :dedicated
    }
  }
```

### Single Tier

```elixir
config :thalamus, :organization_plans,
  available_plans: [:standard],
  default_plan: :standard,
  plan_hierarchy: [:standard],
  plan_configs: %{
    standard: %{
      max_users: 100,
      max_api_calls_per_month: 1_000_000,
      mfa_required: true,
      sso_enabled: true,
      audit_logs_retention_days: 90,
      support_level: :email
    }
  }
```

---

## API Usage

### Creating Organizations

Organizations are created with the default plan:

```bash
POST /api/organizations
{
  "name": "Acme Corp",
  "owner_email": "owner@acme.com"
}
# Created with default_plan (:basic in examples above)
```

Or specify a plan:

```bash
POST /api/organizations
{
  "name": "Acme Corp",
  "owner_email": "owner@acme.com",
  "plan_type": "premium"
}
```

### Upgrading Plans

```bash
PATCH /api/organizations/:id
{
  "plan_type": "enterprise"
}
```

### Checking Plan Limits

The Plan value object provides helper functions:

```elixir
{:ok, plan} = Thalamus.Domain.ValueObjects.Plan.new(:premium)

# Check if plan allows certain number of users
Plan.allows_users?(plan, 50)  # true
Plan.allows_users?(plan, 200)  # false

# Check API call limits
Plan.allows_api_calls?(plan, 400_000)  # true
Plan.allows_api_calls?(plan, 600_000)  # false

# Check features
Plan.requires_mfa?(plan)  # true
Plan.sso_enabled?(plan)   # true

# Upgrade/downgrade
{:ok, upgraded} = Plan.upgrade(plan)  # Returns :enterprise plan
{:ok, downgraded} = Plan.downgrade(plan)  # Returns :basic plan
```

---

## Plan Enforcement

Thalamus automatically enforces plan limits:

### User Limits

When adding members to an organization:

```elixir
# This will fail if organization is at max_users limit
Organization.add_member(org, user_id, email, :member)
# Returns: {:error, :max_users_reached}
```

### API Rate Limits

API call limits are tracked per organization:

```elixir
# Tracked automatically in organization.api_calls_current_month
# Reset monthly based on organization.created_at
```

---

## Migration Guide

### Migrating from Hardcoded Plans

If you're updating from an older version with hardcoded plans:

1. **No action required** - Default configuration matches old behavior
2. **Optional**: Add custom configuration to match your needs
3. **Run migrations**: No database changes needed
4. **Test**: Existing tests should pass

### Changing Plan Names

If you want to rename existing plans:

1. Update configuration with new names
2. Create a migration to update `organizations.plan_type` column:

```elixir
defmodule Thalamus.Repo.Migrations.RenamePlanTypes do
  use Ecto.Migration

  def up do
    execute "UPDATE organizations SET plan_type = 'basic' WHERE plan_type = 'free'"
    execute "UPDATE organizations SET plan_type = 'premium' WHERE plan_type = 'professional'"
  end

  def down do
    execute "UPDATE organizations SET plan_type = 'free' WHERE plan_type = 'basic'"
    execute "UPDATE organizations SET plan_type = 'professional' WHERE plan_type = 'premium'"
  end
end
```

---

## Advanced Features

### Custom Plan Logic

You can create custom plan types programmatically:

```elixir
# Create a custom one-off plan
{:ok, custom_plan} = Plan.new(:vip, %{
  max_users: 500,
  max_api_calls_per_month: 10_000_000,
  mfa_required: true,
  sso_enabled: true,
  audit_logs_retention_days: 730,
  support_level: :dedicated
})
```

### Plan Hierarchy

The `plan_hierarchy` list defines upgrade/downgrade paths:

```elixir
# With hierarchy: [:free, :starter, :pro, :enterprise]
{:ok, plan} = Plan.new(:starter)
{:ok, upgraded} = Plan.upgrade(plan)  # Returns :pro
{:ok, downgraded} = Plan.downgrade(plan)  # Returns :free
```

Upgrading from the highest tier or downgrading from the lowest returns an error:

```elixir
{:ok, enterprise} = Plan.new(:enterprise)
Plan.upgrade(enterprise)  # {:error, :already_highest_tier}

{:ok, free} = Plan.new(:free)
Plan.downgrade(free)  # {:error, :already_lowest_tier}
```

---

## Testing

### Test Configuration

In `config/test.exs`, you can use simplified plans:

```elixir
config :thalamus, :organization_plans,
  available_plans: [:test_basic, :test_premium],
  default_plan: :test_basic,
  plan_hierarchy: [:test_basic, :test_premium],
  plan_configs: %{
    test_basic: %{
      max_users: 5,
      max_api_calls_per_month: 1_000,
      mfa_required: false,
      sso_enabled: false,
      audit_logs_retention_days: 7,
      support_level: :email
    },
    test_premium: %{
      max_users: 50,
      max_api_calls_per_month: 10_000,
      mfa_required: true,
      sso_enabled: true,
      audit_logs_retention_days: 30,
      support_level: :priority
    }
  }
```

### Test Helpers

```elixir
# In your tests
test "respects plan limits" do
  {:ok, org} = Organization.new("Test Corp", "owner@test.com", :test_basic)

  # Add users up to limit
  assert {:ok, _} = Organization.add_member(org, user1_id, email1, :member)
  # ... add 4 more users ...

  # Attempt to add beyond limit
  assert {:error, :max_users_reached} =
    Organization.add_member(org, user6_id, email6, :member)
end
```

---

## Troubleshooting

### Issue: Invalid Plan Type Error

**Symptom**: `{:error, :invalid_plan_type}` when creating organizations

**Solution**: Ensure the plan type is in your `available_plans` list

### Issue: Plan Configuration Not Loading

**Symptom**: Using default plans instead of custom configuration

**Solution**:
1. Check configuration is in `config/runtime.exs` or loaded config file
2. Restart your application
3. Verify with: `Application.get_env(:thalamus, :organization_plans)`

### Issue: Can't Upgrade/Downgrade Plans

**Symptom**: Upgrade/downgrade returns errors

**Solution**: Ensure `plan_hierarchy` includes both current and target plans in correct order

---

## Best Practices

1. **Start Simple**: Begin with 2-3 plans, add more as needed
2. **Consistent Naming**: Use lowercase atoms (`:basic`, `:premium`, not `:Basic`, `:PREMIUM`)
3. **Logical Hierarchy**: Order plans from lowest to highest value
4. **Reasonable Limits**: Set limits based on actual resource constraints
5. **Document Changes**: Keep a changelog when modifying plan configurations
6. **Test Thoroughly**: Verify plan limits work as expected in staging
7. **Monitor Usage**: Track actual usage vs. plan limits to inform pricing

---

## Related Documentation

- [Organization Management API](OPENAPI_SPEC.yaml#organizations)
- [Multi-Tenancy Guide](../README.md#multi-tenancy)
- [Rate Limiting](../README.md#rate-limiting)

---

## Support

For questions or issues with plan configuration:
- GitHub Issues: https://github.com/zeainc/thalamus/issues
- Documentation: Check README.md and CLAUDE.md

---

**Note**: This feature makes Thalamus a truly reusable, generic OAuth2 server suitable for any business model. Plans are no longer hardcoded to ZEA-specific tiers.
