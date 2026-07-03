# MFA API

Multi-factor authentication with TOTP (Time-based One-Time Password). Setup, verification, disable, and backup codes.

---

## Endpoints

| Method | Endpoint | Purpose |
|---|---|---|
| `POST` | `/api/mfa/totp/setup` | Start TOTP setup |
| `POST` | `/api/mfa/totp/verify` | Verify and activate TOTP |
| `POST` | `/api/mfa/verify` | Verify MFA code during login |
| `DELETE` | `/api/mfa/disable` | Disable MFA |
| `POST` | `/api/mfa/backup-codes/regenerate` | Regenerate backup codes |

**Pipeline:** `authenticated_api` — JWT Bearer, 5000 req/min per user.

---

## TOTP Setup

Starts the MFA setup process. Returns a TOTP secret and QR code URI.

```bash
POST /api/mfa/totp/setup
Authorization: Bearer eyJhbGciOi...
```

**Response:**
```json
{
  "data": {
    "secret": "JBSWY3DPEHPK3PXP",
    "qr_code_uri": "otpauth://totp/Thalamus:user@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Thalamus",
    "backup_codes": [
      "a1b2-c3d4-e5f6",
      "g7h8-i9j0-k1l2",
      "m3n4-o5p6-q7r8",
      "s9t0-u1v2-w3x4",
      "y5z6-a7b8-c9d0"
    ]
  }
}
```

| Field | Description |
|---|---|
| `secret` | TOTP secret (base32). Scan with authenticator app or enter manually |
| `qr_code_uri` | URI for QR code generation |
| `backup_codes` | 5 one-time recovery codes. **Save these in a secure location** |

---

## Verify TOTP

Verifies a TOTP code from the authenticator app and activates MFA.

```bash
POST /api/mfa/totp/verify
Authorization: Bearer eyJhbGciOi...
Content-Type: application/json

{
  "code": "123456"
}
```

**Parameters:**

| Parameter | Required | Description |
|---|---|---|
| `code` | ✅ | 6-digit TOTP code from authenticator app |

**Response:**
```json
{
  "data": {
    "mfa_enabled": true,
    "method": "totp",
    "message": "MFA enabled successfully"
  }
}
```

---

## Verify MFA Code (Login)

Used during login flow when MFA is required for a user.

```bash
POST /api/mfa/verify
Authorization: Bearer eyJhbGciOi...
Content-Type: application/json

{
  "user_id": "user_abc123",
  "code": "123456"
}
```

**Parameters:**

| Parameter | Required | Description |
|---|---|---|
| `user_id` | ✅ | User UUID |
| `code` | ✅ | 6-digit TOTP code or backup code |

**Response:**
```json
{
  "data": {
    "verified": true,
    "method": "totp"
  }
}
```

---

## Disable MFA

Disables MFA for the authenticated user. Requires password and valid TOTP code.

```bash
DELETE /api/mfa/disable
Authorization: Bearer eyJhbGciOi...
Content-Type: application/json

{
  "password": "SecurePass123!",
  "code": "123456"
}
```

**Parameters:**

| Parameter | Required | Description |
|---|---|---|
| `password` | ✅ | Current password for confirmation |
| `code` | ✅ | Valid TOTP code |

**Response:**
```json
{
  "data": {
    "mfa_enabled": false,
    "message": "MFA disabled successfully"
  }
}
```

---

## Regenerate Backup Codes

Generates a new set of backup codes. Requires password and valid TOTP code. Previous codes are invalidated.

```bash
POST /api/mfa/backup-codes/regenerate
Authorization: Bearer eyJhbGciOi...
Content-Type: application/json

{
  "password": "SecurePass123!",
  "code": "123456"
}
```

**Response:**
```json
{
  "data": {
    "backup_codes": [
      "e1f2-g3h4-i5j6",
      "k7l8-m9n0-o1p2",
      "q3r4-s5t6-u7v8",
      "w9x0-y1z2-a3b4",
      "c5d6-e7f8-g9h0"
    ]
  }
}
```

> ⚠️ Old backup codes are immediately invalidated.

---

## MFA Flow

```
1. POST /api/mfa/totp/setup     → Get secret + QR + backup codes
2. User scans QR with app
3. POST /api/mfa/totp/verify    → Enter code to activate
4. MFA is now enabled

Login flow:
1. POST /api/public/login        → Returns { mfa_required: true, user_id: "..." }
2. POST /api/mfa/verify          → Enter TOTP code
3. Returns access_token
```

---

## See Also

- [Authentication API](authentication.md) — Login and registration
- [Users API](users.md) — User management
