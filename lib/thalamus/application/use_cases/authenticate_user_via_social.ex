defmodule Thalamus.Application.UseCases.AuthenticateUserViaSocial do
  @moduledoc """
  Use Case for authenticating a user via a federated social identity provider (Google, Apple, GitHub).

  Flow:
  1. Validate incoming profile (provider, provider_uid, email, email_verified).
  2. If identity already exists:
     - Load associated user.
     - Ensure user is active.
     - Record successful login.
     - Return AuthenticationResponse.
  3. If identity does not exist:
     - Check if existing user has matching verified email.
     - If user exists: link new UserIdentity to that user.
     - If user does not exist: JIT provision new User and link UserIdentity.
     - Record login and return AuthenticationResponse.

  SOLID:
  - Single Responsibility: Orchestrates social federation logic.
  - Dependency Inversion: Depends on repository and logger ports.
  """

  alias Thalamus.Application.DTOs.AuthenticationResponse
  alias Thalamus.Domain.Entities.{User, UserIdentity}
  alias Thalamus.Domain.ValueObjects.{UserId, Email, PasswordHash}

  require Logger

  @default_deps %{
    user_repository: Thalamus.Infrastructure.Repositories.PostgreSQLUserRepository,
    user_identity_repository:
      Thalamus.Infrastructure.Repositories.PostgreSQLUserIdentityRepository,
    audit_logger: Thalamus.Infrastructure.Adapters.AuditLoggerImpl
  }

  @doc """
  Executes the social authentication flow.
  """
  @spec execute(map(), map()) :: {:ok, AuthenticationResponse.t()} | {:error, term()}
  def execute(profile, custom_deps \\ %{}) do
    deps = Map.merge(@default_deps, custom_deps)

    with :ok <- validate_profile(profile),
         {:ok, user} <- resolve_or_provision_user(profile, deps),
         {:ok, logged_in_user} <- record_login(user, deps) do
      log_success(logged_in_user, profile[:provider], deps)
      {:ok, AuthenticationResponse.success(logged_in_user)}
    else
      {:error, reason} = error ->
        log_failure(profile, reason, deps)
        error
    end
  end

  defp validate_profile(%{
         provider: provider,
         provider_uid: uid,
         email_verified: true,
         email: email
       })
       when is_binary(provider) and is_binary(uid) and is_binary(email) and email != "" do
    :ok
  end

  defp validate_profile(%{email_verified: false}) do
    {:error, :unverified_social_email}
  end

  defp validate_profile(%{email: nil}) do
    {:error, :missing_social_email}
  end

  defp validate_profile(%{email: ""}) do
    {:error, :missing_social_email}
  end

  defp validate_profile(_) do
    {:error, :invalid_social_profile}
  end

  defp resolve_or_provision_user(%{provider: provider, provider_uid: uid} = profile, deps) do
    case deps.user_identity_repository.find_by_provider_and_uid(provider, uid) do
      {:ok, %UserIdentity{user_id: user_uuid}} ->
        # Existing identity found -> fetch user
        load_and_validate_user(user_uuid, profile, deps)

      {:error, :not_found} ->
        # Identity not found -> link to existing user by email or JIT provision
        link_or_create_user(profile, deps)
    end
  end

  defp load_and_validate_user(user_uuid, profile, deps) do
    user_id_string =
      if String.starts_with?(user_uuid, "user_"), do: user_uuid, else: "user_#{user_uuid}"

    with {:ok, user_id_vo} <- UserId.from_string(user_id_string),
         {:ok, user} <- deps.user_repository.find_by_id(user_id_vo) do
      case user.status do
        :active ->
          maybe_update_user_profile(user, profile, deps)

        :suspended ->
          {:error, :account_suspended}

        :deactivated ->
          {:error, :account_deactivated}

        _ ->
          {:ok, user}
      end
    else
      _ -> {:error, :user_not_found_for_identity}
    end
  end

  defp link_or_create_user(%{email: email_str} = profile, deps) do
    with {:ok, email_vo} <- Email.new(String.downcase(email_str)) do
      case deps.user_repository.find_by_email(email_vo) do
        {:ok, existing_user} ->
          # Link identity to existing user
          link_identity(existing_user, profile, deps)

        {:error, :not_found} ->
          # Provision new user JIT
          provision_new_user(email_vo, profile, deps)
      end
    end
  end

  defp link_identity(user, profile, deps) do
    raw_user_uuid = extract_raw_uuid(user.id)

    identity_attrs = %{
      user_id: raw_user_uuid,
      provider: profile[:provider],
      provider_uid: profile[:provider_uid],
      email: profile[:email],
      metadata: profile[:raw] || %{}
    }

    with {:ok, identity} <- UserIdentity.new(identity_attrs),
         {:ok, _saved_identity} <- deps.user_identity_repository.save(identity),
         {:ok, updated_user} <- maybe_update_user_profile(user, profile, deps) do
      {:ok, updated_user}
    end
  end

  defp provision_new_user(email_vo, profile, deps) do
    {:ok, user_id} = UserId.generate()

    random_password =
      (:crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)) <> "!@1aA"

    {:ok, password_hash} = PasswordHash.from_password(random_password)

    now = DateTime.truncate(DateTime.utc_now(), :second)

    with {:ok, user} <-
           User.new(%{
             id: user_id,
             email: email_vo,
             name: clean_name(profile[:name]),
             avatar_url: profile[:avatar_url],
             password_hash: password_hash,
             status: :active,
             verified_at: now
           }),
         {:ok, saved_user} <- deps.user_repository.save(user) do
      raw_user_uuid = extract_raw_uuid(saved_user.id)

      identity_attrs = %{
        user_id: raw_user_uuid,
        provider: profile[:provider],
        provider_uid: profile[:provider_uid],
        email: profile[:email],
        metadata: profile[:raw] || %{}
      }

      with {:ok, identity} <- UserIdentity.new(identity_attrs),
           {:ok, _saved_identity} <- deps.user_identity_repository.save(identity) do
        {:ok, saved_user}
      end
    end
  end

  defp maybe_update_user_profile(user, profile, deps) do
    should_update_name = is_nil(user.name) and not is_nil(profile[:name])
    should_update_avatar = is_nil(user.avatar_url) and not is_nil(profile[:avatar_url])

    if should_update_name or should_update_avatar do
      updated_user = %{
        user
        | name: if(should_update_name, do: clean_name(profile[:name]), else: user.name),
          avatar_url: if(should_update_avatar, do: profile[:avatar_url], else: user.avatar_url)
      }

      case deps.user_repository.save(updated_user) do
        {:ok, saved} -> {:ok, saved}
        _ -> {:ok, user}
      end
    else
      {:ok, user}
    end
  end

  defp record_login(user, deps) do
    case User.record_successful_login(user) do
      {:ok, updated_user} ->
        deps.user_repository.save(updated_user)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp log_success(user, provider, deps) do
    deps.audit_logger.log_authentication_success(user.id, %{
      method: "social",
      provider: provider
    })
  end

  defp log_failure(profile, reason, deps) do
    deps.audit_logger.log(%{
      event_type: "social_authentication_failure",
      provider: Map.get(profile, :provider),
      reason: reason
    })
  end

  defp extract_raw_uuid(%UserId{value: val}), do: extract_raw_uuid(val)
  defp extract_raw_uuid("user_" <> uuid), do: uuid
  defp extract_raw_uuid(uuid) when is_binary(uuid), do: uuid

  defp clean_name(nil), do: nil

  defp clean_name(name) when is_binary(name) do
    trimmed = String.trim(name)
    if trimmed == "", do: nil, else: trimmed
  end
end
