defmodule Thalamus.Domain.Entities.User do
  @moduledoc """
  User Entity - Aggregate Root for user management and authentication.

  Represents a user in the ZEA Thalamus authentication system with all
  authentication-related state and business logic.

  SOLID Principles Applied:
  - Single Responsibility: Manages user authentication state and behavior
  - Open/Closed: Extensible for new authentication methods without modification
  - Dependency Inversion: Uses Value Objects for data validation
  """

  alias Thalamus.Domain.ValueObjects.{UserId, Email, PasswordHash, MFAMethod}

  @type status :: :active | :suspended | :deactivated | :pending_verification
  @type t :: %__MODULE__{
          id: UserId.t(),
          email: Email.t(),
          name: String.t() | nil,
          password_hash: PasswordHash.t(),
          mfa_methods: [MFAMethod.t()],
          status: status(),
          failed_login_attempts: non_neg_integer(),
          locked_until: DateTime.t() | nil,
          created_at: DateTime.t(),
          verified_at: DateTime.t() | nil,
          last_login_at: DateTime.t() | nil,
          updated_at: DateTime.t(),
          is_agent: boolean(),
          agent_config: map()
        }

  defstruct [
    :id,
    :email,
    :name,
    :password_hash,
    :mfa_methods,
    :status,
    :failed_login_attempts,
    :locked_until,
    :created_at,
    :verified_at,
    :last_login_at,
    :updated_at,
    :is_agent,
    :agent_config
  ]

  @max_failed_login_attempts 5
  @account_lock_duration_minutes 30

  @doc """
  Creates a new User with the given attributes.

  ## Examples

      iex> {:ok, user_id} = UserId.generate()
      iex> {:ok, email} = Email.new("user@example.com")
      iex> {:ok, password_hash} = PasswordHash.from_password("SecureP@ssw0rd!")
      iex> User.new(%{
      ...>   id: user_id,
      ...>   email: email,
      ...>   password_hash: password_hash
      ...> })
      {:ok, %User{status: :pending_verification, ...}}

      iex> User.new(%{})
      {:error, :missing_required_fields}
  """
  def new(%{id: id, email: email, password_hash: password_hash} = attrs) do
    # Truncate to seconds for Ecto :utc_datetime compatibility
    now = DateTime.truncate(DateTime.utc_now(), :second)

    user = %__MODULE__{
      id: id,
      email: email,
      name: Map.get(attrs, :name),
      password_hash: password_hash,
      mfa_methods: Map.get(attrs, :mfa_methods, []),
      status: Map.get(attrs, :status, :pending_verification),
      failed_login_attempts: 0,
      locked_until: nil,
      created_at: Map.get(attrs, :created_at, now),
      verified_at: Map.get(attrs, :verified_at),
      last_login_at: Map.get(attrs, :last_login_at),
      updated_at: now,
      is_agent: Map.get(attrs, :is_agent, false),
      agent_config: Map.get(attrs, :agent_config, nil)
    }

    case validate_user(user) do
      :ok -> {:ok, user}
      {:error, reason} -> {:error, reason}
    end
  end

  def new(_), do: {:error, :missing_required_fields}

  @doc """
  Registers a new user with email and password.
  Convenience function that creates all necessary value objects.

  ## Examples

      iex> User.register("user@example.com", "SecureP@ssw0rd!")
      {:ok, %User{status: :pending_verification, ...}}

      iex> User.register("invalid-email", "weak")
      {:error, :invalid_email}
  """
  def register(email_string, password) when is_binary(email_string) and is_binary(password) do
    with {:ok, user_id} <- UserId.generate(),
         {:ok, email} <- Email.new(email_string),
         {:ok, password_hash} <- PasswordHash.from_password(password) do
      new(%{
        id: user_id,
        email: email,
        password_hash: password_hash
      })
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def register(_, _), do: {:error, :invalid_registration_data}

  def register_agent(name, email_string, password, agent_config) do
    with {:ok, user_id} <- UserId.generate(),
         {:ok, email} <- Email.new(email_string),
         {:ok, password_hash} <- PasswordHash.from_password(password) do
      new(%{
        id: user_id,
        name: name,
        email: email,
        password_hash: password_hash,
        is_agent: true,
        agent_config: agent_config,
        status: :active,
        # Agents are auto-verified
        verified_at: DateTime.truncate(DateTime.utc_now(), :second)
      })
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Verifies the user's email address.

  ## Examples

      iex> user = %User{status: :pending_verification}
      iex> User.verify_email(user)
      {:ok, %User{status: :active, verified_at: %DateTime{}}}

      iex> user = %User{status: :active}
      iex> User.verify_email(user)
      {:error, :already_verified}
  """
  def verify_email(%__MODULE__{status: :pending_verification} = user) do
    now = DateTime.truncate(DateTime.utc_now(), :second)

    {:ok,
     %{
       user
       | status: :active,
         verified_at: now,
         updated_at: now
     }}
  end

  def verify_email(%__MODULE__{verified_at: verified_at}) when not is_nil(verified_at) do
    {:error, :already_verified}
  end

  def verify_email(_), do: {:error, :invalid_user_state}

  @doc """
  Verifies a password against the user's stored password hash.

  ## Examples

      iex> {:ok, user} = User.register("user@example.com", "SecureP@ssw0rd!")
      iex> User.verify_password(user, "SecureP@ssw0rd!")
      :ok

      iex> User.verify_password(user, "WrongPassword")
      {:error, :invalid_password}
  """
  def verify_password(%__MODULE__{password_hash: password_hash}, password)
      when is_binary(password) do
    PasswordHash.verify(password_hash, password)
  end

  def verify_password(_, _), do: {:error, :invalid_password}

  @doc """
  Changes the user's password.

  ## Examples

      iex> {:ok, user} = User.register("user@example.com", "OldP@ssw0rd!")
      iex> User.change_password(user, "OldP@ssw0rd!", "NewP@ssw0rd!")
      {:ok, %User{password_hash: new_hash, ...}}

      iex> User.change_password(user, "WrongOldPassword", "NewP@ssw0rd!")
      {:error, :invalid_current_password}
  """
  def change_password(%__MODULE__{} = user, current_password, new_password)
      when is_binary(current_password) and is_binary(new_password) do
    with :ok <- verify_password(user, current_password),
         {:ok, new_hash} <- PasswordHash.from_password(new_password) do
      {:ok,
       %{
         user
         | password_hash: new_hash,
           updated_at: DateTime.truncate(DateTime.utc_now(), :second)
       }}
    else
      {:error, :invalid_password} -> {:error, :invalid_current_password}
      {:error, reason} -> {:error, reason}
    end
  end

  def change_password(_, _, _), do: {:error, :invalid_password_change}

  @doc """
  Records a failed login attempt and locks account if threshold exceeded.

  ## Examples

      iex> user = %User{failed_login_attempts: 4}
      iex> {:ok, locked_user} = User.record_failed_login(user)
      iex> locked_user.failed_login_attempts
      5
      iex> locked_user.locked_until
      %DateTime{} # 30 minutes from now
  """
  def record_failed_login(%__MODULE__{} = user) do
    new_attempts = user.failed_login_attempts + 1
    now = DateTime.truncate(DateTime.utc_now(), :second)

    user =
      if new_attempts >= @max_failed_login_attempts do
        %{
          user
          | failed_login_attempts: new_attempts,
            locked_until: DateTime.add(now, @account_lock_duration_minutes * 60),
            updated_at: now
        }
      else
        %{user | failed_login_attempts: new_attempts, updated_at: now}
      end

    {:ok, user}
  end

  @doc """
  Records a successful login and resets failed login attempts.

  ## Examples

      iex> user = %User{failed_login_attempts: 3}
      iex> {:ok, updated_user} = User.record_successful_login(user)
      iex> updated_user.failed_login_attempts
      0
      iex> updated_user.last_login_at
      %DateTime{}
  """
  def record_successful_login(%__MODULE__{} = user) do
    case account_locked?(user) do
      true ->
        {:error, :account_locked}

      false ->
        now = DateTime.truncate(DateTime.utc_now(), :second)

        {:ok,
         %{
           user
           | failed_login_attempts: 0,
             locked_until: nil,
             last_login_at: now,
             updated_at: now
         }}
    end
  end

  @doc """
  Checks if the user's account is currently locked.

  ## Examples

      iex> user = %User{locked_until: nil}
      iex> User.account_locked?(user)
      false

      iex> user = %User{locked_until: DateTime.add(DateTime.utc_now(), 3600)}
      iex> User.account_locked?(user)
      true
  """
  def account_locked?(%__MODULE__{locked_until: nil}), do: false

  def account_locked?(%__MODULE__{locked_until: locked_until}) do
    DateTime.compare(DateTime.utc_now(), locked_until) == :lt
  end

  @doc """
  Adds an MFA method to the user.

  ## Examples

      iex> {:ok, user} = User.register("user@example.com", "SecureP@ssw0rd!")
      iex> {:ok, mfa_method} = MFAMethod.totp("JBSWY3DPEHPK3PXP")
      iex> User.add_mfa_method(user, mfa_method)
      {:ok, %User{mfa_methods: [mfa_method]}}

      iex> User.add_mfa_method(user, mfa_method)
      iex> User.add_mfa_method(user, mfa_method)
      {:error, :mfa_method_already_exists}
  """
  def add_mfa_method(%__MODULE__{mfa_methods: methods} = user, %MFAMethod{} = new_method) do
    if mfa_method_exists?(user, new_method) do
      {:error, :mfa_method_already_exists}
    else
      {:ok,
       %{
         user
         | mfa_methods: [new_method | methods],
           updated_at: DateTime.truncate(DateTime.utc_now(), :second)
       }}
    end
  end

  def add_mfa_method(_, _), do: {:error, :invalid_mfa_method}

  @doc """
  Removes an MFA method from the user.

  ## Examples

      iex> {:ok, mfa_method} = MFAMethod.totp("SECRET")
      iex> user = %User{mfa_methods: [mfa_method]}
      iex> User.remove_mfa_method(user, :totp, "SECRET")
      {:ok, %User{mfa_methods: []}}
  """
  def remove_mfa_method(%__MODULE__{mfa_methods: methods} = user, type, identifier) do
    new_methods =
      Enum.reject(methods, fn method ->
        method.type == type and method.identifier == identifier
      end)

    if length(new_methods) == length(methods) do
      {:error, :mfa_method_not_found}
    else
      {:ok,
       %{
         user
         | mfa_methods: new_methods,
           updated_at: DateTime.truncate(DateTime.utc_now(), :second)
       }}
    end
  end

  @doc """
  Checks if the user has MFA enabled.

  ## Examples

      iex> user = %User{mfa_methods: []}
      iex> User.mfa_enabled?(user)
      false

      iex> {:ok, mfa_method} = MFAMethod.totp("SECRET")
      iex> user = %User{mfa_methods: [mfa_method]}
      iex> User.mfa_enabled?(user)
      true
  """
  def mfa_enabled?(%__MODULE__{mfa_methods: methods}) do
    Enum.any?(methods, &MFAMethod.verified?/1)
  end

  @doc """
  Checks if the user can authenticate (not locked, not suspended).

  ## Examples

      iex> user = %User{status: :active}
      iex> User.can_authenticate?(user)
      true

      iex> user = %User{status: :suspended}
      iex> User.can_authenticate?(user)
      false
  """
  def can_authenticate?(%__MODULE__{status: status} = user) do
    status == :active and not account_locked?(user)
  end

  @doc """
  Suspends the user account.

  ## Examples

      iex> user = %User{status: :active}
      iex> User.suspend(user)
      {:ok, %User{status: :suspended}}
  """
  def suspend(%__MODULE__{} = user) do
    {:ok,
     %{user | status: :suspended, updated_at: DateTime.truncate(DateTime.utc_now(), :second)}}
  end

  @doc """
  Reactivates a suspended user account.

  ## Examples

      iex> user = %User{status: :suspended}
      iex> User.reactivate(user)
      {:ok, %User{status: :active}}
  """
  def reactivate(%__MODULE__{status: :suspended} = user) do
    {:ok, %{user | status: :active, updated_at: DateTime.truncate(DateTime.utc_now(), :second)}}
  end

  def reactivate(%__MODULE__{status: :active}), do: {:error, :already_active}
  def reactivate(_), do: {:error, :cannot_reactivate}

  @doc """
  Deactivates a user account permanently.

  ## Examples

      iex> user = %User{status: :active}
      iex> User.deactivate(user)
      {:ok, %User{status: :deactivated}}
  """
  def deactivate(%__MODULE__{} = user) do
    {:ok,
     %{user | status: :deactivated, updated_at: DateTime.truncate(DateTime.utc_now(), :second)}}
  end

  # Private functions

  defp validate_user(%__MODULE__{} = user) do
    cond do
      is_nil(user.id) -> {:error, :missing_user_id}
      is_nil(user.email) -> {:error, :missing_email}
      is_nil(user.password_hash) -> {:error, :missing_password_hash}
      not valid_status?(user.status) -> {:error, :invalid_status}
      true -> :ok
    end
  end

  defp valid_status?(status) do
    status in [:active, :suspended, :deactivated, :pending_verification]
  end

  defp mfa_method_exists?(%__MODULE__{mfa_methods: methods}, %MFAMethod{} = new_method) do
    Enum.any?(methods, fn method ->
      method.type == new_method.type and method.identifier == new_method.identifier
    end)
  end
end

# Implement String.Chars protocol
defimpl String.Chars, for: Thalamus.Domain.Entities.User do
  def to_string(%Thalamus.Domain.Entities.User{email: email}) do
    "User<#{email}>"
  end
end

# Implement Jason.Encoder - safe serialization without sensitive data
defimpl Jason.Encoder, for: Thalamus.Domain.Entities.User do
  def encode(%Thalamus.Domain.Entities.User{} = user, opts) do
    %{
      id: user.id,
      email: user.email,
      status: user.status,
      mfa_enabled: Thalamus.Domain.Entities.User.mfa_enabled?(user),
      verified_at: user.verified_at,
      last_login_at: user.last_login_at,
      created_at: user.created_at
    }
    |> Jason.Encode.map(opts)
  end
end
