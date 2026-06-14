defmodule ThalamusWeb.SessionController do
  use ThalamusWeb, :controller

  alias Thalamus.Repo
  alias Thalamus.Infrastructure.Persistence.Schemas.UserSchema
  alias Thalamus.Infrastructure.Repositories.PostgreSQLSamlIdentityProviderRepository

  def new(conn, params) do
    # Preserve return_to parameter in session for OAuth2 authorization flow
    conn =
      case params["return_to"] do
        nil -> conn
        return_to -> put_session(conn, :return_to, return_to)
      end

    render(conn, :new, layout: false)
  end

  def create(conn, %{"session" => %{"email" => email, "password" => password}}) do
    # SAML SSO detection: if no password provided or org forces SAML, redirect to IdP
    cond do
      password == "" ->
        redirect(conn, to: "/auth/saml/init?email=#{URI.encode_www_form(email)}")

      saml_force_enabled_for_email?(email) ->
        redirect(conn, to: "/auth/saml/init?email=#{URI.encode_www_form(email)}")

      true ->
        case authenticate_user(email, password) do
          {:ok, user} ->
            authorization_request = get_session(conn, :authorization_request)
            return_to = get_session(conn, :return_to)

            conn
            |> put_flash(:info, "Welcome back!")
            |> put_session(:user_id, user.id)
            |> delete_session(:return_to)
            |> delete_session(:authorization_request)
            |> redirect_after_login(authorization_request, return_to)

          {:error, _reason} ->
            # NEW: check if this email might have SAML available
            maybe_saml_hint =
              if saml_available_for_email?(email),
                do: " (or try signing in without a password to use SSO)",
                else: ""

            conn
            |> put_flash(:error, "Invalid email or password.#{maybe_saml_hint}")
            |> render(:new, layout: false)
        end
    end
  end

  def delete(conn, params) do
    return_to =
      params["return_to"] || conn.params["return_to"] ||
        System.get_env("DEFAULT_LOGOUT_URL") || "http://zea.localhost"

    conn
    |> clear_session()
    |> put_flash(:info, "Logged out successfully")
    |> redirect(external: return_to)
  end

  def mock_oauth(conn, %{"provider" => provider}) do
    email_string =
      case provider do
        "google" -> "google-dev@zea.cl"
        "github" -> "github-dev@zea.cl"
        _ -> "dev@zea.cl"
      end

    name =
      case provider do
        "google" -> "Google Developer"
        "github" -> "GitHub Developer"
        _ -> "ZEA Developer"
      end

    user =
      case Repo.get_by(UserSchema, email: email_string) do
        nil ->
          password_hash = Bcrypt.hash_pwd_salt(:crypto.strong_rand_bytes(16) |> Base.encode64())

          user_params = %{
            email: email_string,
            name: name,
            password_hash: password_hash,
            status: :active,
            verified_at: DateTime.truncate(DateTime.utc_now(), :second)
          }

          {:ok, new_user} = Repo.insert(UserSchema.create_changeset(user_params))
          new_user

        existing_user ->
          existing_user
      end

    authorization_request = get_session(conn, :authorization_request)
    return_to = get_session(conn, :return_to)

    conn
    |> put_flash(:info, "Successfully authenticated with #{String.capitalize(provider)}!")
    |> put_session(:user_id, user.id)
    |> delete_session(:return_to)
    |> delete_session(:authorization_request)
    |> redirect_after_login(authorization_request, return_to)
  end

  defp authenticate_user(email, password) do
    user = Repo.get_by(UserSchema, email: email)

    if user && Bcrypt.verify_pass(password, user.password_hash) && user.status == :active do
      {:ok, user}
    else
      Bcrypt.no_user_verify()
      {:error, :invalid_credentials}
    end
  end

  # ─── SAML Detection Helpers ──────────────────────────────────

  defp saml_force_enabled_for_email?(email) do
    domain = extract_domain(email)

    case PostgreSQLSamlIdentityProviderRepository.find_by_email_domain(domain) do
      {:ok, idp} -> Thalamus.Domain.Entities.SamlIdentityProvider.force_saml?(idp)
      _ -> false
    end
  end

  defp saml_available_for_email?(email) do
    domain = extract_domain(email)

    case PostgreSQLSamlIdentityProviderRepository.find_by_email_domain(domain) do
      {:ok, _idp} -> true
      _ -> false
    end
  end

  defp extract_domain(email) do
    case String.split(email, "@") do
      [_, domain] -> String.downcase(domain)
      _ -> ""
    end
  end

  defp get_return_to(conn) do
    get_session(conn, :return_to) || conn.params["return_to"] ||
      System.get_env("DEFAULT_REDIRECT_URL") || "http://zea.localhost"
  end

  defp redirect_after_login(conn, nil, return_to) do
    target = return_to || get_return_to(conn)
    if String.starts_with?(target, "http://") or String.starts_with?(target, "https://") do
      redirect(conn, external: target)
    else
      redirect(conn, to: target)
    end
  end

  defp redirect_after_login(conn, authorization_request, _return_to) when is_map(authorization_request) do
    # Rebuild authorization URL with original OAuth2 parameters
    query_string = URI.encode_query(authorization_request)
    redirect(conn, to: "/oauth/authorize?" <> query_string)
  end
end
