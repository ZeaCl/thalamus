-- Create test organization
INSERT INTO organizations (id, name, plan, is_active, inserted_at, updated_at)
VALUES (
  'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
  'Test Organization',
  'professional',
  true,
  NOW(),
  NOW()
)
ON CONFLICT (id) DO NOTHING;

-- Create test user (password: test123)
INSERT INTO users (id, email, password_hash, name, email_verified, is_active, organization_id, inserted_at, updated_at)
VALUES (
  'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22',
  'test@example.com',
  '$2b$10$X8rZ9QP7fJ3KGz5YQh.Tn.M9vZ5YQh.Tn.M9vZ5YQh.Tn.M9vZ5YQ',
  'Test User',
  true,
  true,
  'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
  NOW(),
  NOW()
)
ON CONFLICT (email) DO NOTHING;

-- Generate client credentials
-- client_id: test_sdk_demo
-- client_secret: demo_secret_12345 (hashed with bcrypt)
INSERT INTO oauth2_clients (
  id,
  name,
  client_id,
  client_secret,
  client_type,
  redirect_uris,
  allowed_grant_types,
  allowed_scopes,
  organization_id,
  is_active,
  inserted_at,
  updated_at
)
VALUES (
  'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33',
  'Test Next.js App',
  'test_sdk_demo',
  '$2b$10$N9qo8uLOickgx2ZMRZoMye7FRNpGhM4bZM4bZM4bZM4bZM4bZM4bZ',
  'confidential',
  '["http://localhost:3000/auth/callback"]',
  '["authorization_code", "refresh_token"]',
  '["openid", "profile", "email"]',
  'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
  true,
  NOW(),
  NOW()
)
ON CONFLICT (client_id) DO UPDATE SET
  redirect_uris = EXCLUDED.redirect_uris,
  allowed_grant_types = EXCLUDED.allowed_grant_types,
  allowed_scopes = EXCLUDED.allowed_scopes;

-- Display credentials
SELECT
  'CREDENTIALS CREATED:' as message,
  'test@example.com' as user_email,
  'test123' as user_password,
  'test_sdk_demo' as client_id,
  'demo_secret_12345' as client_secret,
  'http://localhost:3000/auth/callback' as redirect_uri;
