defmodule Thalamus.Domain.ValueObjects.GrantType do
  @moduledoc """
  Value Object representing OAuth2 grant types.

  SOLID Principles Applied:
  - Single Responsibility: Only handles grant type validation and properties
  - Open/Closed: Can be extended for new grant types without modification
  """

  @type grant_type ::
          :authorization_code | :client_credentials | :refresh_token | :implicit | :password

  @type t :: %__MODULE__{
          type: grant_type(),
          requires_user: boolean(),
          requires_client_secret: boolean(),
          issues_refresh_token: boolean(),
          pkce_required: boolean()
        }

  defstruct [:type, :requires_user, :requires_client_secret, :issues_refresh_token, :pkce_required]

  @valid_types [:authorization_code, :client_credentials, :refresh_token, :implicit, :password]

  # OAuth2 recommended grant types for modern applications
  @recommended_types [:authorization_code, :client_credentials, :refresh_token]

  @doc """
  Creates a new GrantType.

  ## Examples

      iex> GrantType.new(:authorization_code)
      {:ok, %GrantType{type: :authorization_code, requires_user: true, ...}}

      iex> GrantType.new(:client_credentials)
      {:ok, %GrantType{type: :client_credentials, requires_user: false, ...}}

      iex> GrantType.new(:invalid)
      {:error, :invalid_grant_type}
  """
  def new(type) when type in @valid_types do
    {:ok, build_grant_type(type)}
  end

  def new(_), do: {:error, :invalid_grant_type}

  @doc """
  Creates an Authorization Code grant type.
  Most secure flow for web and mobile applications.

  ## Examples

      iex> GrantType.authorization_code()
      {:ok, %GrantType{type: :authorization_code, pkce_required: true}}
  """
  def authorization_code, do: new(:authorization_code)

  @doc """
  Creates a Client Credentials grant type.
  For server-to-server (M2M) authentication.

  ## Examples

      iex> GrantType.client_credentials()
      {:ok, %GrantType{type: :client_credentials, requires_user: false}}
  """
  def client_credentials, do: new(:client_credentials)

  @doc """
  Creates a Refresh Token grant type.

  ## Examples

      iex> GrantType.refresh_token()
      {:ok, %GrantType{type: :refresh_token}}
  """
  def refresh_token, do: new(:refresh_token)

  @doc """
  Creates an Implicit grant type.
  DEPRECATED: Not recommended for security reasons.

  ## Examples

      iex> GrantType.implicit()
      {:ok, %GrantType{type: :implicit}}
  """
  def implicit, do: new(:implicit)

  @doc """
  Creates a Password grant type.
  DEPRECATED: Only for legacy applications.

  ## Examples

      iex> GrantType.password()
      {:ok, %GrantType{type: :password}}
  """
  def password, do: new(:password)

  @doc """
  Checks if this grant type is recommended by OAuth2 best practices.

  ## Examples

      iex> {:ok, grant} = GrantType.authorization_code()
      iex> GrantType.recommended?(grant)
      true

      iex> {:ok, grant} = GrantType.implicit()
      iex> GrantType.recommended?(grant)
      false
  """
  def recommended?(%__MODULE__{type: type}), do: type in @recommended_types

  @doc """
  Checks if this grant type requires a user.

  ## Examples

      iex> {:ok, grant} = GrantType.authorization_code()
      iex> GrantType.requires_user?(grant)
      true

      iex> {:ok, grant} = GrantType.client_credentials()
      iex> GrantType.requires_user?(grant)
      false
  """
  def requires_user?(%__MODULE__{requires_user: required}), do: required

  @doc """
  Checks if this grant type requires a client secret.

  ## Examples

      iex> {:ok, grant} = GrantType.client_credentials()
      iex> GrantType.requires_client_secret?(grant)
      true

      iex> {:ok, grant} = GrantType.implicit()
      iex> GrantType.requires_client_secret?(grant)
      false
  """
  def requires_client_secret?(%__MODULE__{requires_client_secret: required}), do: required

  @doc """
  Checks if this grant type issues refresh tokens.

  ## Examples

      iex> {:ok, grant} = GrantType.authorization_code()
      iex> GrantType.issues_refresh_token?(grant)
      true

      iex> {:ok, grant} = GrantType.implicit()
      iex> GrantType.issues_refresh_token?(grant)
      false
  """
  def issues_refresh_token?(%__MODULE__{issues_refresh_token: issues}), do: issues

  @doc """
  Checks if this grant type requires PKCE.

  ## Examples

      iex> {:ok, grant} = GrantType.authorization_code()
      iex> GrantType.pkce_required?(grant)
      true

      iex> {:ok, grant} = GrantType.client_credentials()
      iex> GrantType.pkce_required?(grant)
      false
  """
  def pkce_required?(%__MODULE__{pkce_required: required}), do: required

  @doc """
  Checks if grant types are compatible (can be used together).

  ## Examples

      iex> {:ok, auth_code} = GrantType.authorization_code()
      iex> {:ok, refresh} = GrantType.refresh_token()
      iex> GrantType.compatible?(auth_code, refresh)
      true

      iex> {:ok, implicit} = GrantType.implicit()
      iex> GrantType.compatible?(implicit, refresh)
      false
  """
  def compatible?(%__MODULE__{type: :authorization_code}, %__MODULE__{type: :refresh_token}),
    do: true

  def compatible?(%__MODULE__{type: :password}, %__MODULE__{type: :refresh_token}), do: true

  def compatible?(%__MODULE__{type: :client_credentials}, %__MODULE__{
        type: :client_credentials
      }),
      do: true

  def compatible?(_, _), do: false

  # Private functions

  defp build_grant_type(:authorization_code) do
    %__MODULE__{
      type: :authorization_code,
      requires_user: true,
      requires_client_secret: true,
      issues_refresh_token: true,
      pkce_required: true
    }
  end

  defp build_grant_type(:client_credentials) do
    %__MODULE__{
      type: :client_credentials,
      requires_user: false,
      requires_client_secret: true,
      issues_refresh_token: false,
      pkce_required: false
    }
  end

  defp build_grant_type(:refresh_token) do
    %__MODULE__{
      type: :refresh_token,
      requires_user: true,
      requires_client_secret: true,
      issues_refresh_token: true,
      pkce_required: false
    }
  end

  defp build_grant_type(:implicit) do
    %__MODULE__{
      type: :implicit,
      requires_user: true,
      requires_client_secret: false,
      issues_refresh_token: false,
      pkce_required: false
    }
  end

  defp build_grant_type(:password) do
    %__MODULE__{
      type: :password,
      requires_user: true,
      requires_client_secret: true,
      issues_refresh_token: true,
      pkce_required: false
    }
  end
end

# Implement String.Chars protocol
defimpl String.Chars, for: Thalamus.Domain.ValueObjects.GrantType do
  def to_string(%Thalamus.Domain.ValueObjects.GrantType{type: type}) do
    "GrantType:#{type}"
  end
end

# Implement Jason.Encoder for JSON serialization
defimpl Jason.Encoder, for: Thalamus.Domain.ValueObjects.GrantType do
  def encode(%Thalamus.Domain.ValueObjects.GrantType{} = grant, opts) do
    %{
      type: grant.type,
      requires_user: grant.requires_user,
      requires_client_secret: grant.requires_client_secret,
      issues_refresh_token: grant.issues_refresh_token,
      pkce_required: grant.pkce_required
    }
    |> Jason.Encode.map(opts)
  end
end
