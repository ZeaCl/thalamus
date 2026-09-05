defmodule Thalamus.Infrastructure.Adapters.SocialAuth.GoogleAdapter do
  @moduledoc """
  Google OAuth2 / OIDC adapter implementing SocialAuthProvider.
  """

  @behaviour Thalamus.Application.Ports.SocialAuthProvider

  require Logger

  @auth_url "https://accounts.google.com/o/oauth2/v2/auth"
  @token_url "https://oauth2.googleapis.com/token"
  @userinfo_url "https://openidconnect.googleapis.com/v1/userinfo"

  @impl true
  def get_authorization_url(state, opts \\ []) do
    client_id = get_config(:client_id, opts)
    redirect_uri = get_config(:redirect_uri, opts)

    if is_nil(client_id) or client_id == "" do
      {:error, :missing_google_client_id}
    else
      params = %{
        "client_id" => client_id,
        "redirect_uri" => redirect_uri,
        "response_type" => "code",
        "scope" => "openid email profile",
        "state" => state,
        "access_type" => "offline",
        "prompt" => "select_account"
      }

      url = @auth_url <> "?" <> URI.encode_query(params)
      {:ok, url}
    end
  end

  @impl true
  def exchange_code(code, opts \\ []) do
    client_id = get_config(:client_id, opts)
    client_secret = get_config(:client_secret, opts)
    redirect_uri = get_config(:redirect_uri, opts)
    http_client = Keyword.get(opts, :http_client, Req)

    cond do
      is_nil(client_id) or client_id == "" ->
        {:error, :missing_google_client_id}

      is_nil(client_secret) or client_secret == "" ->
        {:error, :missing_google_client_secret}

      true ->
        token_payload = %{
          "code" => code,
          "client_id" => client_id,
          "client_secret" => client_secret,
          "redirect_uri" => redirect_uri,
          "grant_type" => "authorization_code"
        }

        case http_client.post(@token_url, form: token_payload) do
          {:ok, %{status: 200, body: %{"access_token" => access_token} = _token_resp}} ->
            fetch_userinfo(access_token, http_client)

          {:ok, %{status: status, body: body}} ->
            Logger.error("Google token exchange failed (#{status}): #{inspect(body)}")
            {:error, :token_exchange_failed}

          {:error, reason} ->
            Logger.error("Google token request failed: #{inspect(reason)}")
            {:error, :network_error}
        end
    end
  end

  defp fetch_userinfo(access_token, http_client) do
    headers = [{"authorization", "Bearer #{access_token}"}]

    case http_client.get(@userinfo_url, headers: headers) do
      {:ok, %{status: 200, body: info}} ->
        uid = info["sub"]
        email = info["email"]
        email_verified = info["email_verified"] in [true, "true"]
        name = info["name"]
        avatar = info["picture"]

        {:ok,
         %{
           provider: "google",
           provider_uid: to_string(uid),
           email: email,
           email_verified: email_verified,
           name: name,
           avatar_url: avatar,
           raw: info
         }}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Google userinfo failed (#{status}): #{inspect(body)}")
        {:error, :userinfo_failed}

      {:error, reason} ->
        Logger.error("Google userinfo request error: #{inspect(reason)}")
        {:error, :network_error}
    end
  end

  defp get_config(key, opts) do
    Keyword.get(opts, key) ||
      Application.get_env(:thalamus, :google_auth, [])[key] ||
      System.get_env(env_var_name(key)) ||
      default_config(key)
  end

  defp env_var_name(:client_id), do: "GOOGLE_CLIENT_ID"
  defp env_var_name(:client_secret), do: "GOOGLE_CLIENT_SECRET"
  defp env_var_name(:redirect_uri), do: "GOOGLE_REDIRECT_URI"
  defp env_var_name(_), do: ""

  defp default_config(:redirect_uri) do
    ThalamusWeb.URLHelpers.resolve_social_redirect_uri(nil, "google")
  end

  defp default_config(_), do: nil
end
