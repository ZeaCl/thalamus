defmodule Thalamus.Application.UseCases.ResolveAgentSecretTest do
  use Thalamus.DataCase

  alias Thalamus.Application.UseCases.ResolveAgentSecret
  alias Thalamus.Application.UseCases.ManageSecrets

  describe "execute/5" do
    test "prefers organization secret by default if both exist" do
      org_id = Ecto.UUID.generate()
      user_id = Ecto.UUID.generate()

      {:ok, _} = ManageSecrets.create_secret(%{owner_type: "organization", owner_id: org_id, provider: "stitch", name: "Org Key", value: "org-123"})
      {:ok, _} = ManageSecrets.create_secret(%{owner_type: "user", owner_id: user_id, provider: "stitch", name: "User Key", value: "user-123"})

      assert {:ok, secret} = ResolveAgentSecret.execute("stitch", org_id, user_id)
      assert secret.encrypted_value == "org-123"
      assert secret.owner_type == "organization"
    end

    test "prefers user secret if prefer_user is true" do
      org_id = Ecto.UUID.generate()
      user_id = Ecto.UUID.generate()

      {:ok, _} = ManageSecrets.create_secret(%{owner_type: "organization", owner_id: org_id, provider: "stitch", name: "Org Key", value: "org-123"})
      {:ok, _} = ManageSecrets.create_secret(%{owner_type: "user", owner_id: user_id, provider: "stitch", name: "User Key", value: "user-123"})

      assert {:ok, secret} = ResolveAgentSecret.execute("stitch", org_id, user_id, prefer_user: true)
      assert secret.encrypted_value == "user-123"
      assert secret.owner_type == "user"
    end

    test "falls back to user if org doesn't have it (default behavior)" do
      org_id = Ecto.UUID.generate()
      user_id = Ecto.UUID.generate()

      {:ok, _} = ManageSecrets.create_secret(%{owner_type: "user", owner_id: user_id, provider: "stitch", name: "User Key", value: "user-123"})

      assert {:ok, secret} = ResolveAgentSecret.execute("stitch", org_id, user_id)
      assert secret.encrypted_value == "user-123"
      assert secret.owner_type == "user"
    end

    test "returns error if neither has it" do
      org_id = Ecto.UUID.generate()
      user_id = Ecto.UUID.generate()

      assert {:error, :not_found} = ResolveAgentSecret.execute("stitch", org_id, user_id)
    end
  end
end
