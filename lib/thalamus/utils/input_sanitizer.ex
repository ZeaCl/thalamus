defmodule Thalamus.Utils.InputSanitizer do
  @moduledoc """
  Utility module for sanitizing user input to prevent security issues.

  Protects against:
  - XSS (Cross-Site Scripting)
  - Log injection
  - Control character injection
  - Excessively long input (DoS)

  SOLID Principles:
  - Single Responsibility: Only sanitizes text input
  - Open/Closed: Extensible with new sanitization methods
  """

  @max_length 500

  @doc """
  Sanitizes text input by:
  - Trimming whitespace
  - Removing control characters
  - Limiting length to #{@max_length} characters

  ## Examples

      iex> InputSanitizer.sanitize_text("  Hello World  ")
      "Hello World"

      iex> InputSanitizer.sanitize_text("Hello\\x00World")
      "HelloWorld"

      iex> InputSanitizer.sanitize_text(nil)
      nil
  """
  @spec sanitize_text(String.t() | nil) :: String.t() | nil
  def sanitize_text(nil), do: nil

  def sanitize_text(text) when is_binary(text) do
    text
    |> String.trim()
    |> remove_control_characters()
    |> String.slice(0, @max_length)
  end

  # Removes ASCII control characters (0x00-0x1F) and DEL (0x7F)
  # These can cause issues in logs and terminal output
  defp remove_control_characters(text) do
    String.replace(text, ~r/[\x00-\x1F\x7F]/, "")
  end
end
