defmodule Thalamus.Domain.ValueObjects.Email do
  @moduledoc """
  Value Object representing an email address.

  SOLID Principles Applied:
  - Single Responsibility: Only handles email validation and formatting
  - Open/Closed: Can be extended for different email validation rules without modification
  - Interface Segregation: Provides only email-specific operations
  """

  @type t :: %__MODULE__{
          value: String.t()
        }

  defstruct [:value]

  @email_regex ~r/^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/

  @doc """
  Creates a new Email.

  ## Examples

      iex> Email.new("user@example.com")
      {:ok, %Email{value: "user@example.com"}}

      iex> Email.new("invalid-email")
      {:error, :invalid_email_format}

      iex> Email.new("")
      {:error, :invalid_email}

      iex> Email.new(nil)
      {:error, :invalid_email}
  """
  def new(value) when is_binary(value) and value != "" do
    normalized_email = String.downcase(String.trim(value))

    case validate_format(normalized_email) do
      :ok -> {:ok, %__MODULE__{value: normalized_email}}
      {:error, reason} -> {:error, reason}
    end
  end

  def new(_), do: {:error, :invalid_email}

  @doc """
  Converts Email to string for database storage or API responses.

  ## Examples

      iex> email = %Email{value: "user@example.com"}
      iex> Email.to_string(email)
      "user@example.com"
  """
  def to_string(%__MODULE__{value: value}), do: value

  @doc """
  Creates Email from string (for database loading).

  ## Examples

      iex> Email.from_string("user@example.com")
      {:ok, %Email{value: "user@example.com"}}
  """
  def from_string(value), do: new(value)

  @doc """
  Gets the domain part of the email.

  ## Examples

      iex> email = %Email{value: "user@example.com"}
      iex> Email.domain(email)
      "example.com"
  """
  def domain(%__MODULE__{value: value}) do
    value
    |> String.split("@")
    |> List.last()
  end

  @doc """
  Gets the local part of the email (before @).

  ## Examples

      iex> email = %Email{value: "user@example.com"}
      iex> Email.local_part(email)
      "user"
  """
  def local_part(%__MODULE__{value: value}) do
    value
    |> String.split("@")
    |> List.first()
  end

  @doc """
  Checks if the email is from a disposable email provider.
  """
  def disposable?(%__MODULE__{} = email) do
    domain = domain(email)

    # List of common disposable email domains
    disposable_domains = [
      "10minutemail.com",
      "guerrillamail.com",
      "mailinator.com",
      "tempmail.org",
      "yopmail.com",
      "throwaway.email"
    ]

    Enum.member?(disposable_domains, domain)
  end

  # Private functions

  defp validate_format(value) do
    cond do
      String.length(value) < 3 ->
        {:error, :email_too_short}

      String.length(value) > 254 ->
        {:error, :email_too_long}

      not String.match?(value, @email_regex) ->
        {:error, :invalid_email_format}

      has_consecutive_dots?(value) ->
        {:error, :invalid_email_format}

      starts_or_ends_with_dot?(value) ->
        {:error, :invalid_email_format}

      true ->
        :ok
    end
  end

  defp has_consecutive_dots?(value) do
    String.contains?(value, "..")
  end

  defp starts_or_ends_with_dot?(value) do
    String.starts_with?(value, ".") or String.ends_with?(value, ".")
  end
end

# Implement String.Chars protocol for easy conversion
defimpl String.Chars, for: Thalamus.Domain.ValueObjects.Email do
  def to_string(%Thalamus.Domain.ValueObjects.Email{value: value}), do: value
end

# Implement Jason.Encoder for JSON serialization
defimpl Jason.Encoder, for: Thalamus.Domain.ValueObjects.Email do
  def encode(%Thalamus.Domain.ValueObjects.Email{value: value}, opts) do
    Jason.Encode.string(value, opts)
  end
end
