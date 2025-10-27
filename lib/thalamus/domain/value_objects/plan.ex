defmodule Thalamus.Domain.ValueObjects.Plan do
  @moduledoc """
  Value Object representing an organization subscription plan.

  SOLID Principles Applied:
  - Single Responsibility: Only handles plan type validation and features
  - Open/Closed: Can be extended for new plans without modification
  """

  @type plan_type :: :free | :starter | :professional | :enterprise
  @type t :: %__MODULE__{
          type: plan_type(),
          max_users: pos_integer() | :unlimited,
          max_api_calls_per_month: pos_integer() | :unlimited,
          mfa_required: boolean(),
          sso_enabled: boolean(),
          audit_logs_retention_days: pos_integer(),
          support_level: :community | :email | :priority | :dedicated
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

  @valid_types [:free, :starter, :professional, :enterprise]

  @doc """
  Creates a new Plan from a plan type.

  ## Examples

      iex> Plan.new(:free)
      {:ok, %Plan{type: :free, max_users: 5, ...}}

      iex> Plan.new(:enterprise)
      {:ok, %Plan{type: :enterprise, max_users: :unlimited, ...}}

      iex> Plan.new(:invalid)
      {:error, :invalid_plan_type}
  """
  def new(type) when type in @valid_types do
    {:ok, build_plan(type)}
  end

  def new(_), do: {:error, :invalid_plan_type}

  @doc """
  Creates a free plan.

  ## Examples

      iex> Plan.free()
      {:ok, %Plan{type: :free, max_users: 5}}
  """
  def free, do: new(:free)

  @doc """
  Creates a starter plan.

  ## Examples

      iex> Plan.starter()
      {:ok, %Plan{type: :starter, max_users: 25}}
  """
  def starter, do: new(:starter)

  @doc """
  Creates a professional plan.

  ## Examples

      iex> Plan.professional()
      {:ok, %Plan{type: :professional, max_users: 100}}
  """
  def professional, do: new(:professional)

  @doc """
  Creates an enterprise plan.

  ## Examples

      iex> Plan.enterprise()
      {:ok, %Plan{type: :enterprise, max_users: :unlimited}}
  """
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
  Upgrades a plan to a higher tier.

  ## Examples

      iex> {:ok, plan} = Plan.free()
      iex> Plan.upgrade(plan)
      {:ok, %Plan{type: :starter}}

      iex> {:ok, enterprise} = Plan.enterprise()
      iex> Plan.upgrade(enterprise)
      {:error, :already_highest_tier}
  """
  def upgrade(%__MODULE__{type: :free}), do: new(:starter)
  def upgrade(%__MODULE__{type: :starter}), do: new(:professional)
  def upgrade(%__MODULE__{type: :professional}), do: new(:enterprise)
  def upgrade(%__MODULE__{type: :enterprise}), do: {:error, :already_highest_tier}

  @doc """
  Downgrades a plan to a lower tier.

  ## Examples

      iex> {:ok, plan} = Plan.professional()
      iex> Plan.downgrade(plan)
      {:ok, %Plan{type: :starter}}

      iex> {:ok, free} = Plan.free()
      iex> Plan.downgrade(free)
      {:error, :already_lowest_tier}
  """
  def downgrade(%__MODULE__{type: :enterprise}), do: new(:professional)
  def downgrade(%__MODULE__{type: :professional}), do: new(:starter)
  def downgrade(%__MODULE__{type: :starter}), do: new(:free)
  def downgrade(%__MODULE__{type: :free}), do: {:error, :already_lowest_tier}

  # Private functions

  defp build_plan(:free) do
    %__MODULE__{
      type: :free,
      max_users: 5,
      max_api_calls_per_month: 10_000,
      mfa_required: false,
      sso_enabled: false,
      audit_logs_retention_days: 7,
      support_level: :community
    }
  end

  defp build_plan(:starter) do
    %__MODULE__{
      type: :starter,
      max_users: 25,
      max_api_calls_per_month: 100_000,
      mfa_required: false,
      sso_enabled: false,
      audit_logs_retention_days: 30,
      support_level: :email
    }
  end

  defp build_plan(:professional) do
    %__MODULE__{
      type: :professional,
      max_users: 100,
      max_api_calls_per_month: 1_000_000,
      mfa_required: true,
      sso_enabled: true,
      audit_logs_retention_days: 90,
      support_level: :priority
    }
  end

  defp build_plan(:enterprise) do
    %__MODULE__{
      type: :enterprise,
      max_users: :unlimited,
      max_api_calls_per_month: :unlimited,
      mfa_required: true,
      sso_enabled: true,
      audit_logs_retention_days: 365,
      support_level: :dedicated
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
