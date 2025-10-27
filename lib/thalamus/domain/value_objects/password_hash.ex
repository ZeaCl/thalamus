defmodule Thalamus.Domain.ValueObjects.PasswordHash do
  @moduledoc """
  Value Object representing a hashed password.

  SOLID Principles Applied:
  - Single Responsibility: Only handles password hashing and verification
  - Open/Closed: Can be extended for different hashing algorithms without modification
  - Dependency Inversion: Uses Bcrypt for hashing but could be swapped
  """

  @type t :: %__MODULE__{
          hash: String.t()
        }

  defstruct [:hash]

  @doc """
  Creates a new PasswordHash from a plaintext password.

  ## Examples

      iex> PasswordHash.from_password("SecureP@ssw0rd!")
      {:ok, %PasswordHash{hash: "$2b$12$..."}}

      iex> PasswordHash.from_password("")
      {:error, :password_too_short}

      iex> PasswordHash.from_password("weak")
      {:error, :password_too_short}
  """
  def from_password(password) when is_binary(password) do
    case validate_password(password) do
      :ok ->
        hash = Bcrypt.hash_pwd_salt(password)
        {:ok, %__MODULE__{hash: hash}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def from_password(_), do: {:error, :invalid_password}

  @doc """
  Creates a PasswordHash from an existing hash string.
  Used when loading from database.

  ## Examples

      iex> PasswordHash.from_hash("$2b$12$abc123...")
      {:ok, %PasswordHash{hash: "$2b$12$abc123..."}}

      iex> PasswordHash.from_hash("")
      {:error, :invalid_hash}
  """
  def from_hash(hash) when is_binary(hash) and hash != "" do
    case validate_hash_format(hash) do
      :ok -> {:ok, %__MODULE__{hash: hash}}
      {:error, reason} -> {:error, reason}
    end
  end

  def from_hash(_), do: {:error, :invalid_hash}

  @doc """
  Verifies a plaintext password against the hash.

  ## Examples

      iex> {:ok, password_hash} = PasswordHash.from_password("SecureP@ssw0rd!")
      iex> PasswordHash.verify(password_hash, "SecureP@ssw0rd!")
      :ok

      iex> {:ok, password_hash} = PasswordHash.from_password("SecureP@ssw0rd!")
      iex> PasswordHash.verify(password_hash, "WrongPassword")
      {:error, :invalid_password}
  """
  def verify(%__MODULE__{hash: hash}, password) when is_binary(password) do
    if Bcrypt.verify_pass(password, hash) do
      :ok
    else
      {:error, :invalid_password}
    end
  end

  def verify(_, _), do: {:error, :invalid_password}

  @doc """
  Returns the hash string for database storage.

  ## Examples

      iex> password_hash = %PasswordHash{hash: "$2b$12$abc123..."}
      iex> PasswordHash.to_string(password_hash)
      "$2b$12$abc123..."
  """
  def to_string(%__MODULE__{hash: hash}), do: hash

  # Private functions

  defp validate_password(password) do
    cond do
      String.length(password) < 8 ->
        {:error, :password_too_short}

      String.length(password) > 128 ->
        {:error, :password_too_long}

      not has_uppercase?(password) ->
        {:error, :password_missing_uppercase}

      not has_lowercase?(password) ->
        {:error, :password_missing_lowercase}

      not has_digit?(password) ->
        {:error, :password_missing_digit}

      not has_special_char?(password) ->
        {:error, :password_missing_special_char}

      true ->
        :ok
    end
  end

  defp validate_hash_format(hash) do
    # Bcrypt hashes start with $2b$ or $2a$ or $2y$ and have specific length
    if String.match?(hash, ~r/^\$2[aby]\$\d{2}\$.{53}$/) do
      :ok
    else
      {:error, :invalid_hash_format}
    end
  end

  defp has_uppercase?(password), do: String.match?(password, ~r/[A-Z]/)
  defp has_lowercase?(password), do: String.match?(password, ~r/[a-z]/)
  defp has_digit?(password), do: String.match?(password, ~r/[0-9]/)
  defp has_special_char?(password), do: String.match?(password, ~r/[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?]/)
end

# Implement String.Chars protocol for easy conversion
defimpl String.Chars, for: Thalamus.Domain.ValueObjects.PasswordHash do
  def to_string(%Thalamus.Domain.ValueObjects.PasswordHash{hash: hash}), do: hash
end

# Implement Jason.Encoder - NEVER expose password hash in JSON
defimpl Jason.Encoder, for: Thalamus.Domain.ValueObjects.PasswordHash do
  def encode(%Thalamus.Domain.ValueObjects.PasswordHash{}, opts) do
    # Never expose password hash in JSON responses
    Jason.Encode.string("[REDACTED]", opts)
  end
end
