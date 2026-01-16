-- Create test organization
INSERT INTO organizations (
  id,
  name,
  plan_type,
  status,
  verified,
  max_users,
  max_api_calls_per_month,
  api_calls_reset_at,
  inserted_at,
  updated_at
)
VALUES (
  'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
  'Test SDK Organization',
  'professional',
  'active',
  true,
  100,
  1000000,
  NOW(),
  NOW(),
  NOW()
)
ON CONFLICT (name) DO UPDATE SET
  plan_type = EXCLUDED.plan_type,
  status = EXCLUDED.status,
  verified = EXCLUDED.verified;

-- Create test user (password will be: test123)
-- Password hash for 'test123' with bcrypt
INSERT INTO users (
  id,
  email,
  password_hash,
  name,
  status,
  verified_at,
  organization_id,
  inserted_at,
  updated_at
)
VALUES (
  'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22',
  'testsdk@example.com',
  '$2b$12$MUAbg/9duuLnfs1KqEZzjOMs.j20vXCyO7zvQvv8gkrpajREwOo7q',
  'SDK Test User',
  'active',
  NOW(),
  'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
  NOW(),
  NOW()
)
ON CONFLICT (email) DO UPDATE SET
  status = EXCLUDED.status,
  verified_at = EXCLUDED.verified_at;

-- Create OAuth2 client
-- client_id_string: test_sdk_nextjs
-- client_secret: sdk_secret_2026 (will be hashed)
INSERT INTO oauth2_clients (
  id,
  name,
  client_id_string,
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
  'Test SDK Next.js App',
  'test_sdk_nextjs',
  '$2b$12$PRGfbopNhYMm/XtExkj..eH7.TKdG30bJhCTlbQTmQO4xMkqVMSZC',
  'confidential',
  ARRAY['http://localhost:3000/auth/callback'],
  ARRAY['authorization_code', 'refresh_token'],
  ARRAY['openid', 'profile', 'email'],
  'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
  true,
  NOW(),
  NOW()
)
ON CONFLICT (client_id_string) DO UPDATE SET
  redirect_uris = EXCLUDED.redirect_uris,
  allowed_grant_types = EXCLUDED.allowed_grant_types,
  allowed_scopes = EXCLUDED.allowed_scopes,
  is_active = EXCLUDED.is_active;

-- Display what was created
SELECT
  '✅ TEST DATA CREATED' as status,
  'testsdk@example.com' as user_email,
  'test123' as user_password,
  'test_sdk_nextjs' as client_id,
  'sdk_secret_2026' as client_secret,
  'http://localhost:3000/auth/callback' as redirect_uri;
