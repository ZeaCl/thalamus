defmodule Thalamus.Domain.ValueObjects.MFAMethod do
  @moduledoc """
  Value Object representing a Multi-Factor Authentication method.

  SOLID Principles Applied:
  - Single Responsibility: Only handles MFA method validation and configuration
  - Open/Closed: Can be extended for new MFA types without modification
  """

  @type method_type :: :totp | :sms | :email | :webauthn
  @type t :: %__MODULE__{
          type: method_type(),
          identifier: String.t(),
          verified: boolean(),
          created_at: DateTime.t()
        }

  defstruct [:type, :identifier, :verified, :created_at]

  @valid_types [:totp, :sms, :email, :webauthn]

  @doc """
  Creates a new MFA method.

  ## Examples

      iex> MFAMethod.new(:totp, "JBSWY3DPEHPK3PXP", true)
      {:ok, %MFAMethod{type: :totp, identifier: "JBSWY3DPEHPK3PXP", verified: true}}

      iex> MFAMethod.new(:sms, "+1234567890", false)
      {:ok, %MFAMethod{type: :sms, identifier: "+1234567890", verified: false}}

      iex> MFAMethod.new(:invalid_type, "test", true)
      {:error, :invalid_mfa_type}

      iex> MFAMethod.new(:totp, "", true)
      {:error, :invalid_identifier}
  """
  def new(type, identifier, verified \\ false)

  def new(type, identifier, verified)
      when type in @valid_types and is_binary(identifier) and is_boolean(verified) do
    case validate(type, identifier) do
      :ok ->
        {:ok,
         %__MODULE__{
           type: type,
           identifier: identifier,
           verified: verified,
           created_at: DateTime.utc_now()
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def new(type, _, _) when type not in @valid_types, do: {:error, :invalid_mfa_type}
  def new(_, _, _), do: {:error, :invalid_mfa_method}

  @doc """
  Creates a TOTP (Time-based One-Time Password) method.
  Used with apps like Google Authenticator.

  ## Examples

      iex> MFAMethod.totp("JBSWY3DPEHPK3PXP")
      {:ok, %MFAMethod{type: :totp, identifier: "JBSWY3DPEHPK3PXP"}}
  """
  def totp(secret) when is_binary(secret) and secret != "" do
    new(:totp, secret, false)
  end

  def totp(_), do: {:error, :invalid_totp_secret}

  @doc """
  Creates an SMS-based MFA method.

  ## Examples

      iex> MFAMethod.sms("+1234567890")
      {:ok, %MFAMethod{type: :sms, identifier: "+1234567890"}}

      iex> MFAMethod.sms("invalid")
      {:error, :invalid_phone_number}
  """
  def sms(phone_number) when is_binary(phone_number) do
    case validate_phone_number(phone_number) do
      :ok -> new(:sms, phone_number, false)
      {:error, reason} -> {:error, reason}
    end
  end

  def sms(_), do: {:error, :invalid_phone_number}

  @doc """
  Creates an Email-based MFA method.

  ## Examples

      iex> MFAMethod.email("user@example.com")
      {:ok, %MFAMethod{type: :email, identifier: "user@example.com"}}

      iex> MFAMethod.email("invalid")
      {:error, :invalid_email}
  """
  def email(email_address) when is_binary(email_address) do
    case validate_email(email_address) do
      :ok -> new(:email, email_address, false)
      {:error, reason} -> {:error, reason}
    end
  end

  def email(_), do: {:error, :invalid_email}

  @doc """
  Creates a WebAuthn/FIDO2 method (hardware security keys).

  ## Examples

      iex> MFAMethod.webauthn("credential_id_base64")
      {:ok, %MFAMethod{type: :webauthn, identifier: "credential_id_base64"}}
  """
  def webauthn(credential_id) when is_binary(credential_id) and credential_id != "" do
    new(:webauthn, credential_id, false)
  end

  def webauthn(_), do: {:error, :invalid_webauthn_credential}

  @doc """
  Marks an MFA method as verified.

  ## Examples

      iex> {:ok, method} = MFAMethod.totp("SECRET")
      iex> MFAMethod.verify(method)
      %MFAMethod{verified: true, ...}
  """
  def verify(%__MODULE__{} = method) do
    %{method | verified: true}
  end

  @doc """
  Checks if an MFA method is verified.

  ## Examples

      iex> {:ok, method} = MFAMethod.totp("SECRET")
      iex> MFAMethod.verified?(method)
      false

      iex> verified_method = MFAMethod.verify(method)
      iex> MFAMethod.verified?(verified_method)
      true
  """
  def verified?(%__MODULE__{verified: verified}), do: verified

  @doc """
  Returns a safe representation of the MFA method for display.
  Masks sensitive information.

  ## Examples

      iex> {:ok, method} = MFAMethod.sms("+1234567890")
      iex> MFAMethod.safe_display(method)
      %{type: :sms, identifier: "+***7890", verified: false}
  """
  def safe_display(%__MODULE__{type: :totp} = method) do
    %{
      type: method.type,
      identifier: "[TOTP Configured]",
      verified: method.verified
    }
  end

  def safe_display(%__MODULE__{type: :sms, identifier: phone} = method) do
    %{
      type: method.type,
      identifier: mask_phone(phone),
      verified: method.verified
    }
  end

  def safe_display(%__MODULE__{type: :email, identifier: email} = method) do
    %{
      type: method.type,
      identifier: mask_email(email),
      verified: method.verified
    }
  end

  def safe_display(%__MODULE__{type: :webauthn} = method) do
    %{
      type: method.type,
      identifier: "[Security Key]",
      verified: method.verified
    }
  end

  # Private functions

  defp validate(type, identifier) do
    cond do
      identifier == "" -> {:error, :invalid_identifier}
      type == :totp and not valid_totp_secret?(identifier) -> {:error, :invalid_totp_secret}
      type == :sms -> validate_phone_number(identifier)
      type == :email -> validate_email(identifier)
      type == :webauthn and String.length(identifier) < 10 -> {:error, :invalid_webauthn_credential}
      true -> :ok
    end
  end

  defp valid_totp_secret?(secret) do
    # TOTP secrets are typically Base32 encoded strings
    String.match?(secret, ~r/^[A-Z2-7]+=*$/) and String.length(secret) >= 16
  end

  defp validate_phone_number(phone) do
    # Basic E.164 format validation
    if String.match?(phone, ~r/^\+[1-9]\d{1,14}$/) do
      :ok
    else
      {:error, :invalid_phone_number}
    end
  end

  defp validate_email(email) do
    if String.match?(email, ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/) do
      :ok
    else
      {:error, :invalid_email}
    end
  end

  defp mask_phone(phone) do
    case String.length(phone) do
      len when len > 4 ->
        last_4 = String.slice(phone, -4, 4)
        "+***#{last_4}"

      _ ->
        "***"
    end
  end

  defp mask_email(email) do
    case String.split(email, "@") do
      [local, domain] ->
        masked_local =
          case String.length(local) do
            len when len > 2 ->
              first = String.first(local)
              last = String.last(local)
              "#{first}***#{last}"

            _ ->
              "***"
          end

        "#{masked_local}@#{domain}"

      _ ->
        "***"
    end
  end
end

# Implement String.Chars protocol
defimpl String.Chars, for: Thalamus.Domain.ValueObjects.MFAMethod do
  def to_string(%Thalamus.Domain.ValueObjects.MFAMethod{type: type}) do
    "MFA:#{type}"
  end
end

# Implement Jason.Encoder - use safe display
defimpl Jason.Encoder, for: Thalamus.Domain.ValueObjects.MFAMethod do
  def encode(%Thalamus.Domain.ValueObjects.MFAMethod{} = method, opts) do
    Thalamus.Domain.ValueObjects.MFAMethod.safe_display(method)
    |> Jason.Encode.map(opts)
  end
end
