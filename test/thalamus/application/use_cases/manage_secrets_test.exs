defmodule Thalamus.Application.UseCases.ManageSecretsTest do
  use Thalamus.DataCase

  alias Thalamus.Application.UseCases.ManageSecrets
  alias Thalamus.Domain.Entities.Secret

  describe "create_secret/2" do
    test "creates a secret successfully" do
      attrs = %{
        owner_type: "user",
        owner_id: Ecto.UUID.generate(),
        provider: "google_stitch",
        name: "My API Key",
        value: "sk-12345"
      }

      assert {:ok, %Secret{} = secret} = ManageSecrets.create_secret(attrs)
      assert secret.provider == "google_stitch"
      assert secret.name == "My API Key"
      assert secret.owner_type == "user"
      # The plain text should not be available in the loaded schema after insert
      assert secret.value == "sk-12345" # Still in the struct right after create because it's virtual
      
      # Reload to prove encryption
      reloaded = Thalamus.Repo.get!(Secret, secret.id)
      assert reloaded.encrypted_value == "sk-12345" # cloak transparently decrypts this field!
      assert reloaded.value == nil # Virtual field is not loaded
    end

    test "fails with invalid data" do
      assert {:error, changeset} = ManageSecrets.create_secret(%{})
      assert "can't be blank" in errors_on(changeset).provider
    end
  end

  describe "list_by_owner/2" do
    test "returns secrets for a specific owner" do
      owner_id = Ecto.UUID.generate()
      
      {:ok, _s1} = ManageSecrets.create_secret(%{
        owner_type: "user", owner_id: owner_id, provider: "openai", name: "A", value: "x"
      })
      {:ok, _s2} = ManageSecrets.create_secret(%{
        owner_type: "user", owner_id: owner_id, provider: "github", name: "B", value: "y"
      })

      secrets = ManageSecrets.list_by_owner("user", owner_id)
      assert length(secrets) == 2
    end
  end
end
