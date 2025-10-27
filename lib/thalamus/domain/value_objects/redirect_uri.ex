defmodule Thalamus.Domain.ValueObjects.RedirectUri do
  @moduledoc """
  Value Object representing an OAuth2 redirect URI.

  SOLID Principles Applied:
  - Single Responsibility: Only handles redirect URI validation and operations
  - Open/Closed: Can be extended for different URI validation rules without modification
  - Interface Segregation: Provides only redirect URI specific operations
  """

  @type t :: %__MODULE__{
          value: String.t()
        }

  defstruct [:value]

  @doc """
  Creates a new RedirectUri.

  ## Examples

      iex> RedirectUri.new("https://app.example.com/callback")
      {:ok, %RedirectUri{value: "https://app.example.com/callback"}}

      iex> RedirectUri.new("http://localhost:3000/callback")
      {:ok, %RedirectUri{value: "http://localhost:3000/callback"}}

      iex> RedirectUri.new("invalid-uri")
      {:error, :invalid_redirect_uri_format}

      iex> RedirectUri.new("")
      {:error, :invalid_redirect_uri}
  """
  def new(value) when is_binary(value) and value != "" do
    case validate_format(value) do
      :ok -> {:ok, %__MODULE__{value: value}}
      {:error, reason} -> {:error, reason}
    end
  end

  def new(_), do: {:error, :invalid_redirect_uri}

  @doc """
  Converts RedirectUri to string for database storage or API responses.

  ## Examples

      iex> redirect_uri = %RedirectUri{value: "https://app.example.com/callback"}
      iex> RedirectUri.to_string(redirect_uri)
      "https://app.example.com/callback"
  """
  def to_string(%__MODULE__{value: value}), do: value

  @doc """
  Creates RedirectUri from string (for database loading).

  ## Examples

      iex> RedirectUri.from_string("https://app.example.com/callback")
      {:ok, %RedirectUri{value: "https://app.example.com/callback"}}
  """
  def from_string(value), do: new(value)

  @doc """
  Checks if the redirect URI is secure (HTTPS).

  ## Examples

      iex> uri = %RedirectUri{value: "https://app.example.com/callback"}
      iex> RedirectUri.secure?(uri)
      true

      iex> uri = %RedirectUri{value: "http://example.com/callback"}
      iex> RedirectUri.secure?(uri)
      false

      iex> uri = %RedirectUri{value: "http://localhost:3000/callback"}
      iex> RedirectUri.secure?(uri)
      true  # localhost is considered secure for development
  """
  def secure?(%__MODULE__{value: value}) do
    uri = URI.parse(value)

    case uri.scheme do
      "https" -> true
      "http" -> is_localhost_host?(uri.host)
      _ -> false
    end
  end

  @doc """
  Checks if the redirect URI is for localhost (development).

  ## Examples

      iex> uri = %RedirectUri{value: "http://localhost:3000/callback"}
      iex> RedirectUri.localhost?(uri)
      true

      iex> uri = %RedirectUri{value: "https://app.example.com/callback"}
      iex> RedirectUri.localhost?(uri)
      false
  """
  def localhost?(%__MODULE__{value: value}) do
    uri = URI.parse(value)
    is_localhost_host?(uri.host)
  end

  @doc """
  Gets the host from the redirect URI.

  ## Examples

      iex> uri = %RedirectUri{value: "https://app.example.com/callback"}
      iex> RedirectUri.host(uri)
      "app.example.com"
  """
  def host(%__MODULE__{value: value}) do
    URI.parse(value).host
  end

  @doc """
  Gets the scheme from the redirect URI.

  ## Examples

      iex> uri = %RedirectUri{value: "https://app.example.com/callback"}
      iex> RedirectUri.scheme(uri)
      "https"
  """
  def scheme(%__MODULE__{value: value}) do
    URI.parse(value).scheme
  end

  @doc """
  Gets the path from the redirect URI.

  ## Examples

      iex> uri = %RedirectUri{value: "https://app.example.com/callback"}
      iex> RedirectUri.path(uri)
      "/callback"
  """
  def path(%__MODULE__{value: value}) do
    URI.parse(value).path
  end

  @doc """
  Checks if the redirect URI matches against a list of allowed URIs.

  ## Examples

      iex> uri = %RedirectUri{value: "https://app.example.com/callback"}
      iex> allowed = ["https://app.example.com/callback", "https://app.example.com/auth"]
      iex> RedirectUri.allowed?(uri, allowed)
      true

      iex> RedirectUri.allowed?(uri, ["https://other.com/callback"])
      false
  """
  def allowed?(%__MODULE__{value: value}, allowed_uris) when is_list(allowed_uris) do
    Enum.member?(allowed_uris, value)
  end

  # Private functions

  defp validate_format(value) do
    cond do
      String.length(value) < 8 ->  # Minimum: "http://a"
        {:error, :redirect_uri_too_short}

      String.length(value) > 2048 ->
        {:error, :redirect_uri_too_long}

      not valid_uri_format?(value) ->
        {:error, :invalid_redirect_uri_format}

      not valid_scheme?(value) ->
        {:error, :invalid_redirect_uri_scheme}

      has_fragment?(value) ->
        {:error, :redirect_uri_has_fragment}

      true ->
        :ok
    end
  end

  defp valid_uri_format?(value) do
    case URI.parse(value) do
      %URI{scheme: scheme, host: host} when not is_nil(scheme) and not is_nil(host) ->
        true
      _ ->
        false
    end
  end

  defp valid_scheme?(value) do
    uri = URI.parse(value)
    uri.scheme in ["http", "https"]
  end

  defp has_fragment?(value) do
    uri = URI.parse(value)
    not is_nil(uri.fragment)
  end

  defp is_localhost_host?(host) do
    host in ["localhost", "127.0.0.1", "::1"] or
      String.starts_with?(host || "", "127.") or
      String.starts_with?(host || "", "192.168.") or
      String.starts_with?(host || "", "10.") or
      (String.starts_with?(host || "", "172.") and
       String.length(host || "") >= 8 and
       is_private_172_network?(host))
  end

  defp is_private_172_network?(host) do
    case host |> String.split(".") |> Enum.at(1) do
      nil -> false
      second_octet_str ->
        case Integer.parse(second_octet_str) do
          {second_octet, ""} -> second_octet in 16..31
          _ -> false
        end
    end
  end
end

# Implement String.Chars protocol for easy conversion
defimpl String.Chars, for: Thalamus.Domain.ValueObjects.RedirectUri do
  def to_string(%Thalamus.Domain.ValueObjects.RedirectUri{value: value}), do: value
end

# Implement Jason.Encoder for JSON serialization
defimpl Jason.Encoder, for: Thalamus.Domain.ValueObjects.RedirectUri do
  def encode(%Thalamus.Domain.ValueObjects.RedirectUri{value: value}, opts) do
    Jason.Encode.string(value, opts)
  end
end