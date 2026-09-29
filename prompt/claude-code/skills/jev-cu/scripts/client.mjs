import { readFile, stat } from 'node:fs/promises';
import { buildRequest } from './core.mjs';

export const ENDPOINT = 'https://api.typesafe.ai/v1/systemone';
export const providerConfig = provider => provider === 'typesafe'
  ? { endpoint: ENDPOINT, model: 'jev-1.13.0', envName: 'TYPESAFE_API_KEY' }
  : provider === 'openjev'
    ? { endpoint: 'https://api.openjev.sh/v1/systemone', model: 'openjev', envName: 'OPENJEV_API_KEY' }
    : null;
// No default file search, clipboard access, keychain access, or secret logging.
export const credential = ({ env = globalThis.process?.env ?? {}, keyFile, provider = 'typesafe' } = {}) => !providerConfig(provider)
  ? Promise.resolve({ ok: false, reason: 'invalid_provider' })
  : env[providerConfig(provider).envName]?.trim()
  ? Promise.resolve({ ok: true, key: env[providerConfig(provider).envName].trim() })
  : keyFile ? stat(keyFile).then(info => info.isFile() && (info.mode & 0o077) === 0
    ? readFile(keyFile, 'utf8').then(value => value.trim() ? { ok: true, key: value.trim() } : { ok: false, reason: 'empty_key' })
    : { ok: false, reason: 'key_file_permissions' }).catch(() => ({ ok: false, reason: 'key_unavailable' }))
  : Promise.resolve({ ok: false, reason: 'key_unavailable' });

// Bounded full response (including body), fixed endpoint, no redirect, no retry.
// Returning to the planner on 429 avoids accumulating requests and stale UI.
export const requestDecision = ({ goal, candidates, key, timeoutMs = 4000, fetchImpl = fetch, provider = 'typesafe' }) => {
  const config = providerConfig(provider);
  if (!config) return Promise.resolve({ ok: false, reason: 'invalid_provider' });
  const started = performance.now();
  return fetchImpl(config.endpoint, {
    method: 'POST', redirect: 'error', signal: AbortSignal.timeout(timeoutMs),
    headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(buildRequest({ goal, candidates, model: config.model })),
  }).then(async response => response.ok
    ? response.json().then(body => body.model === config.model && body.answers?.target
      ? { ok: true, answer: body.answers.target, model: body.model, latencyMs: performance.now() - started }
      : { ok: false, reason: 'invalid_response' })
    : { ok: false, reason: response.status === 429 ? 'rate_limited' : `http_${response.status}` }
  ).catch(() => ({ ok: false, reason: 'transport_error' }));
};
