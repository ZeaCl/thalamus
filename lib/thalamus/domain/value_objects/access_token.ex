defmodule Thalamus.Domain.ValueObjects.AccessToken do
  @moduledoc """
  Value Object representing an OAuth2 access token.

  SOLID Principles Applied:
  - Single Responsibility: Only handles access token creation and validation
  - Open/Closed: Can be extended for different token formats without modification
  - Interface Segregation: Provides only token-specific operations
  """

  alias Thalamus.Domain.ValueObjects.{UserId, ClientId, Scope}

  @type token_type :: :bearer | :mac
  @type subject :: UserId.t() | ClientId.t()

  @type t :: %__MODULE__{
          token: String.t(),
          token_type: token_type(),
          expires_at: DateTime.t(),
          scopes: [Scope.t()],
          subject: subject(),
          issued_at: DateTime.t()
        }

  defstruct [:token, :token_type, :expires_at, :scopes, :subject, :issued_at]

  @default_token_type :bearer
  # 1 hour
  @default_expires_in_seconds 3600
  @min_token_length 32
  @max_token_length 512

  @doc """
  Creates a new AccessToken.

  ## Examples

      iex> user_id = %UserId{value: "user_123"}
      iex> scopes = [%Scope{value: "read"}, %Scope{value: "write"}]
      iex> AccessToken.new("token_abc123", scopes, user_id, 3600)
      {:ok, %AccessToken{token: "token_abc123", scopes: [...], ...}}

      iex> AccessToken.new("", [], %UserId{value: "user_123"}, 3600)
      {:error, :invalid_token}
  """
  def new(
        token,
        scopes,
        subject,
        expires_in_seconds \\ @default_expires_in_seconds,
        token_type \\ @default_token_type
      )

  def new(token, scopes, subject, expires_in_seconds, token_type)
      when is_binary(token) and is_list(scopes) and is_integer(expires_in_seconds) and
             expires_in_seconds > 0 do
    with :ok <- validate_token(token),
         :ok <- validate_scopes(scopes),
         :ok <- validate_subject(subject),
         :ok <- validate_token_type(token_type) do
      now = DateTime.utc_now()
      expires_at = DateTime.add(now, expires_in_seconds, :second)

      {:ok,
       %__MODULE__{
         token: token,
         token_type: token_type,
         expires_at: expires_at,
         scopes: scopes,
         subject: subject,
         issued_at: now
       }}
    end
  end

  def new(_, _, _, _, _), do: {:error, :invalid_parameters}

  @doc """
  Generates a new secure access token.

  ## Examples

      iex> user_id = %UserId{value: "user_123"}
      iex> scopes = [%Scope{value: "read"}]
      iex> AccessToken.generate(scopes, user_id)
      {:ok, %AccessToken{token: "at_" <> _secure_token, ...}}
  """
  def generate(
        scopes,
        subject,
        expires_in_seconds \\ @default_expires_in_seconds,
        token_type \\ @default_token_type
      ) do
    secure_token = generate_secure_token()
    new(secure_token, scopes, subject, expires_in_seconds, token_type)
  end

  @doc """
  Checks if the access token is expired.

  ## Examples

      iex> token = %AccessToken{expires_at: ~U[2023-01-01 00:00:00Z]}
      iex> AccessToken.expired?(token)
      true

      iex> future_time = DateTime.add(DateTime.utc_now(), 3600, :second)
      iex> token = %AccessToken{expires_at: future_time}
      iex> AccessToken.expired?(token)
      false
  """
  def expired?(%__MODULE__{expires_at: expires_at}) do
    DateTime.compare(DateTime.utc_now(), expires_at) == :gt
  end

  @doc """
  Checks if the access token is valid (not expired).

  ## Examples

      iex> future_time = DateTime.add(DateTime.utc_now(), 3600, :second)
      iex> token = %AccessToken{expires_at: future_time}
      iex> AccessToken.valid?(token)
      true
  """
  def valid?(%__MODULE__{} = token) do
    not expired?(token)
  end

  @doc """
  Gets the remaining time until expiration in seconds.

  ## Examples

      iex> future_time = DateTime.add(DateTime.utc_now(), 3600, :second)
      iex> token = %AccessToken{expires_at: future_time}
      iex> AccessToken.time_to_expiry(token)
      3600
  """
  def time_to_expiry(%__MODULE__{expires_at: expires_at}) do
    case DateTime.diff(expires_at, DateTime.utc_now()) do
      diff when diff > 0 -> diff
      _ -> 0
    end
  end

  @doc """
  Checks if the token has a specific scope.

  ## Examples

      iex> scopes = [%Scope{value: "read"}, %Scope{value: "write"}]
      iex> token = %AccessToken{scopes: scopes}
      iex> AccessToken.has_scope?(token, "read")
      true

      iex> AccessToken.has_scope?(token, "delete")
      false
  """
  def has_scope?(%__MODULE__{scopes: scopes}, required_scope) when is_binary(required_scope) do
    Enum.any?(scopes, fn scope -> Scope.to_string(scope) == required_scope end)
  end

  def has_scope?(%__MODULE__{scopes: scopes}, %Scope{} = required_scope) do
    Enum.member?(scopes, required_scope)
  end

  @doc """
  Checks if the token has all required scopes.

  ## Examples

      iex> scopes = [%Scope{value: "read"}, %Scope{value: "write"}]
      iex> token = %AccessToken{scopes: scopes}
      iex> AccessToken.has_scopes?(token, ["read", "write"])
      true

      iex> AccessToken.has_scopes?(token, ["read", "delete"])
      false
  """
  def has_scopes?(%__MODULE__{} = token, required_scopes) when is_list(required_scopes) do
    Enum.all?(required_scopes, &has_scope?(token, &1))
  end

  @doc """
  Converts AccessToken to string representation.

  ## Examples

      iex> token = %AccessToken{token: "token_abc123"}
      iex> AccessToken.to_string(token)
      "token_abc123"
  """
  def to_string(%__MODULE__{token: token}), do: token

  @doc """
  Converts AccessToken to a map for JSON serialization.

  ## Examples

      iex> token = %AccessToken{token: "token_abc123", token_type: :bearer}
      iex> AccessToken.to_response(token)
      %{
        access_token: "token_abc123",
        token_type: "bearer",
        expires_in: 3600,
        scope: "read write"
      }
  """
  def to_response(%__MODULE__{} = token) do
    %{
      access_token: token.token,
      token_type: Atom.to_string(token.token_type),
      expires_in: time_to_expiry(token),
      scope: scopes_to_string(token.scopes)
    }
  end

  # Private functions

  defp validate_token(token) do
    cond do
      String.length(token) < @min_token_length ->
        {:error, :token_too_short}

      String.length(token) > @max_token_length ->
        {:error, :token_too_long}

      not valid_token_format?(token) ->
        {:error, :invalid_token_format}

      true ->
        :ok
    end
  end

  defp validate_scopes([]), do: {:error, :no_scopes_provided}

  defp validate_scopes(scopes) when is_list(scopes) do
    if Enum.all?(scopes, &valid_scope?/1) do
      :ok
    else
      {:error, :invalid_scopes}
    end
  end

  defp validate_subject(%UserId{}), do: :ok
  defp validate_subject(%ClientId{}), do: :ok
  defp validate_subject(_), do: {:error, :invalid_subject}

  defp validate_token_type(token_type) when token_type in [:bearer, :mac], do: :ok
  defp validate_token_type(_), do: {:error, :invalid_token_type}

  defp valid_token_format?(token) do
    # Token should contain only alphanumeric characters and underscores
    String.match?(token, ~r/^[a-zA-Z0-9_-]+$/)
  end

  defp valid_scope?(%Scope{}), do: true
  defp valid_scope?(_), do: false

  defp generate_secure_token do
    # Generate a secure random token with "at_" prefix (access token)
    secure_bytes = :crypto.strong_rand_bytes(32)
    encoded_token = Base.url_encode64(secure_bytes, padding: false)
    "at_#{encoded_token}"
  end

  defp scopes_to_string(scopes) do
    scopes
    |> Enum.map(&Scope.to_string/1)
    |> Enum.join(" ")
  end
end

# Implement String.Chars protocol for easy conversion
defimpl String.Chars, for: Thalamus.Domain.ValueObjects.AccessToken do
  def to_string(%Thalamus.Domain.ValueObjects.AccessToken{token: token}), do: token
end

# Implement Jason.Encoder for JSON serialization
defimpl Jason.Encoder, for: Thalamus.Domain.ValueObjects.AccessToken do
  def encode(%Thalamus.Domain.ValueObjects.AccessToken{} = token, opts) do
    Jason.Encode.map(Thalamus.Domain.ValueObjects.AccessToken.to_response(token), opts)
  end
end
