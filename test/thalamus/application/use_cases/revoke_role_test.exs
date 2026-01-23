defmodule Thalamus.Application.UseCases.RevokeRoleTest do
  use ExUnit.Case, async: true
  import Mox

  alias Thalamus.Application.UseCases.RevokeRole

  setup :verify_on_exit!

  @deps %{
    role_repository: Thalamus.MockRoleRepository,
    cache_service: Thalamus.MockCacheService,
    audit_logger: Thalamus.MockAuditLogger
  }

  describe "execute/2" do
    test "successfully revokes role from user" do
      user_id = Ecto.UUID.generate()
      role_id = Ecto.UUID.generate()
      revoked_by = Ecto.UUID.generate()

      Thalamus.MockRoleRepository
      |> expect(:revoke_from_user, fn ^user_id, ^role_id -> :ok end)

      Thalamus.MockCacheService
      |> expect(:delete, fn "user_effective_scopes:" <> ^user_id -> :ok end)

      Thalamus.MockAuditLogger
      |> expect(:log, fn log_entry ->
        assert log_entry.event_type == "role.revoked"
        assert log_entry.actor_id == revoked_by
        assert log_entry.resource_id == "#{user_id}:#{role_id}"
        :ok
      end)

      request = %{user_id: user_id, role_id: role_id, revoked_by: revoked_by}
      assert {:ok, result} = RevokeRole.execute(request, @deps)
      assert result.user_id == user_id
      assert result.role_id == role_id
      assert result.revoked_at != nil
    end

    test "returns error when assignment not found" do
      user_id = Ecto.UUID.generate()
      role_id = Ecto.UUID.generate()

      Thalamus.MockRoleRepository
      |> expect(:revoke_from_user, fn ^user_id, ^role_id ->
        {:error, :assignment_not_found}
      end)

      request = %{user_id: user_id, role_id: role_id, revoked_by: nil}
      assert {:error, :assignment_not_found} = RevokeRole.execute(request, @deps)
    end

    test "invalidates user's effective scopes cache" do
      user_id = Ecto.UUID.generate()
      role_id = Ecto.UUID.generate()

      Thalamus.MockRoleRepository
      |> expect(:revoke_from_user, fn ^user_id, ^role_id -> :ok end)

      Thalamus.MockCacheService
      |> expect(:delete, fn cache_key ->
        assert cache_key == "user_effective_scopes:#{user_id}"
        :ok
      end)

      Thalamus.MockAuditLogger
      |> expect(:log, fn _log_entry -> :ok end)

      request = %{user_id: user_id, role_id: role_id, revoked_by: nil}
      assert {:ok, _} = RevokeRole.execute(request, @deps)
    end
  end
end
