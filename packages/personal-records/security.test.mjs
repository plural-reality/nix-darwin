import assert from 'node:assert/strict';
import test from 'node:test';
const { requestJson } = await import(process.env.COSENSE_REQUEST_MODULE);
const capture = [];
globalThis.fetch = async (url, options) => {
  capture.push({ url, options });
  return new Response('{}', { status: 200, headers: { 'content-type': 'application/json' } });
};
await test('reject foreign credential destinations before fetch', async () => {
  const before = capture.length;
  await Promise.all([
    'https://example.invalid/api',
    'https://scrapbox.io.example.invalid/api',
    'http://scrapbox.io/api',
    'https://user:pass@scrapbox.io/api',
    'https://scrapbox.io:444/api',
  ].map(url => assert.rejects(requestJson(url), /origin is not allowed/)));
  assert.equal(capture.length, before);
});
await test('official API disables redirects; anonymous oembed still works', async () => {
  await requestJson('https://scrapbox.io/api/users/me');
  assert.equal(capture.at(-1).options.redirect, 'error');
  await requestJson('https://api.gyazo.com/api/oembed');
  await assert.rejects(requestJson('https://api.gyazo.com/api/images'), /origin is not allowed/);
  await assert.rejects(requestJson('https://api.gyazo.com/api/oembed', { credential: { type: 'pat', token: 'canary' } }), /origin is not allowed/);
});
