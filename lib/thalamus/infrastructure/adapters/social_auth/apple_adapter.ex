defmodule Thalamus.Infrastructure.Adapters.SocialAuth.AppleAdapter do
  @moduledoc """
  Sign in with Apple adapter implementing SocialAuthProvider.
  """

  @behaviour Thalamus.Application.Ports.SocialAuthProvider

  require Logger

  @auth_url "https://appleid.apple.com/auth/authorize"
  @token_url "https://appleid.apple.com/auth/token"

  @impl true
  def get_authorization_url(state, opts \\ []) do
    client_id = get_config(:client_id, opts)
    redirect_uri = get_config(:redirect_uri, opts)

    if is_nil(client_id) or client_id == "" do
      {:error, :missing_apple_client_id}
    else
      params = %{
        "client_id" => client_id,
        "redirect_uri" => redirect_uri,
        "response_type" => "code",
        "response_mode" => "form_post",
        "scope" => "name email",
        "state" => state
      }

      url = @auth_url <> "?" <> URI.encode_query(params)
      {:ok, url}
    end
  end

  @impl true
  def exchange_code(code, opts \\ []) do
    client_id = get_config(:client_id, opts)
    team_id = get_config(:team_id, opts)
    key_id = get_config(:key_id, opts)
    private_key = get_config(:private_key, opts)
    redirect_uri = get_config(:redirect_uri, opts)
    http_client = Keyword.get(opts, :http_client, Req)
    user_param = Keyword.get(opts, :user_param)

    with :ok <- validate_apple_config(client_id, team_id, key_id, private_key),
         {:ok, client_secret} <- generate_client_secret(client_id, team_id, key_id, private_key) do
      token_payload = %{
        "code" => code,
        "client_id" => client_id,
        "client_secret" => client_secret,
        "grant_type" => "authorization_code",
        "redirect_uri" => redirect_uri
      }

      case http_client.post(@token_url, form: token_payload) do
        {:ok, %{status: 200, body: %{"id_token" => id_token} = token_resp}} ->
          parse_apple_id_token(id_token, user_param, token_resp)

        {:ok, %{status: status, body: body}} ->
          Logger.error("Apple token exchange failed (#{status}): #{inspect(body)}")
          {:error, :token_exchange_failed}

        {:error, reason} ->
          Logger.error("Apple token request failed: #{inspect(reason)}")
          {:error, :network_error}
      end
    end
  end

  @doc """
  Generates the client_secret JWT for Apple using ES256 and the .p8 private key.
  """
  def generate_client_secret(client_id, team_id, key_id, private_key) do
    try do
      pem_string = normalize_pem(private_key)
      jwk = JOSE.JWK.from_pem(pem_string)

      now = System.system_time(:second)
      # Expires in 24 hours (86400 seconds)
      exp = now + 86_400

      jwt_payload = %{
        "iss" => team_id,
        "iat" => now,
        "exp" => exp,
        "aud" => "https://appleid.apple.com",
        "sub" => client_id
      }

      jws_header = %{
        "alg" => "ES256",
        "kid" => key_id
      }

      {_, signed_jwt} =
        JOSE.JWT.sign(jwk, jws_header, jwt_payload)
        |> JOSE.JWS.compact()

      {:ok, signed_jwt}
    rescue
      e ->
        Logger.error("Failed to generate Apple client_secret: #{Exception.message(e)}")
        {:error, :apple_client_secret_generation_failed}
    end
  end

  defp parse_apple_id_token(id_token, user_param, token_resp) do
    case JOSE.JWT.peek_payload(id_token) do
      %JOSE.JWT{fields: claims} ->
        uid = claims["sub"]
        email = claims["email"]
        email_verified = claims["email_verified"] in [true, "true", "TRUE", nil]

        name = parse_apple_name(user_param)

        {:ok,
         %{
           provider: "apple",
           provider_uid: to_string(uid),
           email: email,
           email_verified: email_verified,
           name: name,
           avatar_url: nil,
           raw: Map.put(token_resp, "claims", claims)
         }}

      _ ->
        {:error, :invalid_apple_id_token}
    end
  end

  defp parse_apple_name(nil), do: nil

  defp parse_apple_name(user_json) when is_binary(user_json) do
    case Jason.decode(user_json) do
      {:ok, data} -> parse_apple_name(data)
      _ -> nil
    end
  end

  defp parse_apple_name(%{"name" => name_map}) when is_map(name_map) do
    first = Map.get(name_map, "firstName")
    last = Map.get(name_map, "lastName")

    case {first, last} do
      {nil, nil} -> nil
      {f, nil} -> f
      {nil, l} -> l
      {f, l} -> "#{f} #{l}"
    end
  end

  defp parse_apple_name(_), do: nil

  defp normalize_pem(pem) when is_binary(pem) do
    trimmed = String.trim(pem)
    # If the user supplied escaped newlines in ENV (\n), unescape them
    String.replace(trimmed, "\\n", "\n")
  end

  defp validate_apple_config(client_id, team_id, key_id, private_key) do
    cond do
      is_nil(client_id) or client_id == "" -> {:error, :missing_apple_client_id}
      is_nil(team_id) or team_id == "" -> {:error, :missing_apple_team_id}
      is_nil(key_id) or key_id == "" -> {:error, :missing_apple_key_id}
      is_nil(private_key) or private_key == "" -> {:error, :missing_apple_private_key}
      true -> :ok
    end
  end

  defp get_config(key, opts) do
    Keyword.get(opts, key) ||
      Application.get_env(:thalamus, :apple_auth, [])[key] ||
      System.get_env(env_var_name(key)) ||
      default_config(key)
  end

  defp env_var_name(:client_id), do: "APPLE_CLIENT_ID"
  defp env_var_name(:team_id), do: "APPLE_TEAM_ID"
  defp env_var_name(:key_id), do: "APPLE_KEY_ID"
  defp env_var_name(:private_key), do: "APPLE_PRIVATE_KEY"
  defp env_var_name(:redirect_uri), do: "APPLE_REDIRECT_URI"
  defp env_var_name(_), do: ""

  defp default_config(:redirect_uri), do: "https://auth.zea.cl/auth/social/apple/callback"
  defp default_config(_), do: nil
end
