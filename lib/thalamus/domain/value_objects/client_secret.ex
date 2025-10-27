defmodule Thalamus.Domain.ValueObjects.ClientSecret do
  @moduledoc """
  Value object representing an OAuth2 client secret.

  Handles secure generation, hashing, and verification of client secrets.
  """

  @type t :: %__MODULE__{
          hash: String.t()
        }

  defstruct [:hash]

  @doc """
  Generates a new random client secret and returns both the plain text
  and the hashed value object.

  Returns: `{plain_secret, %ClientSecret{}}`
  """
  @spec generate() :: {String.t(), t()}
  def generate do
    # Generate 32 random bytes, encode as base64url (43 characters)
    plain_secret = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)

    # Hash the secret using bcrypt
    hash = Bcrypt.hash_pwd_salt(plain_secret)

    {plain_secret, %__MODULE__{hash: hash}}
  end

  @doc """
  Creates a ClientSecret from an already-hashed value.
  Used when loading from database.
  """
  @spec from_hash(String.t()) :: t()
  def from_hash(hash) when is_binary(hash) do
    %__MODULE__{hash: hash}
  end

  @doc """
  Verifies a plain text secret against a hashed ClientSecret.

  ## Examples

      iex> {plain, secret} = ClientSecret.generate()
      iex> ClientSecret.verify(secret, plain)
      true

      iex> {_plain, secret} = ClientSecret.generate()
      iex> ClientSecret.verify(secret, "wrong_secret")
      false
  """
  @spec verify(t(), String.t()) :: boolean()
  def verify(%__MODULE__{hash: hash}, plain_secret) when is_binary(plain_secret) do
    Bcrypt.verify_pass(plain_secret, hash)
  end

  @doc """
  Converts the ClientSecret to its hash representation.
  Used for database storage.
  """
  @spec to_string(t()) :: String.t()
  def to_string(%__MODULE__{hash: hash}), do: hash

  @doc """
  Returns the hash value for storage.
  """
  @spec hash(t()) :: String.t()
  def hash(%__MODULE__{hash: hash}), do: hash
end
