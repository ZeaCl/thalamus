# Thalamus Dashboard - User Guide

**Complete guide to using the Thalamus web interface** | Version 1.0.0

---

## 🎯 Overview

The Thalamus Dashboard provides a web-based interface for managing your OAuth2 clients, API keys, users, organizations, and account settings. This guide covers all features available in the dashboard.

**Dashboard URL:** `http://localhost:4000/dashboard` (development) or `https://your-domain.com/dashboard` (production)

---

## 🔐 Getting Started

### First Login

1. Navigate to the login page: `/login`
2. Enter your email and password
3. Click "Sign In"
4. You'll be redirected to the Dashboard

**Default Admin Credentials (Development):**
- Email: `admin@zea.com`
- Password: Set during initial setup

### Password Requirements

- Minimum 8 characters
- At least one uppercase letter
- At least one lowercase letter
- At least one number
- At least one special character

---

## 📊 Dashboard Home

The dashboard home provides an overview of your Thalamus instance:

- **Active OAuth2 Clients:** Number of registered applications
- **Active Tokens:** Currently valid access tokens
- **Total Users:** Registered user accounts
- **API Keys:** Administrative API keys in use

### Quick Actions

From the dashboard home, you can:
- Create new OAuth2 clients
- Generate API keys
- Manage users and organizations
- View audit logs

---

## 🔑 OAuth2 Clients Management

OAuth2 clients represent applications that can authenticate users through Thalamus.

### Viewing OAuth2 Clients

Navigate to **OAuth2 Clients** from the sidebar to see:
- Client name and ID
- Client type (Confidential/Public)
- Grant types enabled
- Status (Active/Inactive)
- Creation date

**Search & Filter:**
- Search by name or client ID
- Filter by status (All/Active/Inactive)

### Creating a New OAuth2 Client

1. Click **"New Client"** button
2. Fill in the form:

| Field | Description | Required |
|-------|-------------|----------|
| **Name** | Application name (e.g., "Sport App") | ✅ |
| **Organization** | Select from dropdown | ✅ |
| **Client Type** | Confidential (server-side) or Public (mobile/SPA) | ✅ |
| **Redirect URIs** | Callback URLs (one per line) | ✅ |
| **Grant Types** | Authorization methods | ✅ |
| **Scopes** | API permissions | ✅ |
| **Trusted** | Skip user consent | ❌ |

3. Click **"Create Client"**
4. **IMPORTANT:** Copy the **Client Secret** - it's shown only once!

**Example Configuration:**

```
Name: Sport Application
Organization: ZEA Platform
Client Type: Confidential
Redirect URIs:
  https://sport.zea.com/auth/callback
  https://sport.zea.com/auth/callback-silent
Grant Types:
  ☑ Authorization Code
  ☑ Refresh Token
Scopes:
  ☑ openid
  ☑ profile
  ☑ email
  ☑ sport:read
  ☑ sport:write
```

### Viewing Client Details

Click on a client to see:
- **Client ID:** Public identifier
- **Client Secret:** (hidden after creation)
- **Redirect URIs:** Allowed callback URLs
- **Grant Types:** Enabled authorization flows
- **Scopes:** Permitted API access
- **Status:** Active or inactive
- **Creation Date:** When the client was registered

### Editing a Client

1. Click **"Edit"** on the client row
2. Modify fields as needed
3. Click **"Save Changes"**

**Note:** You cannot change the Client ID or Client Secret through editing. To change the secret, use the "Rotate Secret" feature.

### Rotating Client Secret

For security, periodically rotate client secrets:

1. Go to the client details page
2. Click **"Rotate Secret"**
3. Confirm the action
4. **Copy the new secret** - shown only once!
5. Update your application's configuration with the new secret

**Recommended:** Rotate secrets every 90 days

### Deactivating a Client

To temporarily disable a client without deleting it:

1. Go to the client details page
2. Click **"Deactivate"**
3. Confirm the action

The client will immediately stop working. To reactivate, click **"Activate"**.

### Deleting a Client

**⚠️ Warning:** This action is permanent and cannot be undone.

1. Click **"Delete"** on the client row
2. Confirm the deletion
3. All associated tokens will be immediately revoked

---

## 🔐 API Keys Management

API Keys allow programmatic access to Thalamus APIs without user authentication.

### Viewing API Keys

Navigate to **API Keys** from the sidebar to see:
- Key name and description
- Key prefix (e.g., `ak_dev_vK8mN2`)
- Scopes (permissions)
- Status (Active/Revoked)
- Last used date
- Creation date

**Search & Filter:**
- Search by name or key prefix
- Filter by status (All/Active/Revoked)

### Creating a New API Key

1. Click **"New API Key"** button
2. Fill in the form:

| Field | Description | Required |
|-------|-------------|----------|
| **Name** | Descriptive name | ✅ |
| **Description** | Purpose of the key | ❌ |
| **Scopes** | Permissions to grant | ✅ |

3. Select scopes by checking the boxes:
   - `clients:read` - View OAuth2 clients
   - `clients:write` - Create/update OAuth2 clients
   - `clients:delete` - Delete OAuth2 clients
   - `users:read` - View users
   - `users:write` - Create/update users
   - `organizations:read` - View organizations
   - `organizations:write` - Create/update organizations
   - `corpus:read` - Read corpus data
   - `corpus:write` - Write corpus data

4. Click **"Generate API Key"**
5. **CRITICAL:** Copy the full API key - it's shown only once!

**Example:**
```
Name: Sport Backend Service
Description: API key for Sport app to self-register OAuth2 clients
Scopes:
  ☑ clients:read
  ☑ clients:write
```

**API Key Format:**
```
ak_dev_vK8mN2pQ7xR9tY3wZ5aB1cD4eF6gH8jL
└────┬────┘└──────────────┬──────────────┘
  Prefix           Random Secret
```

### Using an API Key

Include the API key in your HTTP requests:

```bash
curl -H "Authorization: ApiKey ak_dev_vK8mN2pQ7xR9tY3wZ5aB1cD4eF6gH8jL" \
  https://thalamus.zea.com/api/clients
```

### Viewing API Key Details

Click on an API key to see:
- **Key Prefix:** First 13 characters (for identification)
- **Full Key:** (only shown once during creation)
- **Scopes:** Granted permissions
- **Status:** Active or Revoked
- **Last Used:** Timestamp of last usage
- **Expires:** Expiration date (if set)
- **Created:** Creation timestamp

### Revoking an API Key

To immediately invalidate an API key:

1. Go to the API key details page
2. Click **"Revoke Key"**
3. Confirm the action

The key will stop working immediately. To reactivate, click **"Activate Key"**.

### Deleting an API Key

**⚠️ Warning:** This action is permanent.

1. Click **"Delete"** on the key row
2. Confirm the deletion

---

## 👥 Users Management

Manage user accounts and permissions.

### Viewing Users

Navigate to **Users** from the sidebar to see:
- User email and full name
- Organization
- Status (Active/Inactive/Pending)
- MFA enabled
- Creation date

### Creating a New User

1. Click **"New User"** button
2. Fill in the form:
   - Email
   - Full name
   - Password
   - Organization
   - Status

3. Click **"Create User"**

### User Status

- **Active:** Can log in and access resources
- **Inactive:** Cannot log in
- **Pending:** Email not verified

### Editing a User

1. Click **"Edit"** on the user row
2. Modify fields
3. Click **"Save Changes"**

### Deactivating a User

1. Go to user details
2. Click **"Deactivate"**
3. Confirm

The user will be immediately logged out and unable to log in again.

---

## 🏢 Organizations Management

Organizations group users and OAuth2 clients.

### Viewing Organizations

Navigate to **Organizations** from the sidebar to see:
- Organization name
- Plan type (Free/Pro/Enterprise)
- Number of users
- Number of clients
- Creation date

### Creating an Organization

1. Click **"New Organization"** button
2. Fill in:
   - Name
   - Plan type

3. Click **"Create Organization"**

### Organization Plans

- **Free:** Limited features
- **Pro:** Extended features
- **Enterprise:** Full features + support

---

## 🔍 Access Tokens

View all issued OAuth2 access tokens.

### Viewing Tokens

Navigate to **Access Tokens** to see:
- Token ID
- User
- OAuth2 Client
- Scopes
- Expiration
- Status (Active/Revoked/Expired)

### Revoking a Token

1. Click on a token
2. Click **"Revoke Token"**
3. Confirm

The token will be immediately invalidated.

---

## 📋 Audit Logs

View security events and administrative actions.

### Viewing Audit Logs

Navigate to **Audit Logs** to see:
- Event type
- User/API Key that triggered the action
- Timestamp
- IP address
- Details

**Event Types:**
- User login/logout
- Client creation/modification
- API key creation/revocation
- Token generation/revocation
- User creation/modification
- Organization changes

**Search & Filter:**
- Search by user or event type
- Filter by date range

---

## ⚙️ Settings

Manage your personal account settings.

### Profile Settings

Navigate to **Settings** → **Profile** tab:

**Editable Fields:**
- Full name
- Email address

Click **"Save Changes"** to update.

### Security Settings

Navigate to **Settings** → **Security** tab:

#### Change Password

1. Enter current password
2. Enter new password (min 8 characters)
3. Confirm new password
4. Click **"Change Password"**

**Password Requirements:**
- At least 8 characters
- Must include uppercase, lowercase, number, and special character

#### Multi-Factor Authentication (MFA)

Enable MFA for additional security:

1. Click **"Enable MFA"**
2. Scan QR code with authenticator app (Google Authenticator, Authy, etc.)
3. Enter 6-digit code to confirm
4. Save backup codes

**To Disable MFA:**
1. Click **"Disable MFA"**
2. Enter current password
3. Confirm

### Preferences

Navigate to **Settings** → **Preferences** tab:

#### Theme

Choose your preferred theme:
- **Light:** Bright interface
- **Dark:** Dark interface (easier on eyes)
- **System:** Match OS theme

Theme changes are saved automatically and sync across devices.

---

## 🎨 Dashboard Features

### Sidebar Navigation

The collapsible sidebar provides quick access to all features:

**Toggle Sidebar:**
- Click the Thalamus logo to collapse/expand
- Collapsed state shows only icons
- Your preference is saved automatically

**Sections:**
- **Main:** Dashboard home
- **OAuth2:** Clients and tokens
- **Management:** Users and organizations
- **Security:** API keys and audit logs

### Search & Filters

Most list views support:
- **Search:** Real-time search as you type
- **Filters:** Filter by status, type, date, etc.
- **Sorting:** Click column headers to sort

### Breadcrumbs

Track your location in the dashboard with breadcrumbs at the top of each page.

### Flash Messages

Success and error messages appear at the top:
- **Green:** Success
- **Red:** Error
- **Yellow:** Warning
- **Blue:** Information

---

## 💡 Best Practices

### Security

1. **Use Strong Passwords**
   - Minimum 12 characters
   - Mix of uppercase, lowercase, numbers, symbols
   - Use a password manager

2. **Enable MFA**
   - Protects against password theft
   - Use authenticator app (not SMS)

3. **Rotate Secrets Regularly**
   - OAuth2 client secrets: Every 90 days
   - API keys: Every 90 days

4. **Revoke Unused Keys**
   - Delete old API keys
   - Deactivate inactive OAuth2 clients

5. **Monitor Audit Logs**
   - Review regularly for suspicious activity
   - Set up alerts for critical events

### OAuth2 Clients

1. **Use Confidential Type for Server Apps**
   - More secure than Public
   - Requires client secret

2. **Limit Scopes**
   - Only request scopes you need
   - Principle of least privilege

3. **Use HTTPS Redirect URIs**
   - Never use HTTP in production
   - Prevents token interception

4. **Validate Redirect URIs**
   - Be specific (not wildcards)
   - Prevents authorization code theft

### API Keys

1. **Store Securely**
   - Use secrets manager (AWS Secrets, Vault, etc.)
   - Never commit to git
   - Never log in plain text

2. **Scope Appropriately**
   - Only grant minimum required permissions
   - Use separate keys for different services

3. **Monitor Usage**
   - Check "Last Used" regularly
   - Delete unused keys

4. **Rotate Periodically**
   - Every 90 days recommended
   - Immediately if compromised

---

## ❓ Troubleshooting

### Can't Log In

**Error:** "Invalid email or password"

**Solutions:**
- Verify email and password are correct
- Check caps lock is off
- Reset password if forgotten (coming soon)
- Contact admin if account is deactivated

### OAuth2 Client Not Working

**Error:** "Invalid client_id"

**Solutions:**
- Verify client_id is correct
- Check client is Active (not Deactivated)
- Ensure redirect_uri matches exactly

### API Key Not Working

**Error:** "Unauthorized"

**Solutions:**
- Verify API key is correct
- Check key is Active (not Revoked)
- Ensure you're using `ApiKey` header (not `Bearer`)
- Verify key hasn't expired

### Can't Create OAuth2 Client

**Error:** "Forbidden"

**Solutions:**
- Verify you have admin permissions
- Check organization exists
- Ensure all required fields are filled

---

## 🆘 Support

Need help? Contact us:

- **Documentation:** https://docs.thalamus.zea.com
- **Email:** support@zea.com
- **GitHub Issues:** https://github.com/zea/thalamus/issues

---

## 🔄 Next Steps

1. ✅ Create your first OAuth2 client
2. ✅ Generate an API key for automation
3. ✅ Enable MFA on your account
4. ✅ Review audit logs regularly
5. ✅ Set calendar reminder to rotate secrets every 90 days

**Happy authenticating! 🚀**
