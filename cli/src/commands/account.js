import zeaFetch from '../lib/http.js';
import { getClient, loadConfig } from '../lib/client.js';
import { getGlobalOpts } from '../lib/globals.js';
import { handleError } from '../lib/errors.js';

export function register(program) {
  // ── register ───────────────────────────────────────
  program.command('register')
    .description('Register a new user account')
    .requiredOption('--email <email>', 'Email address')
    .requiredOption('--password <password>', 'Password (min 8 chars, uppercase, lowercase, number)')
    .option('--name <name>', 'Display name')
    .action(async (options) => {
      try {
        const { apiUrl } = await loadConfig();
        const resp = await zeaFetch(`${apiUrl}/api/public/register`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            email: options.email,
            password: options.password,
            name: options.name || options.email.split('@')[0],
          })
        });
        if (!resp.ok) {
          const err = await resp.json().catch(() => ({}));
          throw new Error(err.error || err.details || `HTTP ${resp.status}`);
        }
        console.log('✅ Registration successful. Check your email to verify your account.');
      } catch (e) { handleError(e); process.exit(1); }
    });

  // ── verify-email ───────────────────────────────────
  program.command('verify-email')
    .description('Verify email address with token')
    .requiredOption('--token <token>', 'Verification token from email')
    .action(async (options) => {
      try {
        const { apiUrl } = await loadConfig();
        const resp = await zeaFetch(`${apiUrl}/api/public/verify-email`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ token: options.token })
        });
        if (!resp.ok) {
          const err = await resp.json().catch(() => ({}));
          throw new Error(err.error || `HTTP ${resp.status}`);
        }
        console.log('✅ Email verified. You can now log in.');
      } catch (e) { handleError(e); process.exit(1); }
    });

  // ── resend-verification ────────────────────────────
  program.command('resend-verification')
    .description('Resend email verification')
    .requiredOption('--email <email>', 'Email address')
    .action(async (options) => {
      try {
        const { apiUrl } = await loadConfig();
        const resp = await zeaFetch(`${apiUrl}/api/public/resend-verification`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ email: options.email })
        });
        if (!resp.ok) {
          const err = await resp.json().catch(() => ({}));
          throw new Error(err.error || `HTTP ${resp.status}`);
        }
        console.log('✅ Verification email resent.');
      } catch (e) { handleError(e); process.exit(1); }
    });

  // ── password reset ─────────────────────────────────
  const pwdCmd = program.command('password').description('Password management');

  pwdCmd.command('reset')
    .description('Request password reset email')
    .requiredOption('--email <email>', 'Email address')
    .action(async (options) => {
      try {
        const { apiUrl } = await loadConfig();
        const resp = await zeaFetch(`${apiUrl}/api/public/password/reset`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ email: options.email })
        });
        if (!resp.ok) {
          const err = await resp.json().catch(() => ({}));
          throw new Error(err.error || `HTTP ${resp.status}`);
        }
        console.log('✅ Password reset email sent. Check your inbox.');
      } catch (e) { handleError(e); process.exit(1); }
    });

  pwdCmd.command('confirm-reset')
    .description('Confirm password reset with token')
    .requiredOption('--token <token>', 'Reset token from email')
    .requiredOption('--password <password>', 'New password')
    .action(async (options) => {
      try {
        const { apiUrl } = await loadConfig();
        const resp = await zeaFetch(`${apiUrl}/api/public/password/confirm-reset`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ token: options.token, password: options.password })
        });
        if (!resp.ok) {
          const err = await resp.json().catch(() => ({}));
          throw new Error(err.error || `HTTP ${resp.status}`);
        }
        console.log('✅ Password changed. You can now log in with your new password.');
      } catch (e) { handleError(e); process.exit(1); }
    });

  pwdCmd.command('change')
    .description('Change password (requires authentication)')
    .requiredOption('--current <password>', 'Current password')
    .requiredOption('--new <password>', 'New password')
    .action(async (options) => {
      try {
        const client = await getClient();
        const resp = await zeaFetch(`${client.apiUrl}/api/password/change`, {
          method: 'PUT',
          headers: client.headers,
          body: JSON.stringify({
            current_password: options.current,
            new_password: options.new,
          })
        });
        if (!resp.ok) {
          const err = await resp.json().catch(() => ({}));
          throw new Error(err.error || `HTTP ${resp.status}`);
        }
        console.log('✅ Password changed.');
      } catch (e) { handleError(e); process.exit(1); }
    });

  // ── avatar ─────────────────────────────────────────
  const avatarCmd = program.command('avatar').description('Avatar management');

  avatarCmd.command('upload')
    .description('Upload avatar image')
    .requiredOption('--file <path>', 'Path to image file')
    .action(async (options) => {
      try {
        const fs = await import('fs');
        const path = await import('path');
        const filePath = path.resolve(options.file);
        if (!fs.existsSync(filePath)) {
          console.error('❌ File not found:', filePath);
          process.exit(1);
        }
        const client = await getClient();
        const boundary = '----FormBoundary' + Math.random().toString(36).slice(2);
        const buf = fs.readFileSync(filePath);
        const ext = path.extname(filePath).toLowerCase();
        const mime = ext === '.png' ? 'image/png' : ext === '.jpg' || ext === '.jpeg' ? 'image/jpeg' : 'application/octet-stream';

        const body = Buffer.concat([
          Buffer.from(`--${boundary}\r\nContent-Disposition: form-data; name="avatar"; filename="avatar${ext}"\r\nContent-Type: ${mime}\r\n\r\n`),
          buf,
          Buffer.from(`\r\n--${boundary}--\r\n`),
        ]);

        const resp = await fetch(`${client.apiUrl}/api/avatar`, {
          method: 'POST',
          headers: { ...client.headers, 'Content-Type': `multipart/form-data; boundary=${boundary}` },
          body,
        });
        if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
        console.log('✅ Avatar uploaded.');
      } catch (e) { handleError(e); process.exit(1); }
    });

  avatarCmd.command('delete')
    .description('Delete avatar')
    .action(async () => {
      try {
        const client = await getClient();
        const resp = await zeaFetch(`${client.apiUrl}/api/avatar`, {
          method: 'DELETE', headers: client.headers
        });
        if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
        console.log('✅ Avatar deleted.');
      } catch (e) { handleError(e); process.exit(1); }
    });
}
