defmodule ThalamusWeb.SocialAuthController do
  @moduledoc """
  Controller for social identity federation (Google, Apple, GitHub).

  Handles:
  - GET  /auth/social/:provider/init      — Initiates OAuth2 flow to provider
  - GET  /auth/social/:provider/callback  — Standard OAuth2 callback (Google, GitHub)
  - POST /auth/social/apple/callback      — Form-post callback (Sign in with Apple)
  """

  use ThalamusWeb, :controller

  alias Thalamus.Application.UseCases.AuthenticateUserViaSocial
  alias Thalamus.Infrastructure.Adapters.SocialAuth.{GoogleAdapter, GitHubAdapter, AppleAdapter}
  alias ThalamusWeb.URLHelpers

  require Logger

  @supported_providers ["google", "apple", "github"]

  @doc """
  GET /auth/social/:provider/init
  """
  def init(conn, %{"provider" => provider} = params) do
    provider_str = String.downcase(provider)

    if provider_str in @supported_providers do
      csrf = UUID.uuid4()
      return_to = safe_return_target(params["return_to"])
      auth_req = get_session(conn, :authorization_request)

      token_payload = %{
        csrf: csrf,
        provider: provider_str,
        return_to: return_to,
        auth_req: auth_req
      }

      state = Phoenix.Token.sign(ThalamusWeb.Endpoint, "social_auth_state", token_payload)
      redirect_uri = URLHelpers.resolve_social_redirect_uri(conn, provider_str)

      conn =
        conn
        |> put_session(:social_auth_csrf, csrf)
        |> put_session(:social_auth_state, state)
        |> maybe_store_return_to(return_to)

      adapter = get_adapter(provider_str)

      case adapter.get_authorization_url(state, redirect_uri: redirect_uri) do
        {:ok, auth_url} ->
          redirect(conn, external: auth_url)

        {:error, reason} ->
          Logger.error("Failed to generate authorization URL for #{provider}: #{inspect(reason)}")

          conn
          |> put_flash(:error, "Could not initiate sign-in with #{String.capitalize(provider)}.")
          |> redirect(to: "/login")
      end
    else
      conn
      |> put_flash(:error, "Unsupported provider.")
      |> redirect(to: "/login")
    end
  end

  @doc """
  GET /auth/social/:provider/callback
  Standard callback for Google & GitHub.
  """
  def callback(conn, %{"provider" => provider} = params) do
    provider_str = String.downcase(provider)

    cond do
      params["error"] ->
        Logger.warning("Social auth provider returned error: #{inspect(params["error"])}")

        conn
        |> put_flash(:error, "Authentication was cancelled or failed.")
        |> redirect(to: "/login")

      provider_str not in @supported_providers ->
        conn
        |> put_flash(:error, "Unsupported provider.")
        |> redirect(to: "/login")

      true ->
        provided_state = params["state"]

        case verify_social_state(conn, provided_state, provider_str) do
          {:ok, state_data} ->
            code = params["code"]
            redirect_uri = URLHelpers.resolve_social_redirect_uri(conn, provider_str)
            adapter = get_adapter(provider_str)

            case adapter.exchange_code(code, redirect_uri: redirect_uri) do
              {:ok, profile} ->
                handle_authenticated_profile(conn, profile, provider_str, state_data)

              {:error, reason} ->
                Logger.error("Social token exchange failed for #{provider}: #{inspect(reason)}")

                conn
                |> clear_social_session()
                |> put_flash(
                  :error,
                  "Failed to authenticate with #{String.capitalize(provider)}."
                )
                |> redirect(to: "/login")
            end

          {:error, _reason} ->
            Logger.warning("Invalid or mismatched social auth state")

            conn
            |> clear_social_session()
            |> put_flash(:error, "Invalid authentication request. Please try again.")
            |> redirect(to: "/login")
        end
    end
  end

  @doc """
  POST /auth/social/apple/callback
  Form-post callback for Sign in with Apple.
  """
  def apple_callback(conn, params) do
    provided_state = params["state"]

    case verify_social_state(conn, provided_state, "apple") do
      {:ok, state_data} ->
        code = params["code"]
        redirect_uri = URLHelpers.resolve_social_redirect_uri(conn, "apple")
        adapter = get_adapter("apple")
        user_param = params["user"]

        case adapter.exchange_code(code, redirect_uri: redirect_uri, user_param: user_param) do
          {:ok, profile} ->
            handle_authenticated_profile(conn, profile, "apple", state_data)

          {:error, reason} ->
            Logger.error("Apple token exchange failed: #{inspect(reason)}")

            conn
            |> clear_social_session()
            |> put_flash(:error, "Failed to authenticate with Apple.")
            |> redirect(to: "/login")
        end

      {:error, _reason} ->
        Logger.warning("Invalid or mismatched social auth state for Apple")

        conn
        |> clear_social_session()
        |> put_flash(:error, "Invalid authentication request. Please try again.")
        |> redirect(to: "/login")
    end
  end

  defp verify_social_state(conn, state, expected_provider) when is_binary(state) do
    case Phoenix.Token.verify(ThalamusWeb.Endpoint, "social_auth_state", state, max_age: 600) do
      {:ok, %{provider: ^expected_provider} = state_data} ->
        session_csrf = get_session(conn, :social_auth_csrf)

        if is_nil(session_csrf) or session_csrf == state_data[:csrf] do
          {:ok, state_data}
        else
          {:error, :csrf_mismatch}
        end

      _ ->
        expected_state = get_session(conn, :social_auth_state)

        if not is_nil(expected_state) and expected_state == state do
          {:ok,
           %{
             provider: expected_provider,
             return_to: get_session(conn, :return_to),
             auth_req: get_session(conn, :authorization_request)
           }}
        else
          {:error, :invalid_state}
        end
    end
  end

  defp verify_social_state(_conn, _state, _provider), do: {:error, :missing_state}

  defp handle_authenticated_profile(conn, profile, provider_str, state_data) do
    case AuthenticateUserViaSocial.execute(profile) do
      {:ok, auth_response} ->
        authorization_request =
          get_session(conn, :authorization_request) || state_data[:auth_req]

        return_to = safe_return_target(get_session(conn, :return_to) || state_data[:return_to])

        conn
        |> put_flash(:info, "Successfully authenticated with #{String.capitalize(provider_str)}!")
        |> put_session(:user_id, auth_response.user_id)
        |> clear_social_session()
        |> redirect_after_login(authorization_request, return_to)

      {:error, :unverified_social_email} ->
        conn
        |> clear_social_session()
        |> put_flash(
          :error,
          "Your email with #{String.capitalize(provider_str)} is not verified."
        )
        |> redirect(to: "/login")

      {:error, reason} ->
        Logger.error("AuthenticateUserViaSocial failed: #{inspect(reason)}")

        conn
        |> clear_social_session()
        |> put_flash(:error, "Authentication failed. Please contact support.")
        |> redirect(to: "/login")
    end
  end

  defp clear_social_session(conn) do
    conn
    |> delete_session(:social_auth_state)
    |> delete_session(:social_auth_csrf)
    |> delete_session(:authorization_request)
    |> delete_session(:return_to)
  end

  defp maybe_store_return_to(conn, nil), do: conn
  defp maybe_store_return_to(conn, return_to), do: put_session(conn, :return_to, return_to)

  defp get_adapter("google"),
    do: Application.get_env(:thalamus, :google_adapter, GoogleAdapter)

  defp get_adapter("github"),
    do: Application.get_env(:thalamus, :github_adapter, GitHubAdapter)

  defp get_adapter("apple"),
    do: Application.get_env(:thalamus, :apple_adapter, AppleAdapter)

  defp redirect_after_login(conn, authorization_request, _return_to)
       when is_map(authorization_request) and map_size(authorization_request) > 0 do
    query_string = URI.encode_query(authorization_request)
    redirect(conn, to: "/oauth/authorize?" <> query_string)
  end

  defp redirect_after_login(conn, _authorization_request, return_to) do
    target = safe_return_target(return_to) || URLHelpers.default_return_to(conn)

    if String.starts_with?(target, "http://") or String.starts_with?(target, "https://") do
      redirect(conn, external: target)
    else
      redirect(conn, to: target)
    end
  end

  @doc """
  Sanitizes a return_to parameter to ensure it is a safe relative path,
  preventing Open Redirect attacks.
  """
  def safe_return_target(nil), do: nil
  def safe_return_target(""), do: nil

  def safe_return_target(target) when is_binary(target) do
    target = String.trim(target)

    if String.starts_with?(target, "/") and not String.starts_with?(target, ["//", "/\\"]) do
      case URI.parse(target) do
        %URI{scheme: nil, host: nil, path: path} when is_binary(path) ->
          target

        _ ->
          nil
      end
    else
      nil
    end
  end

  def safe_return_target(_), do: nil
end
