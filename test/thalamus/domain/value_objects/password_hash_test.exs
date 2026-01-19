defmodule Thalamus.Domain.ValueObjects.PasswordHashTest do
  use ExUnit.Case, async: true

  alias Thalamus.Domain.ValueObjects.PasswordHash

  describe "from_password/1" do
    test "creates valid password hash with secure password" do
      assert {:ok, %PasswordHash{hash: hash}} = PasswordHash.from_password("SecureP@ssw0rd1")
      assert is_binary(hash)
      assert String.starts_with?(hash, "$2b$")
    end

    test "fails with empty password" do
      assert {:error, :password_too_short} = PasswordHash.from_password("")
    end

    test "fails with password too short" do
      assert {:error, :password_too_short} = PasswordHash.from_password("Short1!")
    end

    test "fails with password too long" do
      long_password = String.duplicate("A", 129) <> "a1!"
      assert {:error, :password_too_long} = PasswordHash.from_password(long_password)
    end

    test "fails with password missing uppercase" do
      assert {:error, :password_missing_uppercase} =
               PasswordHash.from_password("lowercase123!")
    end

    test "fails with password missing lowercase" do
      assert {:error, :password_missing_lowercase} =
               PasswordHash.from_password("UPPERCASE123!")
    end

    test "fails with password missing digit" do
      assert {:error, :password_missing_digit} = PasswordHash.from_password("NoDigitsHere!")
    end

    test "fails with password missing special character" do
      assert {:error, :password_missing_special_char} =
               PasswordHash.from_password("NoSpecial123")
    end

    test "fails with nil password" do
      assert {:error, :invalid_password} = PasswordHash.from_password(nil)
    end

    test "fails with non-string password" do
      assert {:error, :invalid_password} = PasswordHash.from_password(12345)
    end
  end

  describe "from_hash/1" do
    test "creates password hash from valid bcrypt hash" do
      valid_hash = "$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5GyYKKvVXqYC6"
      assert {:ok, %PasswordHash{hash: ^valid_hash}} = PasswordHash.from_hash(valid_hash)
    end

    test "accepts different bcrypt versions" do
      hash_2a = "$2a$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5GyYKKvVXqYC6"
      hash_2b = "$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5GyYKKvVXqYC6"
      hash_2y = "$2y$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5GyYKKvVXqYC6"

      assert {:ok, %PasswordHash{}} = PasswordHash.from_hash(hash_2a)
      assert {:ok, %PasswordHash{}} = PasswordHash.from_hash(hash_2b)
      assert {:ok, %PasswordHash{}} = PasswordHash.from_hash(hash_2y)
    end

    test "fails with empty hash" do
      assert {:error, :invalid_hash} = PasswordHash.from_hash("")
    end

    test "fails with invalid hash format" do
      assert {:error, :invalid_hash_format} = PasswordHash.from_hash("not_a_valid_hash")
    end

    test "fails with nil hash" do
      assert {:error, :invalid_hash} = PasswordHash.from_hash(nil)
    end
  end

  describe "verify/2" do
    test "successfully verifies correct password" do
      password = "CorrectP@ssw0rd1"
      {:ok, password_hash} = PasswordHash.from_password(password)

      assert :ok = PasswordHash.verify(password_hash, password)
    end

    test "fails to verify incorrect password" do
      {:ok, password_hash} = PasswordHash.from_password("CorrectP@ssw0rd1")

      assert {:error, :invalid_password} = PasswordHash.verify(password_hash, "WrongPassword1!")
    end

    test "fails with empty password" do
      {:ok, password_hash} = PasswordHash.from_password("CorrectP@ssw0rd1")

      assert {:error, :invalid_password} = PasswordHash.verify(password_hash, "")
    end

    test "fails with nil password" do
      {:ok, password_hash} = PasswordHash.from_password("CorrectP@ssw0rd1")

      assert {:error, :invalid_password} = PasswordHash.verify(password_hash, nil)
    end

    test "fails with non-string password" do
      {:ok, password_hash} = PasswordHash.from_password("CorrectP@ssw0rd1")

      assert {:error, :invalid_password} = PasswordHash.verify(password_hash, 12345)
    end
  end

  describe "to_string/1" do
    test "returns hash string" do
      {:ok, password_hash} = PasswordHash.from_password("TestP@ssw0rd1")
      hash_string = PasswordHash.to_string(password_hash)

      assert is_binary(hash_string)
      assert String.starts_with?(hash_string, "$2b$")
    end
  end

  describe "protocols" do
    test "implements String.Chars protocol" do
      {:ok, password_hash} = PasswordHash.from_password("TestP@ssw0rd1")
      result = to_string(password_hash)

      assert is_binary(result)
      assert String.starts_with?(result, "$2b$")
    end

    test "implements Jason.Encoder protocol with redaction" do
      {:ok, password_hash} = PasswordHash.from_password("TestP@ssw0rd1")
      json = Jason.encode!(password_hash)

      # Should be redacted in JSON
      assert json == ~s("[REDACTED]")
      refute String.contains?(json, "$2b$")
    end
  end

  describe "security properties" do
    test "different hashes for same password" do
      password = "SameP@ssw0rd1"
      {:ok, hash1} = PasswordHash.from_password(password)
      {:ok, hash2} = PasswordHash.from_password(password)

      # Bcrypt uses salt, so hashes should be different
      assert hash1.hash != hash2.hash
      # But both should verify the same password
      assert :ok = PasswordHash.verify(hash1, password)
      assert :ok = PasswordHash.verify(hash2, password)
    end

    test "password complexity requirements enforced" do
      # Missing each requirement
      assert {:error, _} = PasswordHash.from_password("alllowercase123!")
      assert {:error, _} = PasswordHash.from_password("ALLUPPERCASE123!")
      assert {:error, _} = PasswordHash.from_password("NoNumbers!")
      assert {:error, _} = PasswordHash.from_password("NoSpecialChars123")
      assert {:error, _} = PasswordHash.from_password("Short1!")

      # All requirements met
      assert {:ok, _} = PasswordHash.from_password("ValidP@ssw0rd123")
    end
  end
end
