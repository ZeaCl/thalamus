defmodule Mix.Tasks.Cli.Test.E2e do
  @moduledoc """
  Full E2E test suite with ephemeral Docker PostgreSQL.

  Starts PostgreSQL, migrates, seeds, starts Thalamus (subprocess),
  runs scripts/test-cli.sh, and destroys everything.

      mix cli.test.e2e

  Integrated into precommit. Skips gracefully if Docker is unavailable.
  """

  use Mix.Task
  @shortdoc "Full E2E tests (Docker + Thalamus + test-cli.sh)"

  @db_port 5433
  @db_name "thalamus_e2e"
  @db_user "postgres"
  @db_pass "test"
  @container_name "thalamus-e2e-db"
  @app_port 4101

  def run(args) do
    if "--cleanup" in args do
      cleanup()
    else
      run_e2e()
    end
  end

  defp run_e2e do
    unless docker_available?() do
      Mix.shell().info("[cli.test.e2e] Docker not available — skipping E2E tests")
      return_ok()
    end

    Mix.shell().info("═══ CLI E2E Tests ═══")

    started = false

    try do
      start_postgres!()
      setup_database!()
      _server_pid = start_thalamus_subprocess!()
      _started = true
      wait_for_healthy!()

      script = Path.expand("scripts/test-cli.sh", File.cwd!())
      env = [{"THALAMUS_API_URL", "http://localhost:#{@app_port}"}]

      Mix.shell().info("Running E2E tests...")
      Mix.shell().info("")

      {_output, exit_code} =
        System.cmd("bash", [script], env: env, into: IO.stream(:stdio, :line))

      Mix.shell().info("")

      if exit_code != 0 do
        Mix.raise("E2E tests FAILED (exit #{exit_code})")
      else
        Mix.shell().info("All E2E tests passed ✅")
      end
    after
      if started do
        stop_thalamus_subprocess()
      end

      cleanup_docker()
    end
  end

  # ── Docker ─────────────────────────────────────────────────────

  defp docker_available? do
    System.find_executable("docker") != nil &&
      match?({_output, 0}, System.cmd("docker", ["ps"], stderr_to_stdout: true))
  end

  defp start_postgres! do
    Mix.shell().info("Starting PostgreSQL...")
    System.cmd("docker", ["rm", "-f", @container_name], stderr_to_stdout: true)

    {_output, 0} =
      System.cmd(
        "docker",
        [
          "run",
          "-d",
          "--rm",
          "--name",
          @container_name,
          "-e",
          "POSTGRES_PASSWORD=#{@db_pass}",
          "-p",
          "#{@db_port}:5432",
          "postgres:16-alpine"
        ],
        stderr_to_stdout: true
      )

    unless wait_for_pg(30) do
      Mix.raise("PostgreSQL did not become ready")
    end

    Mix.shell().info("  PostgreSQL ready ✅")
  end

  defp wait_for_pg(0), do: false

  defp wait_for_pg(retries) do
    case System.cmd("pg_isready", ["-h", "localhost", "-p", "#{@db_port}", "-U", @db_user],
           stderr_to_stdout: true
         ) do
      {output, 0} ->
        String.contains?(output, "accepting")

      _ ->
        :timer.sleep(1000)
        wait_for_pg(retries - 1)
    end
  end

  defp cleanup_docker do
    Mix.shell().info("Stopping PostgreSQL...")
    System.cmd("docker", ["stop", @container_name], stderr_to_stdout: true)
    Mix.shell().info("  Container removed ✅")
  end

  # ── Database ───────────────────────────────────────────────────

  defp setup_database! do
    Mix.shell().info("Setting up database...")
    db_url = db_url()
    env = [{"DATABASE_URL", db_url}, {"MIX_ENV", "test"}]

    {_, 0} = System.cmd("mix", ["ecto.create", "--quiet"], env: env, stderr_to_stdout: true)
    {_, 0} = System.cmd("mix", ["ecto.migrate", "--quiet"], env: env, stderr_to_stdout: true)
    {_, 0} = System.cmd("mix", ["run", "priv/repo/seeds.exs"], env: env, stderr_to_stdout: true)
    Mix.shell().info("  Database ready ✅")
  end

  defp db_url do
    "ecto://#{@db_user}:#{@db_pass}@localhost:#{@db_port}/#{@db_name}"
  end

  # ── Thalamus subprocess ────────────────────────────────────────

  defp start_thalamus_subprocess! do
    Mix.shell().info("Starting Thalamus on port #{@app_port}...")

    # Precompile in current VM so subprocess doesn't recompile
    Mix.Task.run("compile")

    db_url = db_url()

    env = [
      {"DATABASE_URL", db_url},
      {"MIX_ENV", "test"},
      {"PORT", "#{@app_port}"},
      {"PHX_HOST", "localhost"},
      {"SECRET_KEY_BASE", String.duplicate("a", 64)}
    ]

    # Start phx.server in background via Task.async
    # Precompile above means this starts in ~5s instead of ~30s
    task =
      Task.async(fn ->
        System.cmd("mix", ["phx.server"], env: env, stderr_to_stdout: true)
      end)

    Process.put(:e2e_server_task, task)
    Mix.shell().info("  Waiting for server (precompiled, ~10s)...")
    task
  end

  defp stop_thalamus_subprocess do
    task = Process.get(:e2e_server_task)

    if task && Process.alive?(task.pid) do
      Task.shutdown(task, :brutal_kill)
    end

    # Kill any remaining beam on the E2E port
    System.cmd("lsof", ["-ti", ":#{@app_port}"])
    |> elem(0)
    |> String.trim()
    |> String.split("\n", trim: true)
    |> Enum.each(&System.cmd("kill", [&1]))
  end

  defp wait_for_healthy! do
    unless wait_for_http(60) do
      Mix.raise("Thalamus did not become healthy after 60s")
    end

    Mix.shell().info("  Server healthy ✅")
  end

  defp wait_for_http(0), do: false

  defp wait_for_http(retries) do
    url = "http://localhost:#{@app_port}/api/public/health"

    case System.cmd("curl", ["-s", "-o", "/dev/null", "-w", "%{http_code}", url]) do
      {"200", 0} ->
        true

      _ ->
        :timer.sleep(2000)
        wait_for_http(retries - 1)
    end
  end

  # ── Cleanup ────────────────────────────────────────────────────

  defp cleanup do
    stop_thalamus_subprocess()
    cleanup_docker()
  end

  defp return_ok do
    # No-op: just return without raising
  end
end
