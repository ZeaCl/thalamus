ExUnit.start()

# Only setup database for integration tests, not unit tests
if System.get_env("SKIP_DB_SETUP") != "true" do
  try do
    Ecto.Adapters.SQL.Sandbox.mode(Thalamus.Repo, :manual)
  rescue
    _ ->
      IO.puts("Database not available - skipping database setup for unit tests")
  end
end
