import http from 'node:http';

/**
 * Creates a tiny HTTP server for testing CLI commands.
 * No mocking, no nock — just a real http.createServer.
 *
 * Usage:
 *   const server = createTestServer();
 *   server.get('/api/public/health', 200, { status: 'ok' });
 *   server.post('/api/clients', 201, { data: { id: 'c1' } });
 *   const url = await server.start();
 *   // ... run command against url ...
 *   server.stop();
 */
export function createTestServer() {
  const handlers = [];

  const srv = http.createServer((req, res) => {
    const bodyChunks = [];
    req.on('data', c => bodyChunks.push(c));
    req.on('end', () => {
      const body = Buffer.concat(bodyChunks).toString();
      const handler = handlers.find(h => {
        if (h.method && h.method !== req.method) return false;
        if (typeof h.path === 'string') return req.url === h.path;
        if (h.path instanceof RegExp) return h.path.test(req.url);
        return false;
      });

      if (handler) {
        res.writeHead(handler.status || 200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify(typeof handler.body === 'function' ? handler.body(req, body) : handler.body));
      } else {
        res.writeHead(404, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'not found', url: req.url, method: req.method }));
      }
    });
  });

  return {
    get(path, status, body) {
      handlers.push({ method: 'GET', path, status, body: body || {} });
      return this;
    },
    post(path, status, body) {
      handlers.push({ method: 'POST', path, status, body: body || {} });
      return this;
    },
    put(path, status, body) {
      handlers.push({ method: 'PUT', path, status, body: body || {} });
      return this;
    },
    patch(path, status, body) {
      handlers.push({ method: 'PATCH', path, status, body: body || {} });
      return this;
    },
    delete(path, status, body) {
      handlers.push({ method: 'DELETE', path, status, body: body || {} });
      return this;
    },
    any(path, status, body) {
      handlers.push({ path, status, body: body || {} });
      return this;
    },
    reset() { handlers.length = 0; return this; },
    start() {
      return new Promise(resolve => srv.listen(0, '127.0.0.1', () => {
        resolve(`http://127.0.0.1:${srv.address().port}`);
      }));
    },
    stop() {
      return new Promise(resolve => srv.close(() => resolve()));
    },
  };
}
