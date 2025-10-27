defmodule Thalamus.Domain.ValueObjects.PKCEChallenge do
  @moduledoc """
  Value Object representing a PKCE (Proof Key for Code Exchange) challenge.

  SOLID Principles Applied:
  - Single Responsibility: Only handles PKCE challenge creation and verification
  - Open/Closed: Can be extended for different challenge methods without modification
  - Interface Segregation: Provides only PKCE-specific operations
  """

  @type challenge_method :: :plain | :S256
  @type t :: %__MODULE__{
          value: String.t(),
          method: challenge_method()
        }

  defstruct [:value, :method]

  @min_challenge_length 43  # RFC 7636 requirement
  @max_challenge_length 128

  @doc """
  Creates a new PKCEChallenge.

  ## Examples

      iex> PKCEChallenge.new("dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk", :S256)
      {:ok, %PKCEChallenge{value: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk", method: :S256}}

      iex> PKCEChallenge.new("short", :S256)
      {:error, :challenge_too_short}

      iex> PKCEChallenge.new("valid_challenge_code", :invalid_method)
      {:error, :invalid_challenge_method}
  """
  def new(value, method) when is_binary(value) and method in [:plain, :S256] do
    case validate_challenge(value, method) do
      :ok -> {:ok, %__MODULE__{value: value, method: method}}
      {:error, reason} -> {:error, reason}
    end
  end

  def new(_, _), do: {:error, :invalid_parameters}

  @doc """
  Creates a PKCE challenge from a code verifier.

  ## Examples

      iex> verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
      iex> PKCEChallenge.from_verifier(verifier, :S256)
      {:ok, %PKCEChallenge{value: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM", method: :S256}}

      iex> PKCEChallenge.from_verifier(verifier, :plain)
      {:ok, %PKCEChallenge{value: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk", method: :plain}}
  """
  def from_verifier(verifier, method) when is_binary(verifier) and method in [:plain, :S256] do
    case validate_verifier(verifier) do
      :ok ->
        challenge_value = generate_challenge(verifier, method)
        new(challenge_value, method)
      {:error, reason} ->
        {:error, reason}
    end
  end

  def from_verifier(_, _), do: {:error, :invalid_parameters}

  @doc """
  Generates a new PKCE verifier and challenge pair.

  ## Examples

      iex> PKCEChallenge.generate(:S256)
      {:ok, {verifier, %PKCEChallenge{method: :S256}}}
  """
  def generate(method \\ :S256) when method in [:plain, :S256] do
    verifier = generate_verifier()

    case from_verifier(verifier, method) do
      {:ok, challenge} -> {:ok, {verifier, challenge}}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Verifies a code verifier against the challenge.

  ## Examples

      iex> challenge = %PKCEChallenge{value: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM", method: :S256}
      iex> verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
      iex> PKCEChallenge.verify(challenge, verifier)
      :ok

      iex> PKCEChallenge.verify(challenge, "wrong_verifier")
      {:error, :verification_failed}
  """
  def verify(%__MODULE__{value: expected_challenge, method: method}, verifier) when is_binary(verifier) do
    case validate_verifier(verifier) do
      :ok ->
        actual_challenge = generate_challenge(verifier, method)
        if secure_compare(expected_challenge, actual_challenge) do
          :ok
        else
          {:error, :verification_failed}
        end
      {:error, reason} ->
        {:error, reason}
    end
  end

  def verify(_, _), do: {:error, :invalid_parameters}

  @doc """
  Converts PKCEChallenge to string representation.

  ## Examples

      iex> challenge = %PKCEChallenge{value: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"}
      iex> PKCEChallenge.to_string(challenge)
      "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
  """
  def to_string(%__MODULE__{value: value}), do: value

  @doc """
  Gets the challenge method as a string.

  ## Examples

      iex> challenge = %PKCEChallenge{method: :S256}
      iex> PKCEChallenge.method_string(challenge)
      "S256"

      iex> challenge = %PKCEChallenge{method: :plain}
      iex> PKCEChallenge.method_string(challenge)
      "plain"
  """
  def method_string(%__MODULE__{method: method}), do: Atom.to_string(method)

  @doc """
  Checks if the challenge method is secure (S256).

  ## Examples

      iex> challenge = %PKCEChallenge{method: :S256}
      iex> PKCEChallenge.secure?(challenge)
      true

      iex> challenge = %PKCEChallenge{method: :plain}
      iex> PKCEChallenge.secure?(challenge)
      false
  """
  def secure?(%__MODULE__{method: :S256}), do: true
  def secure?(%__MODULE__{method: :plain}), do: false

  # Private functions

  defp validate_challenge(value, method) do
    cond do
      String.length(value) < @min_challenge_length ->
        {:error, :challenge_too_short}

      String.length(value) > @max_challenge_length ->
        {:error, :challenge_too_long}

      not valid_challenge_format?(value) ->
        {:error, :invalid_challenge_format}

      method == :S256 and not valid_base64_url?(value) ->
        {:error, :invalid_base64_url_format}

      true ->
        :ok
    end
  end

  defp validate_verifier(verifier) do
    cond do
      String.length(verifier) < @min_challenge_length ->
        {:error, :verifier_too_short}

      String.length(verifier) > @max_challenge_length ->
        {:error, :verifier_too_long}

      not valid_verifier_format?(verifier) ->
        {:error, :invalid_verifier_format}

      true ->
        :ok
    end
  end

  defp valid_challenge_format?(value) do
    # PKCE challenge should contain only URL-safe characters
    String.match?(value, ~r/^[a-zA-Z0-9_.-~]+$/)
  end

  defp valid_verifier_format?(value) do
    # PKCE verifier should contain only URL-safe characters
    String.match?(value, ~r/^[a-zA-Z0-9_.-~]+$/)
  end

  defp valid_base64_url?(value) do
    # Check if string is valid base64url (no padding, URL-safe characters)
    case Base.url_decode64(value, padding: false) do
      {:ok, _} -> true
      :error -> false
    end
  end

  defp generate_challenge(verifier, :plain), do: verifier

  defp generate_challenge(verifier, :S256) do
    :crypto.hash(:sha256, verifier)
    |> Base.url_encode64(padding: false)
  end

  defp generate_verifier do
    # Generate a cryptographically secure random verifier
    # RFC 7636 recommends 32 octets of random data
    :crypto.strong_rand_bytes(32)
    |> Base.url_encode64(padding: false)
  end

  defp secure_compare(a, b) do
    # Constant-time string comparison to prevent timing attacks
    import Bitwise
    if String.length(a) != String.length(b) do
      false
    else
      a
      |> String.to_charlist()
      |> Enum.zip(String.to_charlist(b))
      |> Enum.map(fn {x, y} -> bxor(x, y) end)
      |> Enum.reduce(0, &(&1 ||| &2))
      |> Kernel.==(0)
    end
  end
end

# Implement String.Chars protocol for easy conversion
defimpl String.Chars, for: Thalamus.Domain.ValueObjects.PKCEChallenge do
  def to_string(%Thalamus.Domain.ValueObjects.PKCEChallenge{value: value}), do: value
end

# Implement Jason.Encoder for JSON serialization
defimpl Jason.Encoder, for: Thalamus.Domain.ValueObjects.PKCEChallenge do
  def encode(%Thalamus.Domain.ValueObjects.PKCEChallenge{value: value, method: method}, opts) do
    Jason.Encode.map(%{
      challenge: value,
      challenge_method: Atom.to_string(method)
    }, opts)
  end
end