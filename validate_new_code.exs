#!/usr/bin/env elixir

# Validation script for new code (PasswordHash, MFAMethod, User entity)
IO.puts("\n=== Validating New Code ===\n")

# Load dependencies from build
Code.append_path("_build/test/lib/uuid/ebin")
Code.append_path("_build/test/lib/jason/ebin")
Code.append_path("_build/test/lib/bcrypt_elixir/ebin")
Code.append_path("_build/test/lib/comeonin/ebin")
Code.append_path("_build/test/lib/elixir_make/ebin")

# Load all Value Objects
IO.puts("Loading Value Objects...")
Code.require_file("lib/thalamus/domain/value_objects/user_id.ex")
Code.require_file("lib/thalamus/domain/value_objects/email.ex")
Code.require_file("lib/thalamus/domain/value_objects/password_hash.ex")
Code.require_file("lib/thalamus/domain/value_objects/mfa_method.ex")

# Load Entity
IO.puts("Loading Entities...")
Code.require_file("lib/thalamus/domain/entities/user.ex")

# Import modules
alias Thalamus.Domain.ValueObjects.{UserId, Email, PasswordHash, MFAMethod}
alias Thalamus.Domain.Entities.User

IO.puts("\n✓ All modules loaded successfully!\n")

# Test PasswordHash
IO.puts("Testing PasswordHash...")
{:ok, password_hash} = PasswordHash.from_password("SecureP@ssw0rd123")
:ok = PasswordHash.verify(password_hash, "SecureP@ssw0rd123")
{:error, :invalid_password} = PasswordHash.verify(password_hash, "WrongPassword")
IO.puts("  ✓ Password hashing works")
IO.puts("  ✓ Password verification works")

# Test MFAMethod
IO.puts("\nTesting MFAMethod...")
{:ok, totp} = MFAMethod.totp("JBSWY3DPEHPK3PXPJBSWY3DP")
{:ok, sms} = MFAMethod.sms("+1234567890")
{:ok, email_mfa} = MFAMethod.email("user@example.com")
verified_totp = MFAMethod.verify(totp)
unless MFAMethod.verified?(verified_totp), do: raise("MFA verification failed")
IO.puts("  ✓ TOTP MFA works")
IO.puts("  ✓ SMS MFA works")
IO.puts("  ✓ Email MFA works")
IO.puts("  ✓ MFA verification works")

# Test User Entity
IO.puts("\nTesting User Entity...")
{:ok, user} = User.register("test@example.com", "SecureP@ssw0rd123")
unless user.status == :pending_verification, do: raise("User status not pending")
{:ok, verified_user} = User.verify_email(user)
unless verified_user.status == :active, do: raise("User status not active")
:ok = User.verify_password(verified_user, "SecureP@ssw0rd123")
{:ok, user_with_mfa} = User.add_mfa_method(verified_user, verified_totp)
unless User.mfa_enabled?(user_with_mfa), do: raise("MFA not enabled")
IO.puts("  ✓ User registration works")
IO.puts("  ✓ Email verification works")
IO.puts("  ✓ Password verification works")
IO.puts("  ✓ MFA integration works")

# Test failed login tracking
{:ok, user_for_lock} = User.register("lock@example.com", "SecureP@ssw0rd123")
{:ok, user_for_lock} = User.verify_email(user_for_lock)

user_locked =
  Enum.reduce(1..5, user_for_lock, fn _, acc ->
    {:ok, updated} = User.record_failed_login(acc)
    updated
  end)

unless User.account_locked?(user_locked), do: raise("Account not locked")
IO.puts("  ✓ Failed login tracking works")
IO.puts("  ✓ Account locking works")

# Test password change
{:ok, user_pwd} = User.register("pwd@example.com", "OldP@ssw0rd123")
{:ok, changed_user} = User.change_password(user_pwd, "OldP@ssw0rd123", "NewP@ssw0rd123")
:ok = User.verify_password(changed_user, "NewP@ssw0rd123")
{:error, :invalid_password} = User.verify_password(changed_user, "OldP@ssw0rd123")
IO.puts("  ✓ Password change works")

# Test user status management
{:ok, status_user} = User.register("status@example.com", "SecureP@ssw0rd123")
{:ok, status_user} = User.verify_email(status_user)
{:ok, suspended_user} = User.suspend(status_user)
unless suspended_user.status == :suspended, do: raise("User not suspended")
{:ok, reactivated_user} = User.reactivate(suspended_user)
unless reactivated_user.status == :active, do: raise("User not reactivated")
IO.puts("  ✓ User suspension works")
IO.puts("  ✓ User reactivation works")

IO.puts("\n=== All Validations Passed! ===\n")
IO.puts("Summary:")
IO.puts("  • PasswordHash: ✓ Working correctly")
IO.puts("  • MFAMethod: ✓ Working correctly")
IO.puts("  • User Entity: ✓ Working correctly")
IO.puts("  • All business logic: ✓ Implemented correctly")
IO.puts("\n✓ Domain Layer implementation is ready!\n")
