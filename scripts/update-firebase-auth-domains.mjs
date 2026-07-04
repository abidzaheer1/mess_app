/**
 * Adds Netlify/GitHub Pages domains to Firebase Auth authorized domains.
 * Requires: firebase login (uses local firebase-tools credentials).
 *
 * Usage: node scripts/update-firebase-auth-domains.mjs
 */
import { readFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';

const PROJECT_ID = 'mess-df58f';
const DOMAINS_TO_ENSURE = [
  'mess.asxora.io',
  'alpha-mess-app.netlify.app',
  'abidzaheer1.github.io',
];

function loadRefreshToken() {
  const configPath = join(homedir(), '.config', 'configstore', 'firebase-tools.json');
  const raw = readFileSync(configPath, 'utf8');
  const config = JSON.parse(raw);
  const refreshToken = config?.tokens?.refresh_token;
  if (!refreshToken) {
    throw new Error('No Firebase refresh token found. Run: firebase login');
  }
  return refreshToken;
}

async function getAccessToken(refreshToken) {
  const body = new URLSearchParams({
    client_id: '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com',
    client_secret: 'j9iVZfS8kkCEFUPaAeJV0sAi',
    refresh_token: refreshToken,
    grant_type: 'refresh_token',
  });
  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body,
  });
  if (!res.ok) {
    throw new Error(`Token refresh failed: ${res.status} ${await res.text()}`);
  }
  const data = await res.json();
  if (!data.access_token) {
    throw new Error('No access_token in OAuth response');
  }
  return data.access_token;
}

async function getConfig(token) {
  const url = `https://identitytoolkit.googleapis.com/v2/projects/${PROJECT_ID}/config`;
  const res = await fetch(url, {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (!res.ok) {
    throw new Error(`getConfig failed: ${res.status} ${await res.text()}`);
  }
  return res.json();
}

async function updateDomains(token, domains) {
  const url =
    `https://identitytoolkit.googleapis.com/v2/projects/${PROJECT_ID}/config?updateMask=authorizedDomains`;
  const res = await fetch(url, {
    method: 'PATCH',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ authorizedDomains: domains }),
  });
  if (!res.ok) {
    throw new Error(`updateConfig failed: ${res.status} ${await res.text()}`);
  }
  return res.json();
}

async function main() {
  const refreshToken = loadRefreshToken();
  const token = await getAccessToken(refreshToken);
  const config = await getConfig(token);
  const current = config.authorizedDomains ?? [];
  const merged = [...current];
  for (const domain of DOMAINS_TO_ENSURE) {
    if (!merged.includes(domain)) merged.push(domain);
  }
  if (merged.length === current.length) {
    console.log('Authorized domains already include:', DOMAINS_TO_ENSURE.join(', '));
    return;
  }
  const updated = await updateDomains(token, merged);
  console.log('Updated authorized domains:');
  for (const d of updated.authorizedDomains ?? merged) {
    console.log(' -', d);
  }
}

main().catch((err) => {
  console.error(err.message ?? err);
  process.exit(1);
});
