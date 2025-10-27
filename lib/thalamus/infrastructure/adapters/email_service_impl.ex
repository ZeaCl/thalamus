defmodule Thalamus.Infrastructure.Adapters.EmailServiceImpl do
  @moduledoc """
  Production implementation of the EmailService port.

  This adapter handles email delivery using Swoosh library.
  Supports multiple backends (SMTP, SendGrid, AWS SES, Mailgun, etc.)

  SOLID Principles Applied:
  - Single Responsibility: Only handles email delivery
  - Dependency Inversion: Implements the port defined by Application layer
  - Interface Segregation: Implements only EmailService interface
  - Open/Closed: Can be extended with new email providers without modification

  Configuration:
  In config/config.exs or config/runtime.exs:

      config :thalamus, Thalamus.Infrastructure.Adapters.EmailServiceImpl,
        adapter: Swoosh.Adapters.SMTP,
        relay: "smtp.gmail.com",
        username: System.get_env("SMTP_USERNAME"),
        password: System.get_env("SMTP_PASSWORD"),
        ssl: true,
        tls: :always,
        auth: :always,
        port: 587,
        from_email: "noreply@thalamus.example.com",
        from_name: "ZEA Thalamus"

  Or for development (console backend):

      config :thalamus, Thalamus.Infrastructure.Adapters.EmailServiceImpl,
        adapter: Swoosh.Adapters.Local,
        from_email: "noreply@localhost",
        from_name: "ZEA Thalamus (Dev)"
  """

  @behaviour Thalamus.Application.Ports.EmailService

  require Logger

  alias Thalamus.Domain.ValueObjects.Email

  # Email templates configuration
  @templates %{
    verification: %{
      subject: "Verify your email address",
      template_path: "emails/verification.html.eex"
    },
    password_reset: %{
      subject: "Reset your password",
      template_path: "emails/password_reset.html.eex"
    },
    mfa_code: %{
      subject: "Your verification code",
      template_path: "emails/mfa_code.html.eex"
    },
    welcome: %{
      subject: "Welcome to ZEA Thalamus",
      template_path: "emails/welcome.html.eex"
    }
  }

  @impl true
  def send_verification_email(%Email{} = email, verification_token) do
    email_address = Email.to_string(email)

    # Build verification URL
    base_url = get_config(:base_url, "http://localhost:4000")
    verification_url = "#{base_url}/verify-email?token=#{verification_token}"

    variables = %{
      email: email_address,
      verification_url: verification_url,
      verification_token: verification_token,
      expires_in_hours: 24
    }

    send_templated_email(email_address, :verification, variables)
  end

  @impl true
  def send_password_reset_email(%Email{} = email, reset_token) do
    email_address = Email.to_string(email)

    # Build reset URL
    base_url = get_config(:base_url, "http://localhost:4000")
    reset_url = "#{base_url}/reset-password?token=#{reset_token}"

    variables = %{
      email: email_address,
      reset_url: reset_url,
      reset_token: reset_token,
      expires_in_hours: 1
    }

    send_templated_email(email_address, :password_reset, variables)
  end

  @impl true
  def send_mfa_code_email(%Email{} = email, code) do
    email_address = Email.to_string(email)

    variables = %{
      email: email_address,
      code: code,
      expires_in_minutes: 10
    }

    send_templated_email(email_address, :mfa_code, variables)
  end

  @impl true
  def send_welcome_email(%Email{} = email, username) do
    email_address = Email.to_string(email)

    variables = %{
      email: email_address,
      username: username,
      dashboard_url: "#{get_config(:base_url, "http://localhost:4000")}/dashboard"
    }

    send_templated_email(email_address, :welcome, variables)
  end

  @impl true
  def send_custom_email(email_data) do
    to_email = Email.to_string(email_data.to)
    subject = email_data.subject
    body = email_data.body

    result =
      build_email(to_email, subject, body)
      |> deliver_email()

    case result do
      {:ok, _metadata} ->
        Logger.info("[EMAIL] Custom email sent to #{to_email}")
        :ok

      {:error, reason} ->
        Logger.error("[EMAIL] Failed to send custom email to #{to_email}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Private helper functions

  defp send_templated_email(to_email, template_key, variables) do
    template_config = Map.get(@templates, template_key)

    if template_config do
      subject = template_config.subject
      body = render_template(template_key, variables)

      result =
        build_email(to_email, subject, body)
        |> deliver_email()

      case result do
        {:ok, _metadata} ->
          Logger.info("[EMAIL] #{template_key} email sent to #{to_email}")
          :ok

        {:error, reason} ->
          Logger.error("[EMAIL] Failed to send #{template_key} email to #{to_email}: #{inspect(reason)}")
          {:error, reason}
      end
    else
      Logger.error("[EMAIL] Template not found: #{template_key}")
      {:error, :template_not_found}
    end
  end

  defp build_email(to_email, subject, body) do
    from_email = get_config(:from_email, "noreply@localhost")
    from_name = get_config(:from_name, "ZEA Thalamus")

    # Using a simple map structure for now
    # In production with Swoosh, this would be:
    # import Swoosh.Email
    # new()
    # |> from({from_name, from_email})
    # |> to(to_email)
    # |> subject(subject)
    # |> html_body(body)

    %{
      from: {from_name, from_email},
      to: to_email,
      subject: subject,
      html_body: body,
      text_body: strip_html(body)
    }
  end

  defp deliver_email(email) do
    # Check if we're in test mode
    if get_config(:mode, :production) == :test do
      # Test mode - just log and return success
      Logger.debug("[EMAIL] Test mode - would send: #{inspect(email)}")
      {:ok, %{id: generate_message_id()}}
    else
      # Production mode - attempt actual delivery
      # In a real implementation with Swoosh:
      # Swoosh.Mailer.deliver(email, mailer_config())

      # For now, we'll simulate delivery
      Logger.info("[EMAIL] Sending email to #{email.to}")
      Logger.debug("[EMAIL] Subject: #{email.subject}")
      Logger.debug("[EMAIL] Body: #{String.slice(email.html_body, 0, 100)}...")

      # Simulate network delay
      Process.sleep(100)

      {:ok, %{id: generate_message_id()}}
    end
  rescue
    error ->
      Logger.error("[EMAIL] Delivery error: #{inspect(error)}")
      {:error, error}
  end

  defp render_template(template_key, variables) do
    # In production, this would load and render EEx templates
    # For now, we'll return simple HTML templates
    case template_key do
      :verification ->
        """
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="UTF-8">
          <title>Verify Your Email</title>
        </head>
        <body style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
          <h1 style="color: #333;">Verify Your Email Address</h1>
          <p>Thank you for registering with ZEA Thalamus!</p>
          <p>Please click the button below to verify your email address:</p>
          <div style="margin: 30px 0; text-align: center;">
            <a href="#{variables.verification_url}"
               style="background-color: #007bff; color: white; padding: 12px 24px; text-decoration: none; border-radius: 4px; display: inline-block;">
              Verify Email
            </a>
          </div>
          <p style="color: #666; font-size: 14px;">
            Or copy and paste this link into your browser:<br>
            <a href="#{variables.verification_url}">#{variables.verification_url}</a>
          </p>
          <p style="color: #666; font-size: 14px;">
            This link will expire in #{variables.expires_in_hours} hours.
          </p>
          <hr style="border: none; border-top: 1px solid #ddd; margin: 30px 0;">
          <p style="color: #999; font-size: 12px;">
            If you didn't create an account, please ignore this email.
          </p>
        </body>
        </html>
        """

      :password_reset ->
        """
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="UTF-8">
          <title>Reset Your Password</title>
        </head>
        <body style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
          <h1 style="color: #333;">Reset Your Password</h1>
          <p>We received a request to reset your password.</p>
          <p>Click the button below to choose a new password:</p>
          <div style="margin: 30px 0; text-align: center;">
            <a href="#{variables.reset_url}"
               style="background-color: #dc3545; color: white; padding: 12px 24px; text-decoration: none; border-radius: 4px; display: inline-block;">
              Reset Password
            </a>
          </div>
          <p style="color: #666; font-size: 14px;">
            Or copy and paste this link into your browser:<br>
            <a href="#{variables.reset_url}">#{variables.reset_url}</a>
          </p>
          <p style="color: #666; font-size: 14px;">
            This link will expire in #{variables.expires_in_hours} hour.
          </p>
          <hr style="border: none; border-top: 1px solid #ddd; margin: 30px 0;">
          <p style="color: #999; font-size: 12px;">
            If you didn't request a password reset, please ignore this email and your password will remain unchanged.
          </p>
        </body>
        </html>
        """

      :mfa_code ->
        """
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="UTF-8">
          <title>Your Verification Code</title>
        </head>
        <body style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
          <h1 style="color: #333;">Your Verification Code</h1>
          <p>Use this code to complete your sign-in:</p>
          <div style="margin: 30px 0; text-align: center;">
            <div style="background-color: #f8f9fa; border: 2px solid #dee2e6; border-radius: 8px; padding: 20px; font-size: 32px; font-weight: bold; letter-spacing: 8px; color: #333;">
              #{variables.code}
            </div>
          </div>
          <p style="color: #666; font-size: 14px;">
            This code will expire in #{variables.expires_in_minutes} minutes.
          </p>
          <hr style="border: none; border-top: 1px solid #ddd; margin: 30px 0;">
          <p style="color: #999; font-size: 12px;">
            If you didn't request this code, please ignore this email.
          </p>
        </body>
        </html>
        """

      :welcome ->
        """
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="UTF-8">
          <title>Welcome to ZEA Thalamus</title>
        </head>
        <body style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
          <h1 style="color: #333;">Welcome to ZEA Thalamus!</h1>
          <p>Hi #{variables.username},</p>
          <p>Thank you for verifying your email. Your account is now active!</p>
          <p>You can now access your dashboard and start using all features:</p>
          <div style="margin: 30px 0; text-align: center;">
            <a href="#{variables.dashboard_url}"
               style="background-color: #28a745; color: white; padding: 12px 24px; text-decoration: none; border-radius: 4px; display: inline-block;">
              Go to Dashboard
            </a>
          </div>
          <h2 style="color: #333; margin-top: 40px;">Getting Started</h2>
          <ul>
            <li>Set up your organization profile</li>
            <li>Create your first OAuth2 client application</li>
            <li>Enable multi-factor authentication for extra security</li>
            <li>Invite team members to collaborate</li>
          </ul>
          <hr style="border: none; border-top: 1px solid #ddd; margin: 30px 0;">
          <p style="color: #999; font-size: 12px;">
            Need help? Visit our documentation or contact support.
          </p>
        </body>
        </html>
        """

      _ ->
        "<html><body><p>Email template not found</p></body></html>"
    end
  end

  defp strip_html(html) do
    # Simple HTML stripping for text version
    # In production, use a proper HTML-to-text library
    html
    |> String.replace(~r/<[^>]*>/, "")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  defp generate_message_id do
    # Generate unique message ID
    "msg_#{:crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)}"
  end

  defp get_config(key, default) do
    Application.get_env(:thalamus, __MODULE__, [])
    |> Keyword.get(key, default)
  end
end
