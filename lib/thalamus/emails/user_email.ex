defmodule Thalamus.Emails.UserEmail do
  @moduledoc """
  User-related email templates.
  """

  import Swoosh.Email

  @doc """
  Email verification email.
  """
  def email_verification(user, token) do
    verification_url = "#{base_url()}/verify-email?token=#{token}"

    new()
    |> to({user.full_name || user.email, user.email})
    |> from({from_name(), from_email()})
    |> subject("Verify your email address")
    |> html_body("""
    <html>
      <body style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 40px; text-align: center;">
          <h1 style="color: white; margin: 0;">Verify Your Email</h1>
        </div>
        <div style="padding: 40px; background: #f7fafc;">
          <p style="font-size: 16px; color: #2d3748;">Hi #{user.full_name || "there"},</p>
          <p style="font-size: 16px; color: #2d3748;">
            Thanks for signing up for Thalamus! Please verify your email address by clicking the button below:
          </p>
          <div style="text-align: center; margin: 30px 0;">
            <a href="#{verification_url}" style="background: #667eea; color: white; padding: 12px 30px; text-decoration: none; border-radius: 5px; display: inline-block;">
              Verify Email Address
            </a>
          </div>
          <p style="font-size: 14px; color: #718096;">
            Or copy and paste this URL into your browser:<br>
            <a href="#{verification_url}" style="color: #667eea;">#{verification_url}</a>
          </p>
          <p style="font-size: 14px; color: #718096; margin-top: 30px;">
            This link will expire in 24 hours.
          </p>
        </div>
        <div style="background: #2d3748; padding: 20px; text-align: center; color: #a0aec0; font-size: 12px;">
          <p>Thalamus OAuth2 Server | Enterprise Authentication</p>
        </div>
      </body>
    </html>
    """)
    |> text_body("""
    Hi #{user.full_name || "there"},

    Thanks for signing up for Thalamus! Please verify your email address by visiting:

    #{verification_url}

    This link will expire in 24 hours.

    ---
    Thalamus OAuth2 Server
    """)
  end

  @doc """
  Password reset email.
  """
  def password_reset(user, token) do
    reset_url = "#{base_url()}/reset-password?token=#{token}"

    new()
    |> to({user.full_name || user.email, user.email})
    |> from({from_name(), from_email()})
    |> subject("Reset your password")
    |> html_body("""
    <html>
      <body style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <div style="background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%); padding: 40px; text-align: center;">
          <h1 style="color: white; margin: 0;">Reset Your Password</h1>
        </div>
        <div style="padding: 40px; background: #f7fafc;">
          <p style="font-size: 16px; color: #2d3748;">Hi #{user.full_name || "there"},</p>
          <p style="font-size: 16px; color: #2d3748;">
            We received a request to reset your password. Click the button below to set a new password:
          </p>
          <div style="text-align: center; margin: 30px 0;">
            <a href="#{reset_url}" style="background: #f5576c; color: white; padding: 12px 30px; text-decoration: none; border-radius: 5px; display: inline-block;">
              Reset Password
            </a>
          </div>
          <p style="font-size: 14px; color: #718096;">
            Or copy and paste this URL into your browser:<br>
            <a href="#{reset_url}" style="color: #f5576c;">#{reset_url}</a>
          </p>
          <p style="font-size: 14px; color: #718096; margin-top: 30px;">
            This link will expire in 1 hour.
          </p>
          <p style="font-size: 14px; color: #e53e3e;">
            <strong>Important:</strong> If you didn't request this password reset, please ignore this email.
          </p>
        </div>
        <div style="background: #2d3748; padding: 20px; text-align: center; color: #a0aec0; font-size: 12px;">
          <p>Thalamus OAuth2 Server | Enterprise Authentication</p>
        </div>
      </body>
    </html>
    """)
    |> text_body("""
    Hi #{user.full_name || "there"},

    We received a request to reset your password. Visit this link to set a new password:

    #{reset_url}

    This link will expire in 1 hour.

    If you didn't request this password reset, please ignore this email.

    ---
    Thalamus OAuth2 Server
    """)
  end

  @doc """
  Welcome email after successful registration.
  """
  def welcome(user) do
    new()
    |> to({user.full_name || user.email, user.email})
    |> from({from_name(), from_email()})
    |> subject("Welcome to Thalamus!")
    |> html_body("""
    <html>
      <body style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 40px; text-align: center;">
          <h1 style="color: white; margin: 0;">Welcome to Thalamus!</h1>
        </div>
        <div style="padding: 40px; background: #f7fafc;">
          <p style="font-size: 16px; color: #2d3748;">Hi #{user.full_name || "there"},</p>
          <p style="font-size: 16px; color: #2d3748;">
            Your account has been verified! You're all set to start using Thalamus OAuth2.
          </p>
          <div style="text-align: center; margin: 30px 0;">
            <a href="#{base_url()}/dashboard" style="background: #667eea; color: white; padding: 12px 30px; text-decoration: none; border-radius: 5px; display: inline-block;">
              Go to Dashboard
            </a>
          </div>
          <p style="font-size: 14px; color: #718096;">
            Need help? Check out our documentation or contact support.
          </p>
        </div>
        <div style="background: #2d3748; padding: 20px; text-align: center; color: #a0aec0; font-size: 12px;">
          <p>Thalamus OAuth2 Server | Enterprise Authentication</p>
        </div>
      </body>
    </html>
    """)
    |> text_body("""
    Hi #{user.full_name || "there"},

    Your account has been verified! You're all set to start using Thalamus OAuth2.

    Visit your dashboard: #{base_url()}/dashboard

    Need help? Check out our documentation or contact support.

    ---
    Thalamus OAuth2 Server
    """)
  end

  defp base_url do
    Application.get_env(:thalamus, :base_url, "http://localhost:4000")
  end

  defp from_email do
    Application.get_env(:thalamus, :from_email, "noreply@localhost")
  end

  defp from_name do
    Application.get_env(:thalamus, :from_name, "Thalamus OAuth2")
  end
end
