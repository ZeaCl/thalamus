defmodule Thalamus.Domain.Entities.Organization do
  @moduledoc """
  Organization Entity - Aggregate Root for multi-tenant organization management.

  Represents an organization (tenant) in the ZEA Thalamus system with
  subscription plans, member management, and settings.

  SOLID Principles Applied:
  - Single Responsibility: Manages organization state and behavior
  - Open/Closed: Extensible for new features without modification
  - Dependency Inversion: Uses Value Objects for data validation
  """

  alias Thalamus.Domain.ValueObjects.{OrganizationId, UserId, Email, Plan}

  defmodule Member do
    @moduledoc """
    Represents a member of an organization.
    """
    @type t :: %__MODULE__{
            user_id: UserId.t(),
            email: Email.t(),
            role: :owner | :admin | :member | :billing,
            joined_at: DateTime.t()
          }

    defstruct [:user_id, :email, :role, :joined_at]
  end

  @type member_role :: :owner | :admin | :member | :billing
  @type member :: Member.t()

  @type settings :: %{
          require_mfa: boolean(),
          allowed_domains: [String.t()],
          session_timeout_minutes: pos_integer(),
          ip_whitelist: [String.t()]
        }

  @type t :: %__MODULE__{
          id: OrganizationId.t(),
          name: String.t(),
          owner_email: Email.t(),
          plan: Plan.t(),
          members: [member()],
          settings: settings(),
          api_calls_this_month: non_neg_integer(),
          api_calls_current_month: non_neg_integer(),
          is_active: boolean(),
          status: :pending_verification | :active | :suspended | :inactive,
          verified_at: DateTime.t() | nil,
          max_users: pos_integer() | nil,
          max_api_calls_per_month: pos_integer() | nil,
          plan_type: atom(),
          created_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  defstruct [
    :id,
    :name,
    :owner_email,
    :plan,
    :members,
    :settings,
    :api_calls_this_month,
    :api_calls_current_month,
    :is_active,
    :status,
    :verified_at,
    :max_users,
    :max_api_calls_per_month,
    :plan_type,
    :created_at,
    :updated_at
  ]

  @valid_roles [:owner, :admin, :member, :billing]

  @doc """
  Creates a new Organization.

  ## Examples

      iex> {:ok, org_id} = OrganizationId.generate()
      iex> {:ok, user_id} = UserId.generate()
      iex> {:ok, plan} = Plan.free()
      iex> Organization.new(%{
      ...>   id: org_id,
      ...>   name: "Acme Corp",
      ...>   owner_id: user_id,
      ...>   plan: plan
      ...> })
      {:ok, %Organization{name: "Acme Corp", ...}}
  """
  def new(%{id: id, name: name, owner_id: owner_id, plan: plan} = attrs) do
    # Truncate to seconds for Ecto :utc_datetime compatibility
    now = DateTime.truncate(DateTime.utc_now(), :second)

    owner_member = %{
      user_id: owner_id,
      role: :owner,
      joined_at: now
    }

    default_settings = %{
      require_mfa: false,
      allowed_domains: [],
      session_timeout_minutes: 60,
      ip_whitelist: []
    }

    organization = %__MODULE__{
      id: id,
      name: name,
      plan: plan,
      members: [owner_member],
      settings: Map.get(attrs, :settings, default_settings),
      api_calls_this_month: 0,
      is_active: true,
      created_at: now,
      updated_at: now
    }

    case validate_organization(organization) do
      :ok -> {:ok, organization}
      {:error, reason} -> {:error, reason}
    end
  end

  def new(_), do: {:error, :missing_required_fields}

  @doc """
  Creates a new organization with an owner email.
  Convenience function that creates all necessary value objects.

  ## Examples

      iex> Organization.new("Acme Corp", "owner@acme.com")
      {:ok, %Organization{name: "Acme Corp", plan_type: :free}}
  """
  def new(name, owner_email_string, plan_type \\ :free)
      when is_binary(name) and is_binary(owner_email_string) do
    with {:ok, org_id} <- OrganizationId.generate(),
         {:ok, owner_email} <- Email.new(owner_email_string),
         {:ok, plan} <- Plan.new(plan_type) do
      # Truncate to seconds for Ecto :utc_datetime compatibility
      now = DateTime.truncate(DateTime.utc_now(), :second)

      # Convert :unlimited to large numbers for database storage (NOT NULL constraints)
      max_users =
        case plan.max_users do
          :unlimited -> 999_999
          count -> count
        end

      max_api_calls =
        case plan.max_api_calls_per_month do
          :unlimited -> 999_999_999
          count -> count
        end

      organization = %__MODULE__{
        id: org_id,
        name: name,
        owner_email: owner_email,
        plan: plan,
        plan_type: plan_type,
        members: [],
        settings: default_settings(),
        api_calls_this_month: 0,
        api_calls_current_month: 0,
        is_active: true,
        status: :pending_verification,
        verified_at: nil,
        max_users: max_users,
        max_api_calls_per_month: max_api_calls,
        created_at: now,
        updated_at: now
      }

      case validate_organization(organization) do
        :ok -> {:ok, organization}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc """
  Creates a new organization with an owner.
  Convenience function that creates all necessary value objects.

  ## Examples

      iex> {:ok, user_id} = UserId.generate()
      iex> Organization.create("Acme Corp", user_id)
      {:ok, %Organization{name: "Acme Corp", plan: %Plan{type: :free}}}
  """
  def create(name, %UserId{} = owner_id, plan_type \\ :free) do
    with {:ok, org_id} <- OrganizationId.generate(),
         {:ok, plan} <- Plan.new(plan_type) do
      new(%{
        id: org_id,
        name: name,
        owner_id: owner_id,
        plan: plan
      })
    end
  end

  @doc """
  Adds a member to the organization.

  ## Examples

      iex> {:ok, org} = Organization.create("Acme", owner_id)
      iex> {:ok, user_id} = UserId.generate()
      iex> Organization.add_member(org, user_id, :member)
      {:ok, %Organization{members: [_, _]}}
  """
  def add_member(%__MODULE__{} = org, %UserId{} = user_id, role) when role in @valid_roles do
    add_member(org, user_id, nil, role)
  end

  def add_member(%__MODULE__{} = org, %UserId{} = user_id, email, role)
      when role in @valid_roles and (is_nil(email) or is_struct(email, Thalamus.Domain.ValueObjects.Email)) do
    cond do
      member_exists?(org, user_id) ->
        {:error, :member_already_exists}

      not can_add_member?(org) ->
        {:error, :member_limit_reached}

      role == :owner ->
        {:error, :cannot_add_owner}

      true ->
        new_member = %__MODULE__.Member{
          user_id: user_id,
          email: email,
          role: role,
          joined_at: DateTime.utc_now()
        }

        {:ok, %{org | members: [new_member | org.members], updated_at: DateTime.utc_now()}}
    end
  end

  def add_member(_, _, _, _), do: {:error, :invalid_member_data}
  def add_member(_, _, _), do: {:error, :invalid_member_data}

  @doc """
  Removes a member from the organization.

  ## Examples

      iex> Organization.remove_member(org, user_id)
      {:ok, %Organization{members: [_]}}
  """
  def remove_member(%__MODULE__{} = org, %UserId{} = user_id) do
    cond do
      not member_exists?(org, user_id) ->
        {:error, :member_not_found}

      is_owner?(org, user_id) ->
        {:error, :cannot_remove_owner}

      true ->
        new_members = Enum.reject(org.members, fn member -> member.user_id == user_id end)
        {:ok, %{org | members: new_members, updated_at: DateTime.utc_now()}}
    end
  end

  @doc """
  Updates a member's role.

  ## Examples

      iex> Organization.update_member_role(org, user_id, :admin)
      {:ok, %Organization{}}
  """
  def update_member_role(%__MODULE__{} = org, %UserId{} = user_id, new_role)
      when new_role in @valid_roles do
    cond do
      not member_exists?(org, user_id) ->
        {:error, :member_not_found}

      is_owner?(org, user_id) and new_role != :owner ->
        {:error, :cannot_change_owner_role}

      new_role == :owner ->
        {:error, :cannot_promote_to_owner}

      true ->
        new_members =
          Enum.map(org.members, fn member ->
            if member.user_id == user_id do
              %{member | role: new_role}
            else
              member
            end
          end)

        {:ok, %{org | members: new_members, updated_at: DateTime.utc_now()}}
    end
  end

  def update_member_role(_, _, _), do: {:error, :invalid_role}

  @doc """
  Checks if a user is a member of the organization.

  ## Examples

      iex> Organization.member?(org, user_id)
      true
  """
  def member?(%__MODULE__{members: members}, %UserId{} = user_id) do
    Enum.any?(members, fn member -> member.user_id == user_id end)
  end

  @doc """
  Gets a member's role in the organization.

  ## Examples

      iex> Organization.get_member_role(org, user_id)
      {:ok, :admin}
  """
  def get_member_role(%__MODULE__{members: members}, %UserId{} = user_id) do
    case Enum.find(members, fn member -> member.user_id == user_id end) do
      nil -> {:error, :member_not_found}
      member -> {:ok, member.role}
    end
  end

  @doc """
  Checks if a user has a specific role or higher.

  ## Examples

      iex> Organization.has_role?(org, user_id, :admin)
      true
  """
  def has_role?(%__MODULE__{} = org, %UserId{} = user_id, required_role) do
    case get_member_role(org, user_id) do
      {:ok, role} -> role_level(role) >= role_level(required_role)
      {:error, _} -> false
    end
  end

  @doc """
  Upgrades the organization's plan.

  ## Examples

      iex> {:ok, org} = Organization.create("Acme", owner_id, :free)
      iex> Organization.upgrade_plan(org)
      {:ok, %Organization{plan: %Plan{type: :starter}}}
  """
  def upgrade_plan(%__MODULE__{plan: plan} = org) do
    case Plan.upgrade(plan) do
      {:ok, new_plan} ->
        {:ok, %{org | plan: new_plan, updated_at: DateTime.utc_now()}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Downgrades the organization's plan.

  ## Examples

      iex> Organization.downgrade_plan(org)
      {:ok, %Organization{plan: %Plan{type: :free}}}
  """
  def downgrade_plan(%__MODULE__{plan: plan} = org) do
    case Plan.downgrade(plan) do
      {:ok, new_plan} ->
        if can_downgrade_to_plan?(org, new_plan) do
          {:ok, %{org | plan: new_plan, updated_at: DateTime.utc_now()}}
        else
          {:error, :too_many_members_for_plan}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Records an API call for rate limiting.

  ## Examples

      iex> Organization.record_api_call(org)
      {:ok, %Organization{api_calls_this_month: 1}}
  """
  def record_api_call(%__MODULE__{} = org) do
    new_count = org.api_calls_this_month + 1

    if Plan.allows_api_calls?(org.plan, new_count) do
      {:ok, %{org | api_calls_this_month: new_count, updated_at: DateTime.utc_now()}}
    else
      {:error, :api_call_limit_exceeded}
    end
  end

  @doc """
  Resets the monthly API call counter.

  ## Examples

      iex> Organization.reset_api_calls(org)
      {:ok, %Organization{api_calls_this_month: 0}}
  """
  def reset_api_calls(%__MODULE__{} = org) do
    {:ok, %{org | api_calls_this_month: 0, updated_at: DateTime.utc_now()}}
  end

  @doc """
  Updates organization settings.

  ## Examples

      iex> Organization.update_settings(org, %{require_mfa: true})
      {:ok, %Organization{settings: %{require_mfa: true}}}
  """
  def update_settings(%__MODULE__{settings: current_settings} = org, new_settings)
      when is_map(new_settings) do
    updated_settings = Map.merge(current_settings, new_settings)

    case validate_settings(updated_settings) do
      :ok ->
        {:ok, %{org | settings: updated_settings, updated_at: DateTime.utc_now()}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def update_settings(_, _), do: {:error, :invalid_settings}

  @doc """
  Activates the organization.

  ## Examples

      iex> Organization.activate(org)
      {:ok, %Organization{is_active: true}}
  """
  def activate(%__MODULE__{} = org) do
    {:ok, %{org | is_active: true, updated_at: DateTime.utc_now()}}
  end

  @doc """
  Deactivates the organization.

  ## Examples

      iex> Organization.deactivate(org)
      {:ok, %Organization{is_active: false}}
  """
  def deactivate(%__MODULE__{} = org) do
    {:ok, %{org | is_active: false, updated_at: DateTime.utc_now()}}
  end

  @doc """
  Gets the count of members in the organization.

  ## Examples

      iex> Organization.member_count(org)
      5
  """
  def member_count(%__MODULE__{members: members}), do: length(members)

  # Private functions

  defp validate_organization(%__MODULE__{} = org) do
    cond do
      is_nil(org.id) -> {:error, :missing_organization_id}
      is_nil(org.name) or org.name == "" -> {:error, :missing_name}
      String.length(org.name) < 2 -> {:error, :name_too_short}
      String.length(org.name) > 100 -> {:error, :name_too_long}
      is_nil(org.owner_email) -> {:error, :missing_owner_email}
      is_nil(org.plan_type) -> {:error, :missing_plan_type}
      true -> :ok
    end
  end

  defp validate_settings(settings) do
    cond do
      not is_boolean(settings.require_mfa) ->
        {:error, :invalid_require_mfa}

      not is_list(settings.allowed_domains) ->
        {:error, :invalid_allowed_domains}

      not is_integer(settings.session_timeout_minutes) or
          settings.session_timeout_minutes < 5 ->
        {:error, :invalid_session_timeout}

      not is_list(settings.ip_whitelist) ->
        {:error, :invalid_ip_whitelist}

      true ->
        :ok
    end
  end

  defp member_exists?(%__MODULE__{members: members}, user_id) do
    Enum.any?(members, fn member -> member.user_id == user_id end)
  end

  defp is_owner?(%__MODULE__{members: members}, user_id) do
    Enum.any?(members, fn member ->
      member.user_id == user_id and member.role == :owner
    end)
  end

  # Helper function - currently unused but kept for future validation needs
  # defp has_owner?(%__MODULE__{members: members}) do
  #   Enum.any?(members, fn member -> member.role == :owner end)
  # end

  defp can_add_member?(%__MODULE__{max_users: nil}), do: true

  defp can_add_member?(%__MODULE__{max_users: max_users, members: members}) do
    length(members) + 1 <= max_users
  end

  defp can_downgrade_to_plan?(%__MODULE__{members: members}, %Thalamus.Domain.ValueObjects.Plan{type: plan_type}) do
    max_users = plan_max_users(plan_type)
    if is_nil(max_users), do: true, else: length(members) <= max_users
  end

  defp can_downgrade_to_plan?(%__MODULE__{members: members}, new_plan_type) when is_atom(new_plan_type) do
    max_users = plan_max_users(new_plan_type)
    if is_nil(max_users), do: true, else: length(members) <= max_users
  end

  defp plan_max_users(:free), do: 5
  defp plan_max_users(:basic), do: 25
  defp plan_max_users(:standard), do: 100
  defp plan_max_users(:enterprise), do: nil
  defp plan_max_users(_), do: nil

  # Role hierarchy: owner > admin > billing > member
  defp role_level(:owner), do: 4
  defp role_level(:admin), do: 3
  defp role_level(:billing), do: 2
  defp role_level(:member), do: 1

  # Plan limits are now retrieved from Plan value object configuration
  # No hardcoded values needed

  defp default_settings do
    %{
      require_mfa: false,
      allowed_domains: [],
      session_timeout_minutes: 60,
      ip_whitelist: []
    }
  end

  @doc """
  Suspends the organization.
  """
  def suspend(%__MODULE__{} = org) do
    {:ok, %{org | status: :suspended, is_active: false, updated_at: DateTime.utc_now()}}
  end

  @doc """
  Upgrades the organization's plan to a new plan type.

  The plan type should be a valid plan configured in your application.
  See `Thalamus.Domain.ValueObjects.Plan` for configuration details.
  """
  def upgrade_plan(%__MODULE__{} = org, new_plan_type) when is_atom(new_plan_type) do
    case Plan.new(new_plan_type) do
      {:ok, new_plan} ->
        # Convert :unlimited to large numbers for database storage (NOT NULL constraints)
        max_users =
          case new_plan.max_users do
            :unlimited -> 999_999
            count -> count
          end

        max_api_calls =
          case new_plan.max_api_calls_per_month do
            :unlimited -> 999_999_999
            count -> count
          end

        {:ok,
         %{
           org
           | plan: new_plan,
             plan_type: new_plan_type,
             max_users: max_users,
             max_api_calls_per_month: max_api_calls,
             updated_at: DateTime.utc_now()
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def upgrade_plan(_, _), do: {:error, :invalid_plan_type}
end

# Implement String.Chars protocol
defimpl String.Chars, for: Thalamus.Domain.Entities.Organization do
  def to_string(%Thalamus.Domain.Entities.Organization{name: name}) do
    "Organization<#{name}>"
  end
end

# Implement Jason.Encoder - safe serialization
defimpl Jason.Encoder, for: Thalamus.Domain.Entities.Organization do
  def encode(%Thalamus.Domain.Entities.Organization{} = org, opts) do
    %{
      id: org.id,
      name: org.name,
      plan: org.plan,
      member_count: Thalamus.Domain.Entities.Organization.member_count(org),
      is_active: org.is_active,
      created_at: org.created_at
    }
    |> Jason.Encode.map(opts)
  end
end
