defmodule Thalamus.Mailer do
  @moduledoc """
  Email delivery using Swoosh.

  Supports multiple adapters:
  - SMTP (SendGrid, Mailgun, AWS SES, etc.)
  - Local (dev/test)
  - Mailbox (dev UI preview)
  """

  use Swoosh.Mailer, otp_app: :thalamus
end
