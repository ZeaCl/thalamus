defmodule Thalamus.Domain.Services.PersonalAccessTokenGeneratorTest do
  use ExUnit.Case, async: false

  alias Thalamus.Domain.Services.PersonalAccessTokenGenerator

  describe "generate/1" do
    test "generates PAT with dev environment by default" do
      %{token: token, token_prefix: token_prefix, token_hash: token_hash} =
        PersonalAccessTokenGenerator.generate()

      assert is_binary(token)
      assert String.starts_with?(token, "th_pat_dev_")
      assert String.length(token) >= 50

      assert is_binary(token_prefix)
      assert String.starts_with?(token_prefix, "th_pat_dev_")
      assert String.length(token_prefix) == 16

      assert is_binary(token_hash)
      assert String.starts_with?(token_hash, "$2b$")
    end

    test "generates PAT with live environment" do
      %{token: token, token_prefix: token_prefix} =
        PersonalAccessTokenGenerator.generate(:prod)

      assert String.starts_with?(token, "th_pat_live_")
      assert String.starts_with?(token_prefix, "th_pat_live_")
      assert String.length(token_prefix) == 16
    end

    test "generates unique PATs on each call" do
      %{token: token1} = PersonalAccessTokenGenerator.generate()
      %{token: token2} = PersonalAccessTokenGenerator.generate()

      assert token1 != token2
    end
  end

  describe "verify_token/2" do
    test "returns true for matching token and hash" do
      token = "th_pat_dev_vK8mN2pQ7xR9tY3wZ5aB1cD4eF6gH8jL"
      hash = PersonalAccessTokenGenerator.hash_token(token)

      assert PersonalAccessTokenGenerator.verify_token(token, hash) == true
    end

    test "returns false for non-matching token and hash" do
      token = "th_pat_dev_vK8mN2pQ7xR9tY3wZ5aB1cD4eF6gH8jL"
      wrong_token = "th_pat_dev_wrongtoken987654321"
      hash = PersonalAccessTokenGenerator.hash_token(token)

      assert PersonalAccessTokenGenerator.verify_token(wrong_token, hash) == false
    end
  end

  describe "extract_prefix/1" do
    test "extracts prefix from valid dev token" do
      token = "th_pat_dev_vK8mN2pQ7xR9tY3wZ5aB1cD4eF6gH8jL"
      assert {:ok, prefix} = PersonalAccessTokenGenerator.extract_prefix(token)
      assert prefix == "th_pat_dev_vK8mN"
    end
  end

  describe "valid_format?/1" do
    test "returns true for valid dev token" do
      assert PersonalAccessTokenGenerator.valid_format?(
               "th_pat_dev_vK8mN2pQ7xR9tY3wZ5aB1cD4eF6gH8jL"
             ) == true
    end

    test "returns false for too short token" do
      assert PersonalAccessTokenGenerator.valid_format?("th_pat_dev_abc") == false
    end
  end
end
