defmodule Thalamus.Domain.ValueObjects.AuthorizationCode do
  @moduledoc """
  Value Object representing an OAuth2 authorization code.

  SOLID Principles Applied:
  - Single Responsibility: Only handles authorization code creation and validation
  - Open/Closed: Can be extended for different code formats without modification
  - Interface Segregation: Provides only authorization code specific operations
  """

  alias Thalamus.Domain.ValueObjects.{UserId, ClientId, Scope, RedirectUri, PKCEChallenge}

  @type t :: %__MODULE__{
          code: String.t(),
          client_id: ClientId.t(),
          user_id: UserId.t(),
          redirect_uri: RedirectUri.t(),
          scopes: [Scope.t()],
          pkce_challenge: PKCEChallenge.t() | nil,
          expires_at: DateTime.t(),
          issued_at: DateTime.t(),
          used_at: DateTime.t() | nil
        }

  defstruct [
    :code,
    :client_id,
    :user_id,
    :redirect_uri,
    :scopes,
    :pkce_challenge,
    :expires_at,
    :issued_at,
    :used_at
  ]

  # 10 minutes
  @default_expires_in_seconds 600
  @min_code_length 32
  @max_code_length 128

  @doc """
  Creates a new AuthorizationCode.

  ## Examples

      iex> user_id = %UserId{value: "user_123"}
      iex> client_id = %ClientId{value: "client_123"}
      iex> redirect_uri = %RedirectUri{value: "https://app.example.com/callback"}
      iex> scopes = [%Scope{value: "openid"}, %Scope{value: "profile"}]
      iex> AuthorizationCode.new("code_abc123", client_id, user_id, redirect_uri, scopes)
      {:ok, %AuthorizationCode{code: "code_abc123", ...}}
  """
  def new(
        code,
        client_id,
        user_id,
        redirect_uri,
        scopes,
        pkce_challenge \\ nil,
        expires_in_seconds \\ @default_expires_in_seconds
      )

  def new(code, client_id, user_id, redirect_uri, scopes, pkce_challenge, expires_in_seconds)
      when is_binary(code) and is_list(scopes) and is_integer(expires_in_seconds) and
             expires_in_seconds > 0 do
    with :ok <- validate_code(code),
         :ok <- validate_client_id(client_id),
         :ok <- validate_user_id(user_id),
         :ok <- validate_redirect_uri(redirect_uri),
         :ok <- validate_scopes(scopes),
         :ok <- validate_pkce_challenge(pkce_challenge) do
      now = DateTime.utc_now()
      expires_at = DateTime.add(now, expires_in_seconds, :second)

      {:ok,
       %__MODULE__{
         code: code,
         client_id: client_id,
         user_id: user_id,
         redirect_uri: redirect_uri,
         scopes: scopes,
         pkce_challenge: pkce_challenge,
         expires_at: expires_at,
         issued_at: now,
         used_at: nil
       }}
    end
  end

  def new(_, _, _, _, _, _, _), do: {:error, :invalid_parameters}

  @doc """
  Generates a new secure authorization code.

  ## Examples

      iex> user_id = %UserId{value: "user_123"}
      iex> client_id = %ClientId{value: "client_123"}
      iex> redirect_uri = %RedirectUri{value: "https://app.example.com/callback"}
      iex> scopes = [%Scope{value: "openid"}]
      iex> AuthorizationCode.generate(client_id, user_id, redirect_uri, scopes)
      {:ok, %AuthorizationCode{code: "ac_" <> _secure_code, ...}}
  """
  def generate(
        client_id,
        user_id,
        redirect_uri,
        scopes,
        pkce_challenge \\ nil,
        expires_in_seconds \\ @default_expires_in_seconds
      ) do
    secure_code = generate_secure_code()
    new(secure_code, client_id, user_id, redirect_uri, scopes, pkce_challenge, expires_in_seconds)
  end

  @doc """
  Checks if the authorization code is expired.

  ## Examples

      iex> code = %AuthorizationCode{expires_at: ~U[2023-01-01 00:00:00Z]}
      iex> AuthorizationCode.expired?(code)
      true

      iex> future_time = DateTime.add(DateTime.utc_now(), 600, :second)
      iex> code = %AuthorizationCode{expires_at: future_time}
      iex> AuthorizationCode.expired?(code)
      false
  """
  def expired?(%__MODULE__{expires_at: expires_at}) do
    DateTime.compare(DateTime.utc_now(), expires_at) == :gt
  end

  @doc """
  Checks if the authorization code has been used.

  ## Examples

      iex> code = %AuthorizationCode{used_at: nil}
      iex> AuthorizationCode.used?(code)
      false

      iex> code = %AuthorizationCode{used_at: ~U[2023-01-01 00:00:00Z]}
      iex> AuthorizationCode.used?(code)
      true
  """
  def used?(%__MODULE__{used_at: used_at}) do
    not is_nil(used_at)
  end

  @doc """
  Checks if the authorization code is valid (not expired and not used).

  ## Examples

      iex> future_time = DateTime.add(DateTime.utc_now(), 600, :second)
      iex> code = %AuthorizationCode{expires_at: future_time, used_at: nil}
      iex> AuthorizationCode.valid?(code)
      true

      iex> code = %AuthorizationCode{expires_at: ~U[2023-01-01 00:00:00Z], used_at: nil}
      iex> AuthorizationCode.valid?(code)
      false
  """
  def valid?(%__MODULE__{} = code) do
    not expired?(code) and not used?(code)
  end

  @doc """
  Marks the authorization code as used.

  ## Examples

      iex> code = %AuthorizationCode{used_at: nil}
      iex> AuthorizationCode.mark_as_used(code)
      %AuthorizationCode{used_at: %DateTime{...}}
  """
  def mark_as_used(%__MODULE__{} = code) do
    %{code | used_at: DateTime.utc_now()}
  end

  @doc """
  Validates the redirect URI matches the one used for authorization.

  ## Examples

      iex> redirect_uri = %RedirectUri{value: "https://app.example.com/callback"}
      iex> code = %AuthorizationCode{redirect_uri: redirect_uri}
      iex> AuthorizationCode.validate_redirect_uri(code, "https://app.example.com/callback")
      :ok

      iex> AuthorizationCode.validate_redirect_uri(code, "https://evil.com/callback")
      {:error, :redirect_uri_mismatch}
  """
  def validate_redirect_uri(%__MODULE__{redirect_uri: expected_uri}, provided_uri)
      when is_binary(provided_uri) do
    if RedirectUri.to_string(expected_uri) == provided_uri do
      :ok
    else
      {:error, :redirect_uri_mismatch}
    end
  end

  @doc """
  Validates the client ID matches the one used for authorization.

  ## Examples

      iex> client_id = %ClientId{value: "client_123"}
      iex> code = %AuthorizationCode{client_id: client_id}
      iex> AuthorizationCode.validate_client_id(code, "client_123")
      :ok

      iex> AuthorizationCode.validate_client_id(code, "different_client")
      {:error, :client_id_mismatch}
  """
  def validate_client_id(%__MODULE__{client_id: expected_client}, provided_client)
      when is_binary(provided_client) do
    if ClientId.to_string(expected_client) == provided_client do
      :ok
    else
      {:error, :client_id_mismatch}
    end
  end

  @doc """
  Validates PKCE code verifier against the stored challenge.

  ## Examples

      iex> challenge = %PKCEChallenge{value: "hashed_challenge", method: :S256}
      iex> code = %AuthorizationCode{pkce_challenge: challenge}
      iex> AuthorizationCode.validate_pkce(code, "original_verifier")
      :ok
  """
  def validate_pkce(%__MODULE__{pkce_challenge: nil}, _verifier), do: :ok

  def validate_pkce(%__MODULE__{pkce_challenge: challenge}, verifier) when is_binary(verifier) do
    PKCEChallenge.verify(challenge, verifier)
  end

  @doc """
  Gets the remaining time until expiration in seconds.

  ## Examples

      iex> future_time = DateTime.add(DateTime.utc_now(), 600, :second)
      iex> code = %AuthorizationCode{expires_at: future_time}
      iex> AuthorizationCode.time_to_expiry(code)
      600
  """
  def time_to_expiry(%__MODULE__{expires_at: expires_at}) do
    case DateTime.diff(expires_at, DateTime.utc_now()) do
      diff when diff > 0 -> diff
      _ -> 0
    end
  end

  @doc """
  Converts AuthorizationCode to string representation.

  ## Examples

      iex> code = %AuthorizationCode{code: "code_abc123"}
      iex> AuthorizationCode.to_string(code)
      "code_abc123"
  """
  def to_string(%__MODULE__{code: code}), do: code

  # Private functions

  defp validate_code(code) do
    cond do
      String.length(code) < @min_code_length ->
        {:error, :code_too_short}

      String.length(code) > @max_code_length ->
        {:error, :code_too_long}

      not valid_code_format?(code) ->
        {:error, :invalid_code_format}

      true ->
        :ok
    end
  end

  defp validate_client_id(%ClientId{}), do: :ok
  defp validate_client_id(_), do: {:error, :invalid_client_id}

  defp validate_user_id(%UserId{}), do: :ok
  defp validate_user_id(_), do: {:error, :invalid_user_id}

  defp validate_redirect_uri(%RedirectUri{}), do: :ok
  defp validate_redirect_uri(_), do: {:error, :invalid_redirect_uri}

  defp validate_scopes([]), do: {:error, :no_scopes_provided}

  defp validate_scopes(scopes) when is_list(scopes) do
    if Enum.all?(scopes, &valid_scope?/1) do
      :ok
    else
      {:error, :invalid_scopes}
    end
  end

  defp validate_pkce_challenge(nil), do: :ok
  defp validate_pkce_challenge(%PKCEChallenge{}), do: :ok
  defp validate_pkce_challenge(_), do: {:error, :invalid_pkce_challenge}

  defp valid_code_format?(code) do
    # Authorization code should contain only alphanumeric characters and underscores
    String.match?(code, ~r/^[a-zA-Z0-9_-]+$/)
  end

  defp valid_scope?(%Scope{}), do: true
  defp valid_scope?(_), do: false

  defp generate_secure_code do
    # Generate a secure random authorization code with "ac_" prefix
    secure_bytes = :crypto.strong_rand_bytes(32)
    encoded_code = Base.url_encode64(secure_bytes, padding: false)
    "ac_#{encoded_code}"
  end
end

# Implement String.Chars protocol for easy conversion
defimpl String.Chars, for: Thalamus.Domain.ValueObjects.AuthorizationCode do
  def to_string(%Thalamus.Domain.ValueObjects.AuthorizationCode{code: code}), do: code
end

# Implement Jason.Encoder for JSON serialization
defimpl Jason.Encoder, for: Thalamus.Domain.ValueObjects.AuthorizationCode do
  def encode(%Thalamus.Domain.ValueObjects.AuthorizationCode{code: code}, opts) do
    Jason.Encode.string(code, opts)
  end
end
