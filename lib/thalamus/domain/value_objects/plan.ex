defmodule Thalamus.Domain.ValueObjects.Plan do
  @moduledoc """
  Value Object representing an organization subscription plan.

  SOLID Principles Applied:
  - Single Responsibility: Only handles plan type validation and features
  - Open/Closed: Can be extended for new plans without modification
  - Dependency Inversion: Plan definitions come from configuration

  ## Configuration

  Plans can be configured in your config files:

      config :thalamus, :organization_plans,
        available_plans: [:basic, :premium, :enterprise],
        default_plan: :basic,
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

  If no configuration is provided, a default set of plans will be used.
  """

  @type plan_type :: atom()
  @type t :: %__MODULE__{
          type: plan_type(),
          max_users: pos_integer() | :unlimited,
          max_api_calls_per_month: pos_integer() | :unlimited,
          mfa_required: boolean(),
          sso_enabled: boolean(),
          audit_logs_retention_days: pos_integer(),
          support_level: atom()
        }

  defstruct [
    :type,
    :max_users,
    :max_api_calls_per_month,
    :mfa_required,
    :sso_enabled,
    :audit_logs_retention_days,
    :support_level
  ]

  @doc """
  Creates a new Plan from a plan type or custom configuration.

  ## Examples

      # Using configured plan type
      iex> Plan.new(:free)
      {:ok, %Plan{type: :free, max_users: 5, ...}}

      # Using custom plan configuration
      iex> Plan.new(:custom, %{
      ...>   max_users: 50,
      ...>   max_api_calls_per_month: 250_000,
      ...>   mfa_required: false,
      ...>   sso_enabled: false,
      ...>   audit_logs_retention_days: 60,
      ...>   support_level: :email
      ...> })
      {:ok, %Plan{type: :custom, max_users: 50, ...}}

      iex> Plan.new(:invalid)
      {:error, :invalid_plan_type}
  """
  def new(type) when is_atom(type) do
    valid_types = get_valid_plan_types()

    if type in valid_types do
      {:ok, build_plan(type)}
    else
      {:error, :invalid_plan_type}
    end
  end

  def new(type, config) when is_atom(type) and is_map(config) do
    with :ok <- validate_plan_config(config) do
      {:ok, build_custom_plan(type, config)}
    end
  end

  def new(_), do: {:error, :invalid_plan_type}

  @doc """
  Returns the default plan type from configuration.

  ## Examples

      iex> Plan.default()
      {:ok, %Plan{type: :free, ...}}
  """
  def default do
    default_type = get_default_plan_type()
    new(default_type)
  end

  @doc """
  Returns all available plan types from configuration.

  ## Examples

      iex> Plan.available_types()
      [:free, :basic, :standard, :premium, :enterprise]
  """
  def available_types do
    get_valid_plan_types()
  end

  # Backward compatibility - these delegate to new/1
  # but will work with any configured plan names
  def free, do: new(:free)
  def basic, do: new(:basic)
  def standard, do: new(:standard)
  def premium, do: new(:premium)
  def enterprise, do: new(:enterprise)

  @doc """
  Checks if a plan allows a certain number of users.

  ## Examples

      iex> {:ok, plan} = Plan.free()
      iex> Plan.allows_users?(plan, 3)
      true

      iex> Plan.allows_users?(plan, 10)
      false

      iex> {:ok, enterprise} = Plan.enterprise()
      iex> Plan.allows_users?(enterprise, 1000)
      true
  """
  def allows_users?(%__MODULE__{max_users: :unlimited}, _count), do: true
  def allows_users?(%__MODULE__{max_users: max}, count), do: count <= max

  @doc """
  Checks if a plan allows a certain number of API calls.

  ## Examples

      iex> {:ok, plan} = Plan.free()
      iex> Plan.allows_api_calls?(plan, 5000)
      true

      iex> {:ok, enterprise} = Plan.enterprise()
      iex> Plan.allows_api_calls?(enterprise, 10_000_000)
      true
  """
  def allows_api_calls?(%__MODULE__{max_api_calls_per_month: :unlimited}, _count), do: true
  def allows_api_calls?(%__MODULE__{max_api_calls_per_month: max}, count), do: count <= max

  @doc """
  Checks if a plan requires MFA.

  ## Examples

      iex> {:ok, plan} = Plan.free()
      iex> Plan.requires_mfa?(plan)
      false

      iex> {:ok, enterprise} = Plan.enterprise()
      iex> Plan.requires_mfa?(enterprise)
      true
  """
  def requires_mfa?(%__MODULE__{mfa_required: required}), do: required

  @doc """
  Checks if a plan has SSO enabled.

  ## Examples

      iex> {:ok, plan} = Plan.free()
      iex> Plan.sso_enabled?(plan)
      false

      iex> {:ok, enterprise} = Plan.enterprise()
      iex> Plan.sso_enabled?(enterprise)
      true
  """
  def sso_enabled?(%__MODULE__{sso_enabled: enabled}), do: enabled

  @doc """
  Upgrades a plan to a higher tier based on configured plan hierarchy.

  ## Examples

      iex> {:ok, plan} = Plan.new(:free)
      iex> Plan.upgrade(plan)
      {:ok, %Plan{type: :basic}}

      iex> {:ok, top_plan} = Plan.new(:enterprise)
      iex> Plan.upgrade(top_plan)
      {:error, :already_highest_tier}
  """
  def upgrade(%__MODULE__{type: current_type}) do
    plan_hierarchy = get_plan_hierarchy()
    current_index = Enum.find_index(plan_hierarchy, &(&1 == current_type))

    if current_index == nil do
      {:error, :invalid_plan_type}
    else
      next_index = current_index + 1

      if next_index >= length(plan_hierarchy) do
        {:error, :already_highest_tier}
      else
        next_type = Enum.at(plan_hierarchy, next_index)
        new(next_type)
      end
    end
  end

  @doc """
  Downgrades a plan to a lower tier based on configured plan hierarchy.

  ## Examples

      iex> {:ok, plan} = Plan.new(:standard)
      iex> Plan.downgrade(plan)
      {:ok, %Plan{type: :basic}}

      iex> {:ok, lowest} = Plan.new(:free)
      iex> Plan.downgrade(lowest)
      {:error, :already_lowest_tier}
  """
  def downgrade(%__MODULE__{type: current_type}) do
    plan_hierarchy = get_plan_hierarchy()
    current_index = Enum.find_index(plan_hierarchy, &(&1 == current_type))

    if current_index == nil do
      {:error, :invalid_plan_type}
    else
      if current_index == 0 do
        {:error, :already_lowest_tier}
      else
        prev_type = Enum.at(plan_hierarchy, current_index - 1)
        new(prev_type)
      end
    end
  end

  # Private functions - Configuration Management

  defp get_plan_config do
    Application.get_env(:thalamus, :organization_plans, default_plan_config())
  end

  defp get_valid_plan_types do
    get_plan_config()
    |> Keyword.get(:available_plans, [:free, :basic, :standard, :premium, :enterprise])
  end

  defp get_default_plan_type do
    get_plan_config()
    |> Keyword.get(:default_plan, :free)
  end

  defp get_plan_hierarchy do
    get_plan_config()
    |> Keyword.get(:plan_hierarchy, [:free, :basic, :standard, :premium, :enterprise])
  end

  defp get_plan_definitions do
    get_plan_config()
    |> Keyword.get(:plan_configs, default_plan_definitions())
  end

  defp build_plan(type) when is_atom(type) do
    plan_definitions = get_plan_definitions()

    case Map.get(plan_definitions, type) do
      nil -> raise "Plan type #{type} not found in configuration"
      config -> build_custom_plan(type, config)
    end
  end

  defp build_custom_plan(type, config) do
    %__MODULE__{
      type: type,
      max_users: Map.get(config, :max_users),
      max_api_calls_per_month: Map.get(config, :max_api_calls_per_month),
      mfa_required: Map.get(config, :mfa_required, false),
      sso_enabled: Map.get(config, :sso_enabled, false),
      audit_logs_retention_days: Map.get(config, :audit_logs_retention_days, 30),
      support_level: Map.get(config, :support_level, :community)
    }
  end

  defp validate_plan_config(config) do
    required_fields = [:max_users, :max_api_calls_per_month]

    missing_fields =
      Enum.filter(required_fields, fn field ->
        not Map.has_key?(config, field)
      end)

    if Enum.empty?(missing_fields) do
      :ok
    else
      {:error, {:missing_fields, missing_fields}}
    end
  end

  # Default configuration (generic plans - configurable via Application config)
  defp default_plan_config do
    [
      available_plans: [:free, :basic, :standard, :premium, :enterprise],
      default_plan: :free,
      plan_hierarchy: [:free, :basic, :standard, :premium, :enterprise],
      plan_configs: default_plan_definitions()
    ]
  end

  defp default_plan_definitions do
    %{
      free: %{
        max_users: 5,
        max_api_calls_per_month: 10_000,
        mfa_required: false,
        sso_enabled: false,
        audit_logs_retention_days: 7,
        support_level: :community
      },
      basic: %{
        max_users: 25,
        max_api_calls_per_month: 100_000,
        mfa_required: false,
        sso_enabled: false,
        audit_logs_retention_days: 30,
        support_level: :email
      },
      standard: %{
        max_users: 100,
        max_api_calls_per_month: 500_000,
        mfa_required: true,
        sso_enabled: true,
        audit_logs_retention_days: 90,
        support_level: :priority
      },
      premium: %{
        max_users: 500,
        max_api_calls_per_month: 2_000_000,
        mfa_required: true,
        sso_enabled: true,
        audit_logs_retention_days: 180,
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
  end
end

# Implement String.Chars protocol
defimpl String.Chars, for: Thalamus.Domain.ValueObjects.Plan do
  def to_string(%Thalamus.Domain.ValueObjects.Plan{type: type}) do
    "Plan:#{type}"
  end
end

# Implement Jason.Encoder for JSON serialization
defimpl Jason.Encoder, for: Thalamus.Domain.ValueObjects.Plan do
  def encode(%Thalamus.Domain.ValueObjects.Plan{} = plan, opts) do
    %{
      type: plan.type,
      max_users: plan.max_users,
      max_api_calls_per_month: plan.max_api_calls_per_month,
      mfa_required: plan.mfa_required,
      sso_enabled: plan.sso_enabled,
      audit_logs_retention_days: plan.audit_logs_retention_days,
      support_level: plan.support_level
    }
    |> Jason.Encode.map(opts)
  end
end
