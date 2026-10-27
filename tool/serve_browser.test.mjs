import test from 'node:test';
import assert from 'node:assert/strict';
import http from 'node:http';
import { mkdtemp, mkdir, writeFile, rm } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { once } from 'node:events';
import { createBrowserServer } from './serve_browser.mjs';

const listen = async server => { server.listen(0, '127.0.0.1'); await once(server, 'listening'); return `http://127.0.0.1:${server.address().port}`; };
const rawStatus = (url, headers) => new Promise((resolve, reject) => { const request = http.request(url, { method: 'POST', headers }, response => { response.resume(); response.on('end', () => resolve(response.statusCode)); }); request.on('error', reject); request.end(); });
async function fixture(t, handler) {
  const temporary = await mkdtemp(path.join(os.tmpdir(), 'syncare-browser-test-'));
  const buildDirectory = path.join(temporary, 'public'); await mkdir(buildDirectory);
  await writeFile(path.join(buildDirectory, 'index.html'), '<title>SynCare</title>');
  await writeFile(path.join(buildDirectory, 'main.dart.js'), 'void 0;');
  await writeFile(path.join(temporary, 'private.txt'), 'must-not-be-served');
  const upstream = http.createServer(handler ?? ((req, res) => { res.writeHead(401); res.end('unauthenticated'); }));
  const upstreamOrigin = await listen(upstream);
  const server = createBrowserServer({ buildDirectory, upstream: upstreamOrigin });
  const origin = await listen(server);
  t.after(async () => {
    for (const current of [server, upstream]) { current.closeAllConnections(); await new Promise(resolve => current.close(resolve)); }
    if (path.resolve(temporary).startsWith(path.join(os.tmpdir(), 'syncare-browser-test-'))) await rm(temporary, { recursive: true, force: true });
  });
  return { origin, upstream };
}

test('serves only public build files with correct MIME/no-store; missing asset and traversal cannot expose files', async t => {
  const { origin } = await fixture(t);
  const html = await fetch(origin); assert.equal(html.status, 200); assert.match(await html.text(), /SynCare/);
  const script = await fetch(`${origin}/main.dart.js`); assert.equal(script.headers.get('content-type'), 'application/javascript'); assert.equal(script.headers.get('cache-control'), 'no-store');
  for (const target of ['/missing.js', '/private.txt', '/%2e%2e%2fprivate.txt', '/..%5cprivate.txt']) {
    const response = await fetch(origin + target); assert.ok(response.status >= 400); assert.doesNotMatch(await response.text(), /must-not-be-served/);
  }
  assert.equal((await fetch(origin, { method: 'POST' })).status, 405);
});

test('foreign origin, cross-site fetch and forged Host never reach upstream; same-origin bearer intent is preserved', async t => {
  let calls = 0, received;
  const { origin } = await fixture(t, async (req, res) => {
    calls++; let body = ''; for await (const chunk of req) body += chunk;
    received = { headers: req.headers, url: req.url, body };
    res.writeHead(409, { 'content-type': 'application/json', 'cache-control': 'public', 'set-cookie': 'not-relayed=1' }); res.end('{"error":"version_conflict"}');
  });
  for (const headers of [{ Origin: 'https://foreign.example' }, { 'Sec-Fetch-Site': 'cross-site' }, { Host: 'foreign.example' }]) assert.equal(await rawStatus(`${origin}/api/v1/auth/login`, headers), 403);
  assert.equal(calls, 0);
  const result = await fetch(`${origin}/api/v1/bookings/example/transitions?check=1`, { method: 'POST', headers: { Origin: origin, Authorization: 'Bearer test-session', 'Idempotency-Key': 'test-intent', 'Content-Type': 'application/json', Cookie: 'not-forwarded=1' }, body: '{"expectedVersion":2}' });
  assert.equal(result.status, 409); assert.deepEqual(await result.json(), { error: 'version_conflict' }); assert.equal(result.headers.get('cache-control'), 'no-store'); assert.equal(result.headers.get('set-cookie'), null); assert.equal(calls, 1);
  assert.equal(received.headers.origin, undefined); assert.equal(received.headers.cookie, undefined);
  assert.equal(received.headers.authorization, 'Bearer test-session'); assert.equal(received.headers['idempotency-key'], 'test-intent');
  assert.equal(received.url, '/api/v1/bookings/example/transitions?check=1'); assert.equal(received.body, '{"expectedVersion":2}');
});

test('missing bearer remains unauthorized and stopped upstream returns502 without invented success', async t => {
  const { origin, upstream } = await fixture(t);
  assert.equal((await fetch(`${origin}/api/v1/patients/me`)).status, 401);
  upstream.closeAllConnections(); await new Promise(resolve => upstream.close(resolve));
  const response = await fetch(`${origin}/api/v1/patients/me`); assert.equal(response.status, 502); assert.deepEqual(await response.json(), { error: 'local_backend_unavailable' });
});

test('API event stream arrives before upstream completion', async t => {
  let finish;
  const { origin } = await fixture(t, (req, res) => { res.writeHead(200, { 'content-type': 'text/event-stream' }); res.write('data: first\n\n'); finish = () => res.end('data: last\n\n'); });
  const response = await fetch(`${origin}/api/v1/events`);
  assert.equal(response.headers.get('content-type'), 'text/event-stream');
  const reader = response.body.getReader(); const first = await reader.read(); assert.match(new TextDecoder().decode(first.value), /data: first/);
  finish(); let remaining = ''; for (;;) { const next = await reader.read(); if (next.done) break; remaining += new TextDecoder().decode(next.value); } assert.match(remaining, /data: last/);
});
