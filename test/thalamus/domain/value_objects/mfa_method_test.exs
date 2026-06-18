defmodule Thalamus.Domain.ValueObjects.MFAMethodTest do
  use ExUnit.Case, async: false

  alias Thalamus.Domain.ValueObjects.MFAMethod

  describe "new/3" do
    test "creates valid TOTP MFA method" do
      secret = "JBSWY3DPEHPK3PXP"

      assert {:ok, %MFAMethod{type: :totp, identifier: ^secret, verified: false}} =
               MFAMethod.new(:totp, secret, false)
    end

    test "creates valid SMS MFA method" do
      phone = "+1234567890"

      assert {:ok, %MFAMethod{type: :sms, identifier: ^phone}} =
               MFAMethod.new(:sms, phone, false)
    end

    test "creates valid email MFA method" do
      email = "user@example.com"

      assert {:ok, %MFAMethod{type: :email, identifier: ^email}} =
               MFAMethod.new(:email, email, false)
    end

    test "creates valid WebAuthn MFA method" do
      credential = "credential_id_base64_encoded_string"

      assert {:ok, %MFAMethod{type: :webauthn, identifier: ^credential}} =
               MFAMethod.new(:webauthn, credential, false)
    end

    test "sets created_at timestamp" do
      {:ok, method} = MFAMethod.new(:totp, "JBSWY3DPEHPK3PXP", false)
      assert %DateTime{} = method.created_at
    end

    test "fails with invalid MFA type" do
      assert {:error, :invalid_mfa_type} = MFAMethod.new(:invalid_type, "test", false)
    end

    test "fails with empty identifier" do
      assert {:error, :invalid_identifier} = MFAMethod.new(:totp, "", false)
    end

    test "fails with non-binary identifier" do
      assert {:error, :invalid_mfa_method} = MFAMethod.new(:totp, 12345, false)
    end
  end

  describe "totp/1" do
    test "creates TOTP method with valid secret" do
      secret = "JBSWY3DPEHPK3PXPJBSWY3DP"

      assert {:ok, %MFAMethod{type: :totp, identifier: ^secret, verified: false}} =
               MFAMethod.totp(secret)
    end

    test "fails with short TOTP secret" do
      assert {:error, :invalid_totp_secret} = MFAMethod.totp("SHORT")
    end

    test "fails with invalid TOTP secret format" do
      assert {:error, :invalid_totp_secret} = MFAMethod.totp("invalid-secret-format")
    end

    test "fails with empty TOTP secret" do
      assert {:error, :invalid_totp_secret} = MFAMethod.totp("")
    end

    test "fails with nil TOTP secret" do
      assert {:error, :invalid_totp_secret} = MFAMethod.totp(nil)
    end
  end

  describe "sms/1" do
    test "creates SMS method with valid E.164 phone number" do
      phone = "+1234567890"
      assert {:ok, %MFAMethod{type: :sms, identifier: ^phone}} = MFAMethod.sms(phone)
    end

    test "accepts various country codes" do
      assert {:ok, _} = MFAMethod.sms("+1234567890")
      # US/Canada
      assert {:ok, _} = MFAMethod.sms("+447911123456")
      # UK
      assert {:ok, _} = MFAMethod.sms("+861234567890")
      # China
    end

    test "fails with invalid phone format" do
      assert {:error, :invalid_phone_number} = MFAMethod.sms("1234567890")
      # Missing +
      assert {:error, :invalid_phone_number} = MFAMethod.sms("+0234567890")
      # Starts with 0
      assert {:error, :invalid_phone_number} = MFAMethod.sms("not-a-phone")
    end

    test "fails with empty phone" do
      assert {:error, :invalid_phone_number} = MFAMethod.sms("")
    end

    test "fails with nil phone" do
      assert {:error, :invalid_phone_number} = MFAMethod.sms(nil)
    end
  end

  describe "email/1" do
    test "creates email method with valid email" do
      email = "user@example.com"
      assert {:ok, %MFAMethod{type: :email, identifier: ^email}} = MFAMethod.email(email)
    end

    test "accepts various email formats" do
      assert {:ok, _} = MFAMethod.email("user@example.com")
      assert {:ok, _} = MFAMethod.email("user.name@example.com")
      assert {:ok, _} = MFAMethod.email("user+tag@example.co.uk")
    end

    test "fails with invalid email format" do
      assert {:error, :invalid_email} = MFAMethod.email("not-an-email")
      assert {:error, :invalid_email} = MFAMethod.email("@example.com")
      assert {:error, :invalid_email} = MFAMethod.email("user@")
      assert {:error, :invalid_email} = MFAMethod.email("user @example.com")
    end

    test "fails with empty email" do
      assert {:error, :invalid_email} = MFAMethod.email("")
    end

    test "fails with nil email" do
      assert {:error, :invalid_email} = MFAMethod.email(nil)
    end
  end

  describe "webauthn/1" do
    test "creates WebAuthn method with valid credential ID" do
      credential = "base64_encoded_credential_id_string"

      assert {:ok, %MFAMethod{type: :webauthn, identifier: ^credential}} =
               MFAMethod.webauthn(credential)
    end

    test "fails with empty credential ID" do
      assert {:error, :invalid_webauthn_credential} = MFAMethod.webauthn("")
    end

    test "fails with nil credential ID" do
      assert {:error, :invalid_webauthn_credential} = MFAMethod.webauthn(nil)
    end
  end

  describe "verify/1" do
    test "marks MFA method as verified" do
      {:ok, method} = MFAMethod.totp("JBSWY3DPEHPK3PXP")
      assert method.verified == false

      verified_method = MFAMethod.verify(method)
      assert verified_method.verified == true
    end

    test "returns updated method struct" do
      {:ok, method} = MFAMethod.sms("+1234567890")
      verified_method = MFAMethod.verify(method)

      assert %MFAMethod{} = verified_method
      assert verified_method.type == method.type
      assert verified_method.identifier == method.identifier
    end
  end

  describe "verified?/1" do
    test "returns false for unverified method" do
      {:ok, method} = MFAMethod.totp("JBSWY3DPEHPK3PXP")
      assert MFAMethod.verified?(method) == false
    end

    test "returns true for verified method" do
      {:ok, method} = MFAMethod.totp("JBSWY3DPEHPK3PXP")
      verified_method = MFAMethod.verify(method)
      assert MFAMethod.verified?(verified_method) == true
    end
  end

  describe "safe_display/1" do
    test "masks TOTP secret" do
      {:ok, method} = MFAMethod.totp("JBSWY3DPEHPK3PXP")
      display = MFAMethod.safe_display(method)

      assert display.type == :totp
      assert display.identifier == "[TOTP Configured]"
      refute String.contains?(display.identifier, "JBSWY")
    end

    test "masks phone number showing only last 4 digits" do
      {:ok, method} = MFAMethod.sms("+1234567890")
      display = MFAMethod.safe_display(method)

      assert display.type == :sms
      assert display.identifier == "+***7890"
    end

    test "masks email showing first and last character of local part" do
      {:ok, method} = MFAMethod.email("user@example.com")
      display = MFAMethod.safe_display(method)

      assert display.type == :email
      assert display.identifier == "u***r@example.com"
    end

    test "masks WebAuthn credential" do
      {:ok, method} = MFAMethod.webauthn("credential_id_base64")
      display = MFAMethod.safe_display(method)

      assert display.type == :webauthn
      assert display.identifier == "[Security Key]"
    end

    test "includes verification status in display" do
      {:ok, method} = MFAMethod.totp("JBSWY3DPEHPK3PXP")
      unverified_display = MFAMethod.safe_display(method)
      assert unverified_display.verified == false

      verified_method = MFAMethod.verify(method)
      verified_display = MFAMethod.safe_display(verified_method)
      assert verified_display.verified == true
    end
  end

  describe "protocols" do
    test "implements String.Chars protocol" do
      {:ok, method} = MFAMethod.totp("JBSWY3DPEHPK3PXP")
      result = to_string(method)

      assert result == "MFA:totp"
    end

    test "implements Jason.Encoder protocol with safe display" do
      {:ok, method} = MFAMethod.sms("+1234567890")
      json = Jason.encode!(method)

      # Should use safe display, not expose full phone
      assert String.contains?(json, "sms")
      assert String.contains?(json, "+***7890")
      refute String.contains?(json, "+1234567890")
    end
  end

  describe "security properties" do
    test "never exposes sensitive identifiers in string representation" do
      {:ok, totp} = MFAMethod.totp("JBSWY3DPEHPK3PXP")
      {:ok, sms} = MFAMethod.sms("+1234567890")
      {:ok, email} = MFAMethod.email("user@example.com")

      # String protocol should not expose secrets
      refute String.contains?(to_string(totp), "JBSWY")
      refute String.contains?(to_string(sms), "1234567890")
      refute String.contains?(to_string(email), "user")
    end

    test "safe display consistently masks sensitive data" do
      {:ok, method} = MFAMethod.sms("+1234567890")

      # Multiple calls should produce same masked output
      display1 = MFAMethod.safe_display(method)
      display2 = MFAMethod.safe_display(method)

      assert display1 == display2
    end
  end
end
