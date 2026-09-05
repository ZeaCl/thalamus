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

  require Logger

  @supported_providers ["google", "apple", "github"]

  @doc """
  GET /auth/social/:provider/init
  """
  def init(conn, %{"provider" => provider} = params) do
    provider_str = String.downcase(provider)

    if provider_str in @supported_providers do
      state = UUID.uuid4()

      conn =
        conn
        |> put_session(:social_auth_state, state)
        |> maybe_store_return_to(params["return_to"])

      adapter = get_adapter(provider_str)

      case adapter.get_authorization_url(state) do
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
        expected_state = get_session(conn, :social_auth_state)
        provided_state = params["state"]

        if is_nil(expected_state) or expected_state != provided_state do
          Logger.warning("CSRF state mismatch in social auth callback")

          conn
          |> delete_session(:social_auth_state)
          |> put_flash(:error, "Invalid authentication request. Please try again.")
          |> redirect(to: "/login")
        else
          code = params["code"]
          adapter = get_adapter(provider_str)

          case adapter.exchange_code(code) do
            {:ok, profile} ->
              handle_authenticated_profile(conn, profile, provider_str)

            {:error, reason} ->
              Logger.error("Social token exchange failed for #{provider}: #{inspect(reason)}")

              conn
              |> delete_session(:social_auth_state)
              |> put_flash(:error, "Failed to authenticate with #{String.capitalize(provider)}.")
              |> redirect(to: "/login")
          end
        end
    end
  end

  @doc """
  POST /auth/social/apple/callback
  Form-post callback for Sign in with Apple.
  """
  def apple_callback(conn, params) do
    expected_state = get_session(conn, :social_auth_state)
    provided_state = params["state"]

    if is_nil(expected_state) or expected_state != provided_state do
      Logger.warning("CSRF state mismatch in Apple social auth callback")

      conn
      |> delete_session(:social_auth_state)
      |> put_flash(:error, "Invalid authentication request. Please try again.")
      |> redirect(to: "/login")
    else
      code = params["code"]
      adapter = get_adapter("apple")
      user_param = params["user"]

      case adapter.exchange_code(code, user_param: user_param) do
        {:ok, profile} ->
          handle_authenticated_profile(conn, profile, "apple")

        {:error, reason} ->
          Logger.error("Apple token exchange failed: #{inspect(reason)}")

          conn
          |> delete_session(:social_auth_state)
          |> put_flash(:error, "Failed to authenticate with Apple.")
          |> redirect(to: "/login")
      end
    end
  end

  defp handle_authenticated_profile(conn, profile, provider_str) do
    case AuthenticateUserViaSocial.execute(profile) do
      {:ok, auth_response} ->
        authorization_request = get_session(conn, :authorization_request)
        return_to = get_session(conn, :return_to)

        conn
        |> put_flash(:info, "Successfully authenticated with #{String.capitalize(provider_str)}!")
        |> put_session(:user_id, auth_response.user_id)
        |> delete_session(:social_auth_state)
        |> delete_session(:authorization_request)
        |> delete_session(:return_to)
        |> redirect_after_login(authorization_request, return_to)

      {:error, :unverified_social_email} ->
        conn
        |> delete_session(:social_auth_state)
        |> put_flash(
          :error,
          "Your email with #{String.capitalize(provider_str)} is not verified."
        )
        |> redirect(to: "/login")

      {:error, reason} ->
        Logger.error("AuthenticateUserViaSocial failed: #{inspect(reason)}")

        conn
        |> delete_session(:social_auth_state)
        |> put_flash(:error, "Authentication failed. Please contact support.")
        |> redirect(to: "/login")
    end
  end

  defp maybe_store_return_to(conn, nil), do: conn
  defp maybe_store_return_to(conn, return_to), do: put_session(conn, :return_to, return_to)

  defp get_adapter("google"),
    do: Application.get_env(:thalamus, :google_adapter, GoogleAdapter)

  defp get_adapter("github"),
    do: Application.get_env(:thalamus, :github_adapter, GitHubAdapter)

  defp get_adapter("apple"),
    do: Application.get_env(:thalamus, :apple_adapter, AppleAdapter)

  defp redirect_after_login(conn, nil, return_to) do
    target = return_to || get_return_to(conn)

    if String.starts_with?(target, "http://") or String.starts_with?(target, "https://") do
      redirect(conn, external: target)
    else
      redirect(conn, to: target)
    end
  end

  defp redirect_after_login(conn, authorization_request, _return_to)
       when is_map(authorization_request) and map_size(authorization_request) > 0 do
    query_string = URI.encode_query(authorization_request)
    redirect(conn, to: "/oauth/authorize?" <> query_string)
  end

  defp redirect_after_login(conn, _, return_to) do
    redirect_after_login(conn, nil, return_to)
  end

  defp get_return_to(conn) do
    get_session(conn, :return_to) || conn.params["return_to"] ||
      System.get_env("DEFAULT_REDIRECT_URL") || "http://zea.localhost/dashboard"
  end
end
