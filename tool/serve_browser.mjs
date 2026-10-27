import http from 'node:http';
import { createReadStream } from 'node:fs';
import { realpath, stat } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const types = { '.html': 'text/html; charset=utf-8', '.js': 'application/javascript', '.mjs': 'application/javascript', '.json': 'application/json', '.wasm': 'application/wasm', '.css': 'text/css', '.png': 'image/png', '.svg': 'image/svg+xml', '.ttf': 'font/ttf', '.otf': 'font/otf', '.woff2': 'font/woff2' };
const requestHeaders = ['authorization', 'content-type', 'accept', 'idempotency-key', 'last-event-id'];
const responseHeaders = ['content-type', 'cache-control', 'retry-after', 'x-request-id'];
const within = (root, target) => target === root || target.startsWith(root + path.sep);

export function createBrowserServer({ buildDirectory, upstream = 'http://127.0.0.1:8080' }) {
  const backend = new URL(upstream);
  if (backend.origin !== upstream || backend.protocol !== 'http:' || backend.hostname !== '127.0.0.1') throw Error('Loopback upstream required.');
  const root = path.resolve(buildDirectory);
  const server = http.createServer(async (req, res) => {
    const fail = status => { if (!res.headersSent) { res.writeHead(status, { 'content-type': 'application/json', 'cache-control': 'no-store' }); res.end(JSON.stringify({ error: status === 502 ? 'local_backend_unavailable' : 'request_rejected' })); } else res.destroy(); };
    try {
      const origin = `http://127.0.0.1:${server.address().port}`;
      if (req.headers.host !== new URL(origin).host || (req.headers.origin && req.headers.origin !== origin) || req.headers['sec-fetch-site'] === 'cross-site') return fail(403);
      const url = new URL(req.url, origin);
      if (url.origin !== origin) return fail(403);
      let pathname;
      try { pathname = decodeURIComponent(url.pathname); } catch { return fail(400); }
      if (pathname.includes('\\') || pathname.includes('\0') || pathname.split('/').includes('..')) return fail(400);
      if (pathname.startsWith('/api/')) {
        // Same-origin browser checks happen above; the upstream sees the existing native bearer contract.
        const headers = Object.fromEntries(requestHeaders.filter(key => req.headers[key] !== undefined).map(key => [key, req.headers[key]]));
        const relay = http.request(new URL(url.pathname + url.search, backend), { method: req.method, headers }, incoming => {
          res.writeHead(incoming.statusCode ?? 502, { ...Object.fromEntries(responseHeaders.filter(key => incoming.headers[key] !== undefined).map(key => [key, incoming.headers[key]])), 'cache-control': 'no-store' });
          incoming.on('error', () => res.destroy()); incoming.pipe(res);
        });
        relay.on('error', () => fail(502));
        relay.setTimeout(180000, () => relay.destroy());
        req.on('aborted', () => relay.destroy());
        res.on('close', () => relay.destroy());
        req.pipe(relay); return;
      }
      if (!['GET', 'HEAD'].includes(req.method)) return fail(405);
      const relative = pathname === '/' ? 'index.html' : pathname.slice(1);
      const candidate = path.resolve(root, relative);
      if (!within(root, candidate)) return fail(403);
      let filename;
      try { filename = await realpath(candidate); if (!within(await realpath(root), filename)) return fail(403); if (!(await stat(filename)).isFile()) return fail(404); }
      catch { return fail(404); }
      res.writeHead(200, { 'content-type': types[path.extname(filename)] ?? 'application/octet-stream', 'cache-control': 'no-store', 'x-content-type-options': 'nosniff' });
      if (req.method === 'HEAD') return res.end();
      const stream = createReadStream(filename); stream.on('error', () => res.destroy()); stream.pipe(res);
    } catch { fail(502); }
  });
  return server;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const buildDirectory = fileURLToPath(new URL('../build/web/', import.meta.url));
  try { await stat(path.join(buildDirectory, 'main.dart.js')); }
  catch { console.error('Build web first with tool/run-browser.ps1.'); process.exit(1); }
  const server = createBrowserServer({ buildDirectory });
  server.on('error', () => { console.error('Cannot start local browser preview on port3001.'); process.exitCode = 1; });
  server.listen(3001, '127.0.0.1', () => console.log('SynCare patient browser preview: http://127.0.0.1:3001 (backend localhost8080)'));
}
