defmodule Thalamus.Domain.Services.PersonalAccessTokenGenerator do
  @moduledoc """
  Service for generating secure Personal Access Tokens (PATs).

  Generates cryptographically secure tokens with the following format:
  `th_pat_{env}_{random_32_bytes}`

  Where:
  - `th_pat_` is the fixed prefix
  - `env` is either "dev" or "live" based on the environment
  - `random_32_bytes` is a cryptographically secure random string
  """

  @doc """
  Generates a new Personal Access Token.
  """
  def generate(env \\ Mix.env()) do
    env_prefix = environment_prefix(env)
    random_part = generate_random_part()

    token = "th_pat_#{env_prefix}_#{random_part}"
    token_prefix = String.slice(token, 0, 16)
    token_hash = hash_token(token)

    %{
      token: token,
      token_prefix: token_prefix,
      token_hash: token_hash
    }
  end

  def hash_token(token) do
    Bcrypt.hash_pwd_salt(token, rounds: 10)
  end

  def verify_token(token, token_hash) do
    Bcrypt.verify_pass(token, token_hash)
  end

  def extract_prefix(token) when byte_size(token) < 16 do
    {:error, :invalid_token_length}
  end

  def extract_prefix(token) do
    {:ok, String.slice(token, 0, 16)}
  end

  def valid_format?(token) when is_binary(token) do
    case String.split(token, "_", parts: 4) do
      ["th", "pat", env, random] when env in ["dev", "live"] and byte_size(random) > 20 ->
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
