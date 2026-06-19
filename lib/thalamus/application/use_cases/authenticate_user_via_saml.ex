defmodule Thalamus.Application.UseCases.AuthenticateUserViaSaml do
  @moduledoc """
  Use Case for authenticating a user via SAML assertion from an external IdP.

  Orchestrates the SAML → User authentication flow:
  1. Load the IdP configuration for the organization
  2. Validate the SAML assertion cryptographically
  3. Extract user identity (email, name) from the assertion
  4. Find existing user or create via JIT provisioning
  5. Record login event and return AuthenticationResponse

  SOLID:
  - Single Responsibility: Only handles SAML authentication workflow
  - Dependency Inversion: Depends on ports (interfaces), not implementations
  - Open/Closed: Extends authentication without modifying AuthenticateUser
  """

  alias Thalamus.Application.DTOs.AuthenticationResponse
  alias Thalamus.Domain.Entities.{User, SamlIdentityProvider}
  alias Thalamus.Domain.ValueObjects.{UserId, Email, PasswordHash, OrganizationId}

  @type saml_attrs :: %{
          email: String.t(),
          name: String.t() | nil,
          avatar_url: String.t() | nil
        }

  @type deps :: %{
          user_repository: module(),
          saml_idp_repository: module(),
          saml_service: module(),
          audit_logger: module()
        }

  @doc """
  Executes the SAML authentication use case.

  ## Parameters
  - saml_response_xml — the raw SAMLResponse from the IdP POST
  - organization_id — the org that owns this IdP config
  - deps — dependency injection map

  ## Returns
  - {:ok, AuthenticationResponse.t()} on success
  - {:error, reason} on failure

  ## Error reasons
  - :saml_disabled — IdP config is not enabled
  - :invalid_saml_assertion — assertion validation failed
  - :missing_email_in_assertion — email not found in assertion
  - :saml_user_not_found — user doesn't exist and JIT is disabled
  """
  @spec execute(String.t(), OrganizationId.t(), deps()) ::
          {:ok, AuthenticationResponse.t()} | {:error, atom()}

  def execute(saml_response_xml, org_id, deps) do
    with {:ok, idp_config} <- fetch_idp_config(org_id, deps),
         :ok <- ensure_enabled(idp_config),
         {:ok, assertion_data} <- validate_saml(saml_response_xml, idp_config, deps),
         {:ok, saml_attrs} <- extract_user_attrs(assertion_data, idp_config),
         {:ok, email} <- Email.new(saml_attrs.email),
         {:ok, user} <- find_or_create_user(email, saml_attrs, idp_config, deps),
         :ok <- record_login(user, deps) do
      log_success(user.id, idp_config, deps)
      {:ok, AuthenticationResponse.success(user)}
    else
      {:error, :saml_user_not_found} = error ->
        log_failure(org_id, :user_not_found_for_saml, deps)
        error

      {:error, reason} ->
        log_failure(org_id, reason, deps)
        {:error, reason}
    end
  end

  # ─── Private Pipeline Steps ─────────────────────────────────

  defp fetch_idp_config(org_id, %{saml_idp_repository: repo}) do
    repo.find_by_organization_id(org_id)
  end

  defp ensure_enabled(%SamlIdentityProvider{enabled: true}), do: :ok
  defp ensure_enabled(_), do: {:error, :saml_disabled}

  defp validate_saml(xml, idp, %{saml_service: service}) do
    service.validate_assertion(xml, idp)
  end

  defp extract_user_attrs(assertion_data, idp) do
    mapping = idp.attribute_mapping

    # Resolve attribute names from the mapping, falling back to direct keys
    email_attr = resolve_attr(mapping, "email", "emailaddress")
    name_attr = resolve_attr(mapping, "name", "displayname")
    avatar_attr = resolve_attr(mapping, "avatar_url", nil)

    email =
      Map.get(assertion_data, email_attr) ||
        Map.get(assertion_data, "email") ||
        Map.get(assertion_data, "emailaddress") ||
        Map.get(assertion_data, :email)

    name =
      if name_attr,
        do: Map.get(assertion_data, name_attr),
        else:
          Map.get(assertion_data, "name") || Map.get(assertion_data, "displayname") ||
            Map.get(assertion_data, :name)

    avatar_url =
      if avatar_attr,
        do: Map.get(assertion_data, avatar_attr),
        else: Map.get(assertion_data, "avatar_url") || Map.get(assertion_data, :avatar_url)

    if is_binary(email) and email != "" do
      {:ok,
       %{
         email: String.downcase(email),
         name: clean_name(name),
         avatar_url: avatar_url
       }}
    else
      {:error, :missing_email_in_assertion}
    end
  end

  defp find_or_create_user(email, saml_attrs, idp, deps) do
    case find_existing_user(email, deps) do
      {:ok, user} ->
        {:ok, user}

      {:error, :not_found} ->
        if SamlIdentityProvider.jit_enabled?(idp) do
          create_jit_user(email, saml_attrs, deps)
        else
          {:error, :saml_user_not_found}
        end
    end
  end

  defp find_existing_user(email, %{user_repository: repo}) do
    repo.find_by_email(email)
  end

  defp create_jit_user(email, saml_attrs, deps) do
    {:ok, user_id} = UserId.generate()

    # Generate a random secure password for SAML-only users
    random_password =
      (:crypto.strong_rand_bytes(32)
      |> Base.url_encode64(padding: false)) <> "!@1aA"

    {:ok, password_hash} = PasswordHash.from_password(random_password)

    {:ok, user} =
      User.new(%{
        id: user_id,
        email: email,
        name: saml_attrs.name,
        password_hash: password_hash,
        status: :active,
        verified_at: DateTime.truncate(DateTime.utc_now(), :second)
      })

    deps.user_repository.save(user)
  end

  defp record_login(user, %{user_repository: repo}) do
    {:ok, updated_user} = User.record_successful_login(user)
    repo.save(updated_user)
    :ok
  end

  # ─── Logging ────────────────────────────────────────────────

  defp log_success(user_id, idp, %{audit_logger: logger}) do
    logger.log_authentication_success(user_id, %{
      method: "saml",
      idp: idp.name
    })
  end

  defp log_failure(org_id, reason, %{audit_logger: logger}) do
    logger.log_authentication_failure(org_id, reason, %{method: "saml"})
  end

  # ─── Helpers ────────────────────────────────────────────────

  defp resolve_attr(mapping, field, default) when is_map(mapping) do
    mapping
    |> Map.get(field)
    |> case do
      nil -> default
      value -> value
    end
  end

  defp clean_name(nil), do: nil

  defp clean_name(name) when is_binary(name) do
    trimmed = String.trim(name)
    if trimmed == "", do: nil, else: trimmed
  end
end
