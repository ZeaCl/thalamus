defmodule Thalamus.Domain.Services.AdminApiKeyGeneratorTest do
  use ExUnit.Case, async: false

  alias Thalamus.Domain.Services.AdminApiKeyGenerator

  describe "generate/1" do
    test "generates API key with dev environment by default" do
      %{api_key: api_key, key_prefix: key_prefix, key_hash: key_hash} =
        AdminApiKeyGenerator.generate()

      assert is_binary(api_key)
      assert String.starts_with?(api_key, "ak_dev_")
      assert String.length(api_key) >= 50

      assert is_binary(key_prefix)
      assert String.starts_with?(key_prefix, "ak_dev_")
      assert String.length(key_prefix) == 13

      assert is_binary(key_hash)
      assert String.starts_with?(key_hash, "$2b$")
    end

    test "generates API key with live environment" do
      %{api_key: api_key, key_prefix: key_prefix, key_hash: key_hash} =
        AdminApiKeyGenerator.generate(:prod)

      assert String.starts_with?(api_key, "ak_live_")
      assert String.starts_with?(key_prefix, "ak_live_")
      assert String.length(key_prefix) == 13
      assert String.starts_with?(key_hash, "$2b$")
    end

    test "generates API key with test environment" do
      %{api_key: api_key, key_prefix: key_prefix} = AdminApiKeyGenerator.generate(:test)

      assert String.starts_with?(api_key, "ak_dev_")
      assert String.starts_with?(key_prefix, "ak_dev_")
    end

    test "generates unique API keys on each call" do
      %{api_key: key1} = AdminApiKeyGenerator.generate()
      %{api_key: key2} = AdminApiKeyGenerator.generate()
      %{api_key: key3} = AdminApiKeyGenerator.generate()

      assert key1 != key2
      assert key2 != key3
      assert key1 != key3
    end

    test "key prefix is first 13 characters of API key" do
      %{api_key: api_key, key_prefix: key_prefix} = AdminApiKeyGenerator.generate()

      assert key_prefix == String.slice(api_key, 0, 13)
    end
  end

  describe "hash_key/1" do
    test "generates bcrypt hash for API key" do
      api_key = "ak_dev_testkey123456789"

      hash = AdminApiKeyGenerator.hash_key(api_key)

      assert is_binary(hash)
      assert String.starts_with?(hash, "$2b$")
      assert String.length(hash) == 60
    end

    test "generates different hashes for different keys" do
      hash1 = AdminApiKeyGenerator.hash_key("ak_dev_key1")
      hash2 = AdminApiKeyGenerator.hash_key("ak_dev_key2")

      assert hash1 != hash2
    end

    test "generates consistent hash for same key (same rounds)" do
      api_key = "ak_dev_testkey"

      # Note: Bcrypt includes a salt, so hashes will be different each time
      # We verify by checking verification instead
      hash1 = AdminApiKeyGenerator.hash_key(api_key)
      hash2 = AdminApiKeyGenerator.hash_key(api_key)

      assert Bcrypt.verify_pass(api_key, hash1)
      assert Bcrypt.verify_pass(api_key, hash2)
    end
  end

  describe "verify_key/2" do
    test "returns true for matching key and hash" do
      api_key = "ak_dev_testkey123456789"
      hash = AdminApiKeyGenerator.hash_key(api_key)

      assert AdminApiKeyGenerator.verify_key(api_key, hash) == true
    end

    test "returns false for non-matching key and hash" do
      api_key = "ak_dev_testkey123456789"
      wrong_key = "ak_dev_wrongkey987654321"
      hash = AdminApiKeyGenerator.hash_key(api_key)

      assert AdminApiKeyGenerator.verify_key(wrong_key, hash) == false
    end

    test "returns false for invalid hash format" do
      api_key = "ak_dev_testkey123456789"
      invalid_hash = "invalid_hash"

      assert AdminApiKeyGenerator.verify_key(api_key, invalid_hash) == false
    end
  end

  describe "extract_prefix/1" do
    test "extracts prefix from valid API key" do
      api_key = "ak_dev_vK8mN2pQ7xR9tY3wZ5aB1cD4eF6gH8jL"

      prefix = AdminApiKeyGenerator.extract_prefix(api_key)

      assert prefix == "ak_dev_vK8mN2"
    end

    test "extracts prefix from live API key" do
      api_key = "ak_live_zX1yW2vU3tS4rQ5pO6nM7lK8jI9hG0fE"

      prefix = AdminApiKeyGenerator.extract_prefix(api_key)

      assert prefix == "ak_live_zX1yW"
    end

    test "handles short API keys gracefully" do
      short_key = "ak_dev_abc"

      prefix = AdminApiKeyGenerator.extract_prefix(short_key)

      # Should return error for keys shorter than 13 chars
      assert prefix == {:error, :invalid_key_length}
    end
  end

  describe "valid_format?/1" do
    test "returns true for valid dev API key" do
      assert AdminApiKeyGenerator.valid_format?("ak_dev_vK8mN2pQ7xR9tY3wZ5aB1cD4eF6gH8jL") == true
    end

    test "returns true for valid live API key" do
      assert AdminApiKeyGenerator.valid_format?("ak_live_zX1yW2vU3tS4rQ5pO6nM7lK8jI9hG0fE") ==
               true
    end

    test "returns false for invalid prefix" do
      assert AdminApiKeyGenerator.valid_format?("invalid_vK8mN2pQ7xR9tY3wZ5aB1cD4eF6gH8jL") ==
               false
    end

    test "returns false for missing prefix" do
      assert AdminApiKeyGenerator.valid_format?("vK8mN2pQ7xR9tY3wZ5aB1cD4eF6gH8jL") == false
    end

    test "returns false for too short key" do
      assert AdminApiKeyGenerator.valid_format?("ak_dev_abc") == false
    end

    test "returns false for nil" do
      assert AdminApiKeyGenerator.valid_format?(nil) == false
    end

    test "returns false for non-string" do
      assert AdminApiKeyGenerator.valid_format?(12345) == false
    end
  end
end
