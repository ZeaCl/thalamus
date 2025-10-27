defmodule Thalamus.Domain.Entities.UserTest do
  use ExUnit.Case, async: true

  alias Thalamus.Domain.Entities.User
  alias Thalamus.Domain.ValueObjects.{UserId, Email, PasswordHash, MFAMethod}

  describe "new/1" do
    test "creates valid user with required fields" do
      {:ok, user_id} = UserId.generate()
      {:ok, email} = Email.new("user@example.com")
      {:ok, password_hash} = PasswordHash.from_password("SecureP@ssw0rd1")

      assert {:ok, %User{} = user} =
               User.new(%{
                 id: user_id,
                 email: email,
                 password_hash: password_hash
               })

      assert user.id == user_id
      assert user.email == email
      assert user.password_hash == password_hash
      assert user.status == :pending_verification
      assert user.mfa_methods == []
      assert user.failed_login_attempts == 0
      assert is_nil(user.locked_until)
      assert is_nil(user.verified_at)
      assert is_nil(user.last_login_at)
      assert %DateTime{} = user.created_at
      assert %DateTime{} = user.updated_at
    end

    test "accepts optional fields" do
      {:ok, user_id} = UserId.generate()
      {:ok, email} = Email.new("user@example.com")
      {:ok, password_hash} = PasswordHash.from_password("SecureP@ssw0rd1")
      {:ok, mfa_method} = MFAMethod.totp("JBSWY3DPEHPK3PXP")
      now = DateTime.utc_now()

      assert {:ok, user} =
               User.new(%{
                 id: user_id,
                 email: email,
                 password_hash: password_hash,
                 mfa_methods: [mfa_method],
                 status: :active,
                 verified_at: now
               })

      assert user.mfa_methods == [mfa_method]
      assert user.status == :active
      assert user.verified_at == now
    end

    test "fails with missing required fields" do
      assert {:error, :missing_required_fields} = User.new(%{})
    end

    test "fails with missing user_id" do
      {:ok, email} = Email.new("user@example.com")
      {:ok, password_hash} = PasswordHash.from_password("SecureP@ssw0rd1")

      assert {:error, :missing_user_id} =
               User.new(%{
                 email: email,
                 password_hash: password_hash
               })
    end

    test "fails with missing email" do
      {:ok, user_id} = UserId.generate()
      {:ok, password_hash} = PasswordHash.from_password("SecureP@ssw0rd1")

      assert {:error, :missing_email} =
               User.new(%{
                 id: user_id,
                 password_hash: password_hash
               })
    end

    test "fails with missing password_hash" do
      {:ok, user_id} = UserId.generate()
      {:ok, email} = Email.new("user@example.com")

      assert {:error, :missing_password_hash} =
               User.new(%{
                 id: user_id,
                 email: email
               })
    end

    test "fails with invalid status" do
      {:ok, user_id} = UserId.generate()
      {:ok, email} = Email.new("user@example.com")
      {:ok, password_hash} = PasswordHash.from_password("SecureP@ssw0rd1")

      assert {:error, :invalid_status} =
               User.new(%{
                 id: user_id,
                 email: email,
                 password_hash: password_hash,
                 status: :invalid_status
               })
    end
  end

  describe "register/2" do
    test "creates new user from email and password strings" do
      assert {:ok, %User{} = user} = User.register("user@example.com", "SecureP@ssw0rd1")

      assert %UserId{} = user.id
      assert %Email{} = user.email
      assert %PasswordHash{} = user.password_hash
      assert user.status == :pending_verification
    end

    test "fails with invalid email" do
      assert {:error, :invalid_email} = User.register("not-an-email", "SecureP@ssw0rd1")
    end

    test "fails with weak password" do
      assert {:error, :password_too_short} = User.register("user@example.com", "weak")
    end

    test "fails with non-string inputs" do
      assert {:error, :invalid_registration_data} = User.register(nil, nil)
      assert {:error, :invalid_registration_data} = User.register(123, 456)
    end
  end

  describe "verify_email/1" do
    test "verifies pending user and activates account" do
      {:ok, user} = User.register("user@example.com", "SecureP@ssw0rd1")
      assert user.status == :pending_verification
      assert is_nil(user.verified_at)

      assert {:ok, verified_user} = User.verify_email(user)
      assert verified_user.status == :active
      assert %DateTime{} = verified_user.verified_at
    end

    test "fails if already verified" do
      {:ok, user} = User.register("user@example.com", "SecureP@ssw0rd1")
      {:ok, verified_user} = User.verify_email(user)

      assert {:error, :already_verified} = User.verify_email(verified_user)
    end
  end

  describe "verify_password/2" do
    test "successfully verifies correct password" do
      password = "CorrectP@ssw0rd1"
      {:ok, user} = User.register("user@example.com", password)

      assert :ok = User.verify_password(user, password)
    end

    test "fails with incorrect password" do
      {:ok, user} = User.register("user@example.com", "CorrectP@ssw0rd1")

      assert {:error, :invalid_password} = User.verify_password(user, "WrongPassword1!")
    end

    test "fails with empty password" do
      {:ok, user} = User.register("user@example.com", "CorrectP@ssw0rd1")

      assert {:error, :invalid_password} = User.verify_password(user, "")
    end

    test "fails with nil password" do
      {:ok, user} = User.register("user@example.com", "CorrectP@ssw0rd1")

      assert {:error, :invalid_password} = User.verify_password(user, nil)
    end
  end

  describe "change_password/3" do
    test "successfully changes password with correct current password" do
      current_password = "OldP@ssw0rd1"
      new_password = "NewP@ssw0rd1"
      {:ok, user} = User.register("user@example.com", current_password)

      assert {:ok, updated_user} = User.change_password(user, current_password, new_password)
      assert :ok = User.verify_password(updated_user, new_password)
      assert {:error, :invalid_password} = User.verify_password(updated_user, current_password)
    end

    test "fails with incorrect current password" do
      {:ok, user} = User.register("user@example.com", "CorrectP@ssw0rd1")

      assert {:error, :invalid_current_password} =
               User.change_password(user, "WrongPassword1!", "NewP@ssw0rd1")
    end

    test "fails with weak new password" do
      current_password = "CorrectP@ssw0rd1"
      {:ok, user} = User.register("user@example.com", current_password)

      assert {:error, :password_too_short} =
               User.change_password(user, current_password, "weak")
    end
  end

  describe "record_failed_login/1" do
    test "increments failed login attempts" do
      {:ok, user} = User.register("user@example.com", "SecureP@ssw0rd1")
      assert user.failed_login_attempts == 0

      {:ok, updated_user} = User.record_failed_login(user)
      assert updated_user.failed_login_attempts == 1
    end

    test "locks account after max failed attempts" do
      {:ok, user} = User.register("user@example.com", "SecureP@ssw0rd1")

      # Record 5 failed attempts
      user = Enum.reduce(1..5, user, fn _, acc ->
        {:ok, updated} = User.record_failed_login(acc)
        updated
      end)

      assert user.failed_login_attempts == 5
      assert %DateTime{} = user.locked_until
      assert User.account_locked?(user)
    end

    test "locked_until is set 30 minutes in the future" do
      {:ok, user} = User.register("user@example.com", "SecureP@ssw0rd1")

      # Record 5 failed attempts to lock
      user = Enum.reduce(1..5, user, fn _, acc ->
        {:ok, updated} = User.record_failed_login(acc)
        updated
      end)

      now = DateTime.utc_now()
      expected_unlock = DateTime.add(now, 30 * 60)

      # Account should be locked until approximately 30 minutes from now
      # Allow 10 second tolerance for test execution time
      assert DateTime.diff(user.locked_until, expected_unlock) < 10
    end
  end

  describe "record_successful_login/1" do
    test "resets failed login attempts and updates last login" do
      {:ok, user} = User.register("user@example.com", "SecureP@ssw0rd1")
      {:ok, user} = User.verify_email(user)

      # Simulate some failed attempts
      user = Enum.reduce(1..3, user, fn _, acc ->
        {:ok, updated} = User.record_failed_login(acc)
        updated
      end)

      assert user.failed_login_attempts == 3

      {:ok, updated_user} = User.record_successful_login(user)
      assert updated_user.failed_login_attempts == 0
      assert %DateTime{} = updated_user.last_login_at
      assert is_nil(updated_user.locked_until)
    end

    test "fails if account is locked" do
      {:ok, user} = User.register("user@example.com", "SecureP@ssw0rd1")
      {:ok, user} = User.verify_email(user)

      # Lock the account
      user = Enum.reduce(1..5, user, fn _, acc ->
        {:ok, updated} = User.record_failed_login(acc)
        updated
      end)

      assert {:error, :account_locked} = User.record_successful_login(user)
    end
  end

  describe "account_locked?/1" do
    test "returns false when locked_until is nil" do
      {:ok, user} = User.register("user@example.com", "SecureP@ssw0rd1")
      assert User.account_locked?(user) == false
    end

    test "returns true when locked_until is in the future" do
      {:ok, user} = User.register("user@example.com", "SecureP@ssw0rd1")
      locked_user = %{user | locked_until: DateTime.add(DateTime.utc_now(), 3600)}

      assert User.account_locked?(locked_user) == true
    end

    test "returns false when locked_until is in the past" do
      {:ok, user} = User.register("user@example.com", "SecureP@ssw0rd1")
      locked_user = %{user | locked_until: DateTime.add(DateTime.utc_now(), -3600)}

      assert User.account_locked?(locked_user) == false
    end
  end

  describe "add_mfa_method/2" do
    test "adds MFA method to user" do
      {:ok, user} = User.register("user@example.com", "SecureP@ssw0rd1")
      {:ok, mfa_method} = MFAMethod.totp("JBSWY3DPEHPK3PXP")

      assert {:ok, updated_user} = User.add_mfa_method(user, mfa_method)
      assert length(updated_user.mfa_methods) == 1
      assert hd(updated_user.mfa_methods) == mfa_method
    end

    test "allows multiple different MFA methods" do
      {:ok, user} = User.register("user@example.com", "SecureP@ssw0rd1")
      {:ok, totp} = MFAMethod.totp("JBSWY3DPEHPK3PXP")
      {:ok, sms} = MFAMethod.sms("+1234567890")

      {:ok, user} = User.add_mfa_method(user, totp)
      {:ok, user} = User.add_mfa_method(user, sms)

      assert length(user.mfa_methods) == 2
    end

    test "fails when adding duplicate MFA method" do
      {:ok, user} = User.register("user@example.com", "SecureP@ssw0rd1")
      {:ok, mfa_method} = MFAMethod.totp("JBSWY3DPEHPK3PXP")

      {:ok, user} = User.add_mfa_method(user, mfa_method)

      assert {:error, :mfa_method_already_exists} = User.add_mfa_method(user, mfa_method)
    end

    test "fails with invalid MFA method" do
      {:ok, user} = User.register("user@example.com", "SecureP@ssw0rd1")

      assert {:error, :invalid_mfa_method} = User.add_mfa_method(user, "not an mfa method")
    end
  end

  describe "remove_mfa_method/3" do
    test "removes MFA method from user" do
      {:ok, user} = User.register("user@example.com", "SecureP@ssw0rd1")
      {:ok, mfa_method} = MFAMethod.totp("JBSWY3DPEHPK3PXP")
      {:ok, user} = User.add_mfa_method(user, mfa_method)

      assert {:ok, updated_user} = User.remove_mfa_method(user, :totp, "JBSWY3DPEHPK3PXP")
      assert updated_user.mfa_methods == []
    end

    test "only removes matching MFA method" do
      {:ok, user} = User.register("user@example.com", "SecureP@ssw0rd1")
      {:ok, totp} = MFAMethod.totp("JBSWY3DPEHPK3PXP")
      {:ok, sms} = MFAMethod.sms("+1234567890")

      {:ok, user} = User.add_mfa_method(user, totp)
      {:ok, user} = User.add_mfa_method(user, sms)

      {:ok, user} = User.remove_mfa_method(user, :totp, "JBSWY3DPEHPK3PXP")

      assert length(user.mfa_methods) == 1
      assert hd(user.mfa_methods).type == :sms
    end

    test "fails when MFA method not found" do
      {:ok, user} = User.register("user@example.com", "SecureP@ssw0rd1")

      assert {:error, :mfa_method_not_found} =
               User.remove_mfa_method(user, :totp, "NONEXISTENT")
    end
  end

  describe "mfa_enabled?/1" do
    test "returns false when no MFA methods" do
      {:ok, user} = User.register("user@example.com", "SecureP@ssw0rd1")
      assert User.mfa_enabled?(user) == false
    end

    test "returns false when MFA methods exist but none verified" do
      {:ok, user} = User.register("user@example.com", "SecureP@ssw0rd1")
      {:ok, mfa_method} = MFAMethod.totp("JBSWY3DPEHPK3PXP")
      {:ok, user} = User.add_mfa_method(user, mfa_method)

      assert User.mfa_enabled?(user) == false
    end

    test "returns true when at least one MFA method is verified" do
      {:ok, user} = User.register("user@example.com", "SecureP@ssw0rd1")
      {:ok, mfa_method} = MFAMethod.totp("JBSWY3DPEHPK3PXP")
      verified_method = MFAMethod.verify(mfa_method)
      {:ok, user} = User.add_mfa_method(user, verified_method)

      assert User.mfa_enabled?(user) == true
    end
  end

  describe "can_authenticate?/1" do
    test "returns true for active unlocked user" do
      {:ok, user} = User.register("user@example.com", "SecureP@ssw0rd1")
      {:ok, user} = User.verify_email(user)

      assert User.can_authenticate?(user) == true
    end

    test "returns false for suspended user" do
      {:ok, user} = User.register("user@example.com", "SecureP@ssw0rd1")
      {:ok, user} = User.verify_email(user)
      {:ok, user} = User.suspend(user)

      assert User.can_authenticate?(user) == false
    end

    test "returns false for locked user" do
      {:ok, user} = User.register("user@example.com", "SecureP@ssw0rd1")
      {:ok, user} = User.verify_email(user)

      # Lock the account
      user = Enum.reduce(1..5, user, fn _, acc ->
        {:ok, updated} = User.record_failed_login(acc)
        updated
      end)

      assert User.can_authenticate?(user) == false
    end

    test "returns false for pending verification" do
      {:ok, user} = User.register("user@example.com", "SecureP@ssw0rd1")
      assert user.status == :pending_verification

      assert User.can_authenticate?(user) == false
    end
  end

  describe "suspend/1" do
    test "suspends active user" do
      {:ok, user} = User.register("user@example.com", "SecureP@ssw0rd1")
      {:ok, user} = User.verify_email(user)

      assert {:ok, suspended_user} = User.suspend(user)
      assert suspended_user.status == :suspended
    end
  end

  describe "reactivate/1" do
    test "reactivates suspended user" do
      {:ok, user} = User.register("user@example.com", "SecureP@ssw0rd1")
      {:ok, user} = User.verify_email(user)
      {:ok, user} = User.suspend(user)

      assert {:ok, reactivated_user} = User.reactivate(user)
      assert reactivated_user.status == :active
    end

    test "fails when user is already active" do
      {:ok, user} = User.register("user@example.com", "SecureP@ssw0rd1")
      {:ok, user} = User.verify_email(user)

      assert {:error, :already_active} = User.reactivate(user)
    end

    test "fails when user is deactivated" do
      {:ok, user} = User.register("user@example.com", "SecureP@ssw0rd1")
      {:ok, user} = User.deactivate(user)

      assert {:error, :cannot_reactivate} = User.reactivate(user)
    end
  end

  describe "deactivate/1" do
    test "deactivates user" do
      {:ok, user} = User.register("user@example.com", "SecureP@ssw0rd1")

      assert {:ok, deactivated_user} = User.deactivate(user)
      assert deactivated_user.status == :deactivated
    end
  end

  describe "protocols" do
    test "implements String.Chars protocol" do
      {:ok, user} = User.register("user@example.com", "SecureP@ssw0rd1")
      result = to_string(user)

      assert String.contains?(result, "User<")
      assert String.contains?(result, "user@example.com")
    end

    test "implements Jason.Encoder protocol with safe serialization" do
      {:ok, user} = User.register("user@example.com", "SecureP@ssw0rd1")
      json = Jason.encode!(user)

      # Should include safe fields
      assert String.contains?(json, "user@example.com")
      assert String.contains?(json, "pending_verification")

      # Should NOT include sensitive fields
      refute String.contains?(json, "password_hash")
      refute String.contains?(json, "$2b$")
    end
  end
end
