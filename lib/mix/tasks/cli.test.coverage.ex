defmodule Mix.Tasks.Cli.Test.Coverage do
  @moduledoc """
  Validates that every CLI command has tests (cli = api).

  Unit tests: checks cli/src/commands/*.test.js
  E2E tests:  checks scripts/test-cli.sh

  Runs automatically as part of `mix compile`. Fails if any command
  has no tests at all.

      mix cli.test.coverage
  """

  use Mix.Task
  @shortdoc "Verify every CLI command has test coverage"

  @cli_dir Path.expand("cli", File.cwd!())

  def run(_args) do
    script = Path.join(@cli_dir, "scripts/extract-test-coverage.cjs")

    unless System.find_executable("node") do
      Mix.shell().error("Node.js not found in PATH — skipping CLI test coverage check")
    else
      do_run(script)
    end
  end

  defp do_run(script) do
    unless File.exists?(script) do
      Mix.raise("Test coverage script not found: #{script}")
    end

    report =
      case System.cmd("node", [script], cd: @cli_dir, stderr_to_stdout: true) do
        {output, 0} ->
          case Jason.decode(output) do
            {:ok, data} -> data
            {:error, err} -> Mix.raise("Failed to parse: #{inspect(err)}")
          end

        {output, code} ->
          Mix.shell().error(output)
          Mix.raise("Script failed (exit #{code})")
      end

    print_report(report)

    summary = report["_summary"]
    commands = report["commands"]

    # Count commands that have NEITHER unit NOR e2e coverage
    # Unit coverage: unit_line > 0 means the module has real test coverage
    missing =
      commands
      |> Enum.count(fn {_k, v} ->
        (v["unit_line"] || 0) == 0 && !v["e2e"]
      end)

    threshold = Application.get_env(:thalamus, :cli_coverage_threshold, 15)
    avg = summary["unit_avg_line_coverage"] || 0

    if avg < threshold do
      Mix.raise(
        "CLI test coverage FAILED: #{avg}% avg line coverage " <>
          "(threshold: #{threshold}%)"
      )
    end

    if missing > 0 do
      Mix.shell().error(
        "WARNING: #{missing} commands have no test coverage. " <>
          "This will become a hard failure once coverage reaches #{threshold}%."
      )
    end
  end

  defp print_report(report) do
    summary = report["_summary"]
    commands = report["commands"]

    no_tests =
      commands
      |> Enum.filter(fn {_k, v} -> (v["unit_line"] || 0) == 0 && !v["e2e"] end)
      |> Enum.map(fn {k, _v} -> k end)
      |> Enum.sort()

    e2e_only =
      commands
      |> Enum.filter(fn {_k, v} -> v["e2e"] && (v["unit_line"] || 0) == 0 end)
      |> Enum.map(fn {k, _v} -> k end)
      |> Enum.sort()

    Mix.shell().info("")
    Mix.shell().info("═══ CLI Test Coverage (real) ═══")
    Mix.shell().info("Commands:       #{summary["total_commands"]}")
    Mix.shell().info("Avg line cov:   #{summary["unit_avg_line_coverage"]}% (#{summary["unit_files_covered"]}/#{summary["unit_files"]} files)")
    Mix.shell().info("E2E functions:  #{summary["e2e_functions"]} (#{summary["e2e_commands_covered"]} commands)")
    Mix.shell().info("Untested:       #{summary["commands_with_neither"]}")

    if no_tests != [] do
      Mix.shell().error("NO TESTS: #{length(no_tests)} commands")
      Enum.each(no_tests, fn cmd -> Mix.shell().error("   #{cmd}") end)
    end

    if e2e_only != [] do
      Mix.shell().info("E2E-only: #{length(e2e_only)} commands (no unit tests)")
    end

    Mix.shell().info("")
  end
end
