# Standalone test runner for Domain Layer (Value Objects + Entities)
# This allows testing without database setup
#
# Usage: elixir test_domain_entities.exs

# Add lib and test directories to code path
Code.append_path("_build/test/lib/thalamus/ebin")
Code.prepend_path("lib")
Code.prepend_path("test")

# Configure ExUnit
ExUnit.start(auto_run: false)

# Load dependencies
Mix.install([
  {:bcrypt_elixir, "~> 3.0"},
  {:jason, "~> 1.2"},
  {:uuid, "~> 1.1"}
])

# Load domain modules
Code.require_file("lib/thalamus/domain/value_objects/user_id.ex")
Code.require_file("lib/thalamus/domain/value_objects/email.ex")
Code.require_file("lib/thalamus/domain/value_objects/client_id.ex")
Code.require_file("lib/thalamus/domain/value_objects/scope.ex")
Code.require_file("lib/thalamus/domain/value_objects/access_token.ex")
Code.require_file("lib/thalamus/domain/value_objects/authorization_code.ex")
Code.require_file("lib/thalamus/domain/value_objects/redirect_uri.ex")
Code.require_file("lib/thalamus/domain/value_objects/pkce_challenge.ex")
Code.require_file("lib/thalamus/domain/value_objects/password_hash.ex")
Code.require_file("lib/thalamus/domain/value_objects/mfa_method.ex")

# Load entity modules
Code.require_file("lib/thalamus/domain/entities/user.ex")

# Load test files
Code.require_file("test/thalamus/domain/value_objects/user_id_test.exs")
Code.require_file("test/thalamus/domain/value_objects/email_test.exs")
Code.require_file("test/thalamus/domain/value_objects/client_id_test.exs")
Code.require_file("test/thalamus/domain/value_objects/scope_test.exs")
Code.require_file("test/thalamus/domain/value_objects/access_token_test.exs")
Code.require_file("test/thalamus/domain/value_objects/authorization_code_test.exs")
Code.require_file("test/thalamus/domain/value_objects/redirect_uri_test.exs")
Code.require_file("test/thalamus/domain/value_objects/pkce_challenge_test.exs")
Code.require_file("test/thalamus/domain/value_objects/password_hash_test.exs")
Code.require_file("test/thalamus/domain/value_objects/mfa_method_test.exs")
Code.require_file("test/thalamus/domain/entities/user_test.exs")

# Run all tests
ExUnit.run()
