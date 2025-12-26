defmodule Thalamus.Domain.Services.AdminApiKeyGenerator do
  @moduledoc """
  Service for generating secure Admin API Keys.

  Generates cryptographically secure API keys with the following format:
  `ak_{env}_{random_32_bytes}`

  Where:
  - `ak_` is the fixed prefix (Admin Key)
  - `env` is either "dev" or "live" based on the environment
  - `random_32_bytes` is a cryptographically secure random string

  SOLID Principles Applied:
  - Single Responsibility: Only generates API keys
  - Open/Closed: Can be extended for different key formats without modification

  ## Security Considerations

  - Uses :crypto.strong_rand_bytes/1 for cryptographically secure randomness
  - Generates 32 bytes of entropy (256 bits)
  - Keys are URL-safe base64 encoded
  - Returns key_hash (Bcrypt) for secure storage
  - Returns key_prefix (first 12 chars) for efficient lookup
  """

  @doc """
  Generates a new Admin API Key.

  Returns a map containing:
  - `api_key` - The full API key (only show once to user)
  - `key_prefix` - First 13 characters for database lookup
  - `key_hash` - Bcrypt hash for secure storage

  ## Examples

      iex> %{api_key: key, key_prefix: prefix, key_hash: hash} = AdminApiKeyGenerator.generate()
      iex> String.starts_with?(key, "ak_")
      true
      iex> String.length(prefix)
      13
      iex> String.starts_with?(hash, "$2b$")
      true

      # Development environment
      iex> %{api_key: key} = AdminApiKeyGenerator.generate()
      iex> String.starts_with?(key, "ak_dev_")
      true

      # Production environment (when Mix.env() == :prod)
      iex> %{api_key: key} = AdminApiKeyGenerator.generate(:prod)
      iex> String.starts_with?(key, "ak_live_")
      true
  """
  def generate(env \\ Mix.env()) do
    env_prefix = environment_prefix(env)
    random_part = generate_random_part()

    api_key = "ak_#{env_prefix}_#{random_part}"
    key_prefix = String.slice(api_key, 0, 13)
    key_hash = hash_key(api_key)

    %{
      api_key: api_key,
      key_prefix: key_prefix,
      key_hash: key_hash
    }
  end

  @doc """
  Hashes an API key using Bcrypt.

  ## Examples

      iex> key = "ak_dev_vK8mN2pQ7xR9tY3wZ5aB1cD4eF6gH8jL"
      iex> hash = AdminApiKeyGenerator.hash_key(key)
      iex> String.starts_with?(hash, "$2b$")
      true
  """
  def hash_key(api_key) do
    Bcrypt.hash_pwd_salt(api_key, rounds: 10)
  end

  @doc """
  Verifies if a given API key matches the stored hash.

  Uses constant-time comparison to prevent timing attacks.

  ## Examples

      iex> key = "ak_dev_vK8mN2pQ7xR9tY3wZ5aB1cD4eF6gH8jL"
      iex> hash = AdminApiKeyGenerator.hash_key(key)
      iex> AdminApiKeyGenerator.verify_key(key, hash)
      true
      iex> AdminApiKeyGenerator.verify_key("wrong_key", hash)
      false
  """
  def verify_key(api_key, key_hash) do
    Bcrypt.verify_pass(api_key, key_hash)
  end

  @doc """
  Extracts the key prefix from a full API key.

  The prefix is the first 13 characters and is used for database lookup.

  ## Examples

      iex> key = "ak_dev_vK8mN2pQ7xR9tY3wZ5aB1cD4eF6gH8jL"
      iex> AdminApiKeyGenerator.extract_prefix(key)
      "ak_dev_vK8mN2"

      iex> AdminApiKeyGenerator.extract_prefix("short")
      {:error, :invalid_key_length}
  """
  def extract_prefix(api_key) when byte_size(api_key) < 13 do
    {:error, :invalid_key_length}
  end

  def extract_prefix(api_key) do
    String.slice(api_key, 0, 13)
  end

  @doc """
  Validates the format of an API key.

  ## Examples

      iex> AdminApiKeyGenerator.valid_format?("ak_dev_vK8mN2pQ7xR9tY3wZ5aB1cD4eF6gH8jL")
      true

      iex> AdminApiKeyGenerator.valid_format?("ak_live_xY9zA2bC4dE6fG8hJ1kL3mN5pQ7rS9tU")
      true

      iex> AdminApiKeyGenerator.valid_format?("invalid_key")
      false

      iex> AdminApiKeyGenerator.valid_format?("ak_prod_somekey")
      false
  """
  def valid_format?(api_key) when is_binary(api_key) do
    case String.split(api_key, "_", parts: 3) do
      ["ak", env, random] when env in ["dev", "live"] and byte_size(random) > 20 ->
        true

      _ ->
        false
    end
  end

  def valid_format?(_), do: false

  # Private functions

  defp environment_prefix(:prod), do: "live"
  defp environment_prefix(:test), do: "dev"
  defp environment_prefix(:dev), do: "dev"
  defp environment_prefix(_), do: "dev"

  defp generate_random_part do
    :crypto.strong_rand_bytes(32)
    |> Base.url_encode64(padding: false)
  end
end
