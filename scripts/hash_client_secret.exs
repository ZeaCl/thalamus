#!/usr/bin/env elixir

# Script para hashear un client_secret con Bcrypt
# Uso: mix run scripts/hash_client_secret.exs <secret>
#
# Ejemplo:
#   mix run scripts/hash_client_secret.exs dev_secret_change_in_production

defmodule HashClientSecret do
  def run([secret]) when is_binary(secret) do
    hash = Bcrypt.hash_pwd_salt(secret, rounds: 12)

    IO.puts("\n=== Client Secret Hash Generator ===\n")
    IO.puts("Plain secret: #{secret}")
    IO.puts("Bcrypt hash:  #{hash}")
    IO.puts("\n=== SQL UPDATE Command ===\n")
    IO.puts("UPDATE oauth2_clients")
    IO.puts("SET client_secret = '#{hash}'")
    IO.puts("WHERE client_id_string = '<your_client_id>';")
    IO.puts("\n⚠️  Replace <your_client_id> with the actual client ID\n")
  end

  def run([]) do
    IO.puts("Usage: mix run scripts/hash_client_secret.exs <secret>")
    IO.puts("\nExample:")
    IO.puts("  mix run scripts/hash_client_secret.exs dev_secret_change_in_production")
    System.halt(1)
  end

  def run(_) do
    IO.puts("Error: Too many arguments")
    IO.puts("Usage: mix run scripts/hash_client_secret.exs <secret>")
    System.halt(1)
  end
end

HashClientSecret.run(System.argv())
