# Email Configuration Guide

Thalamus uses Swoosh for email delivery. You can configure different email providers for different environments.

## Development

In development, emails are captured locally and can be viewed at:
- http://localhost:4000/dev/mailbox

No configuration needed - works out of the box.

## Production

### Option 1: SendGrid (Recommended)

1. Sign up at https://sendgrid.com
2. Get your API key
3. Set environment variables:

```bash
export SMTP_RELAY="smtp.sendgrid.net"
export SMTP_USERNAME="apikey"
export SMTP_PASSWORD="your-sendgrid-api-key"
export SMTP_PORT="587"
export SMTP_TLS="always"
export SMTP_AUTH="always"
export FROM_EMAIL="noreply@yourdomain.com"
export FROM_NAME="Your App Name"
```

### Option 2: Mailgun

1. Sign up at https://mailgun.com
2. Get your SMTP credentials
3. Set environment variables:

```bash
export SMTP_RELAY="smtp.mailgun.org"
export SMTP_USERNAME="postmaster@your-domain.mailgun.org"
export SMTP_PASSWORD="your-smtp-password"
export SMTP_PORT="587"
export SMTP_TLS="always"
export SMTP_AUTH="always"
export FROM_EMAIL="noreply@yourdomain.com"
export FROM_NAME="Your App Name"
```

### Option 3: AWS SES

1. Set up SES in AWS Console
2. Get SMTP credentials
3. Set environment variables:

```bash
export SMTP_RELAY="email-smtp.us-east-1.amazonaws.com"  # Your SES region
export SMTP_USERNAME="your-ses-smtp-username"
export SMTP_PASSWORD="your-ses-smtp-password"
export SMTP_PORT="587"
export SMTP_TLS="always"
export SMTP_AUTH="always"
export FROM_EMAIL="noreply@yourdomain.com"  # Must be verified in SES
export FROM_NAME="Your App Name"
```

### Option 4: Custom SMTP Server

```bash
export SMTP_RELAY="smtp.yourserver.com"
export SMTP_USERNAME="your-username"
export SMTP_PASSWORD="your-password"
export SMTP_PORT="587"  # or 465 for SSL
export SMTP_TLS="always"  # or "never" or "if_available"
export SMTP_AUTH="always"  # or "if_available"
export FROM_EMAIL="noreply@yourdomain.com"
export FROM_NAME="Your App Name"
```

## Email Templates

Thalamus includes the following email templates:

### 1. Email Verification
Sent when a new user registers.
- Subject: "Verify your email address"
- Contains verification link
- Expires in 24 hours

### 2. Password Reset
Sent when user requests password reset.
- Subject: "Reset your password"
- Contains reset link
- Expires in 1 hour

### 3. Welcome Email
Sent after email verification.
- Subject: "Welcome to Thalamus!"
- Contains getting started information

## Customization

To customize email templates, edit:
```
lib/thalamus/emails/user_email.ex
```

You can change:
- Email subject lines
- HTML templates
- Text fallbacks
- From address (via environment variables)
- Brand colors and styling

## Testing

### Test in Development

```bash
# Start server
mix phx.server

# Visit mailbox to see captured emails
open http://localhost:4000/dev/mailbox

# Trigger test email (in IEx)
iex> alias Thalamus.Emails.UserEmail
iex> user = %{email: "test@example.com", full_name: "Test User"}
iex> UserEmail.email_verification(user, "test-token") |> Thalamus.Mailer.deliver()
```

### Test in Production

Use a tool like Mailtrap or similar to test without sending to real users:

```bash
export SMTP_RELAY="smtp.mailtrap.io"
export SMTP_USERNAME="your-mailtrap-username"
export SMTP_PASSWORD="your-mailtrap-password"
export SMTP_PORT="2525"
```

## Troubleshooting

### Emails not sending

1. Check environment variables are set
2. Verify SMTP credentials are correct
3. Check firewall allows outbound connections on SMTP port
4. Review logs for error messages

### Emails going to spam

1. Set up SPF record for your domain
2. Set up DKIM signing (provided by email provider)
3. Set up DMARC policy
4. Use a verified sender email address

### Rate limits

Most email providers have rate limits:
- SendGrid: Up to 100 emails/day (free), more with paid plan
- Mailgun: Up to 100 emails/day (free), more with paid plan
- AWS SES: 200 emails/day initially, request limit increase

## Security Best Practices

1. **Never commit SMTP credentials to git**
2. Use environment variables for all sensitive data
3. Rotate SMTP passwords regularly
4. Monitor email sending for abuse
5. Implement rate limiting for email endpoints
6. Use TLS/SSL for SMTP connections (always)

## Support

For email delivery issues:
- SendGrid: https://support.sendgrid.com
- Mailgun: https://help.mailgun.com
- AWS SES: https://aws.amazon.com/ses/faqs/
