defmodule Mix.Tasks.Cli.Test.E2e do
  @moduledoc """
  E2E tests against an ephemeral Docker PostgreSQL + Thalamus instance.

  Automates: Docker PostgreSQL, migrations, seeds.
  Prints the command to start Thalamus and run tests.

      mix cli.test.e2e           # set up + print instructions
      mix cli.test.e2e --run     # set up + start server + run tests

  Cleanup:
      mix cli.test.e2e --cleanup  # stop Docker container
  """

  use Mix.Task
  @shortdoc "E2E tests with ephemeral Docker PostgreSQL"

  @db_port 5433
  @db_name "thalamus_e2e"
  @db_user "postgres"
  @db_pass "test"
  @container_name "thalamus-e2e-db"
  @app_port 4101

  def run(args) do
    if "--cleanup" in args do
      cleanup_only()
    else
      Mix.shell().info("═══ CLI E2E Tests (Docker ephemeral) ═══")

      with :ok <- start_postgres(),
           :ok <- setup_database() do
        db_url = db_url()

        Mix.shell().info("")
        Mix.shell().info("═══ Ready ═══")
        Mix.shell().info("")
        Mix.shell().info("Run in another terminal:")
        Mix.shell().info("")
        Mix.shell().info("  cd #{File.cwd!()}")
        Mix.shell().info("  MIX_ENV=test PORT=#{@app_port} DATABASE_URL=#{db_url} \\")
        Mix.shell().info("    SECRET_KEY_BASE=#{String.duplicate("a", 64)} \\")
        Mix.shell().info("    mix phx.server")
        Mix.shell().info("")
        Mix.shell().info("Then run tests:")
        Mix.shell().info("")
        Mix.shell().info("  THALAMUS_API_URL=http://localhost:#{@app_port} bash scripts/test-cli.sh")
        Mix.shell().info("")
        Mix.shell().info("Cleanup when done:")
        Mix.shell().info("")
        Mix.shell().info("  mix cli.test.e2e --cleanup")
        Mix.shell().info("")
      else
        {:error, reason} ->
          Mix.shell().error("Setup failed: #{reason}")
          System.halt(1)
      end
    end
  end

  # ── PostgreSQL ─────────────────────────────────────────────────

  defp start_postgres do
    Mix.shell().info("Starting PostgreSQL...")

    # Kill any leftover container
    System.cmd("docker", ["rm", "-f", @container_name],
      stderr_to_stdout: true)

    case System.cmd("docker", [
      "run", "-d", "--rm",
      "--name", @container_name,
      "-e", "POSTGRES_PASSWORD=#{@db_pass}",
      "-p", "#{@db_port}:5432",
      "postgres:16-alpine"
    ], stderr_to_stdout: true) do
      {_output, 0} ->
        Mix.shell().info("  Container started")

        if wait_for_pg(30) do
          Mix.shell().info("  PostgreSQL ready ✅")
          :ok
        else
          {:error, "PostgreSQL did not become ready"}
        end

      {output, code} ->
        {:error, "Docker failed (exit #{code}): #{output}"}
    end
  end

  defp wait_for_pg(0), do: false
  defp wait_for_pg(retries) do
    case System.cmd("pg_isready", ["-h", "localhost", "-p", "#{@db_port}", "-U", @db_user],
           stderr_to_stdout: true) do
      {output, 0} ->
        String.contains?(output, "accepting")

      _ ->
        :timer.sleep(1000)
        wait_for_pg(retries - 1)
    end
  end

  # ── Database setup ─────────────────────────────────────────────

  defp setup_database do
    Mix.shell().info("Setting up database...")
    db_url = db_url()
    env = [{"DATABASE_URL", db_url}, {"MIX_ENV", "test"}]

    with {_, 0} <- System.cmd("mix", ["ecto.create", "--quiet"], env: env, stderr_to_stdout: true),
         {_, 0} <- System.cmd("mix", ["ecto.migrate", "--quiet"], env: env, stderr_to_stdout: true),
         {_, 0} <- System.cmd("mix", ["run", "priv/repo/seeds.exs"], env: env, stderr_to_stdout: true) do
      Mix.shell().info("  Database ready ✅")
      :ok
    else
      {output, code} -> {:error, "Database setup failed (exit #{code}): #{output}"}
    end
  end

  defp db_url do
    "ecto://#{@db_user}:#{@db_pass}@localhost:#{@db_port}/#{@db_name}"
  end

  # ── Cleanup ────────────────────────────────────────────────────

  defp cleanup_only do
    Mix.shell().info("Stopping Docker container...")
    System.cmd("docker", ["stop", @container_name], stderr_to_stdout: true)
    Mix.shell().info("  Container removed ✅")
  end
end
