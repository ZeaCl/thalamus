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
    missing = summary["total_commands"] - summary["unit_covered"] - summary["e2e_covered"]

    if missing > 0 do
      Mix.raise(
        "CLI test coverage FAILED: #{missing} commands have no tests " <>
          "(#{summary["unit_covered"]} unit, #{summary["e2e_covered"]} e2e, " <>
          "#{summary["total_commands"]} total)"
      )
    end
  end

  defp print_report(report) do
    summary = report["_summary"]
    commands = report["commands"]

    no_tests =
      commands
      |> Enum.filter(fn {_k, v} -> !v["unit"] && !v["e2e"] end)
      |> Enum.map(fn {k, _v} -> k end)
      |> Enum.sort()

    e2e_only =
      commands
      |> Enum.filter(fn {_k, v} -> v["e2e"] && !v["unit"] end)
      |> Enum.map(fn {k, _v} -> k end)
      |> Enum.sort()

    Mix.shell().info("")
    Mix.shell().info("═══ CLI Test Coverage ═══")
    Mix.shell().info("Commands:     #{summary["total_commands"]}")
    Mix.shell().info("Unit tests:   #{summary["unit_covered"]} (#{summary["unit_test_files"]} files)")
    Mix.shell().info("E2E tests:    #{summary["e2e_covered"]} (#{summary["e2e_test_functions"]} functions)")
    Mix.shell().info("Contracts:    #{summary["contract_fixtures"] || 0} fixtures")

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
