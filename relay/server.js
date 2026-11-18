// Brain Max — relay local (Windows)
// Recebe POST /proxy com { url, method, auth, body } do app no iPad (HTTP),
// faz a chamada HTTPS real para a API escolhida, e devolve { status, data }.
// Chaves de API ficam no iPad; este relay só repassa e não persiste nada.
'use strict';

const http = require('http');
const https = require('https');
const { URL } = require('url');

const PORT = process.env.BRAINMAX_PORT ? parseInt(process.env.BRAINMAX_PORT, 10) : 8890;

function rawRequest(options, bodyBuffer) {
  return new Promise((resolve, reject) => {
    const mod = options.protocol === 'https:' ? https : http;
    const req = mod.request(options, (res) => {
      const chunks = [];
      res.on('data', (c) => chunks.push(c));
      res.on('end', () => {
        const data = Buffer.concat(chunks);
        resolve({ status: res.statusCode || 0, headers: res.headers, data });
      });
    });
    req.on('error', (e) => reject(e));
    if (bodyBuffer) req.write(bodyBuffer);
    req.end();
  });
}

function jsonBody(req) {
  return new Promise((resolve) => {
    const chunks = [];
    req.on('data', (c) => chunks.push(c));
    req.on('end', () => {
      const raw = Buffer.concat(chunks).toString('utf8');
      let obj = null;
      try { obj = JSON.parse(raw); } catch (e) { obj = null; }
      resolve(obj);
    });
  });
}

const server = http.createServer(async (req, res) => {
  // CORS simples para facilitar debug no navegador, se necessário.
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  if (req.method === 'POST' && req.url === '/proxy') {
    const env = await jsonBody(req);
    if (!env || !env.url) {
      res.writeHead(400, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ status: 400, data: { error: { message: 'Envelope inválido: falta "url"' } } }));
      return;
    }

    let u;
    try { u = new URL(env.url); } catch (e) {
      res.writeHead(400, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ status: 400, data: { error: { message: 'URL inválida: ' + env.url } } }));
      return;
    }

    const method = (env.method || 'POST').toUpperCase();
    const headers = {
      'Content-Type': 'application/json',
      'User-Agent': 'BrainMax-relay/1.0',
    };
    if (env.auth) headers['Authorization'] = 'Bearer ' + env.auth;

    const bodyBuffer = env.body ? Buffer.from(String(env.body), 'utf8') : null;

    const options = {
      protocol: u.protocol,
      hostname: u.hostname,
      port: u.port || (u.protocol === 'https:' ? 443 : 80),
      path: u.pathname + (u.search || ''),
      method,
      headers,
    };

    try {
      const r = await rawRequest(options, bodyBuffer);
      // Devolve o corpo da API e o status HTTP.
      const ctype = r.headers['content-type'] || '';
      if (ctype.includes('application/json')) {
        let parsed = null;
        try { parsed = JSON.parse(r.data.toString('utf8')); } catch (e) { parsed = { raw: r.data.toString('utf8') }; }
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ status: r.status, data: parsed }));
      } else {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ status: r.status, data: { raw: r.data.toString('utf8') } }));
      }
    } catch (err) {
      res.writeHead(502, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ status: 502, data: { error: { message: 'Falha na chamada à API: ' + (err.message || String(err)) } } }));
    }
    return;
  }

  if (req.method === 'GET' && req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ ok: true, name: 'brainmax-relay' }));
    return;
  }

  res.writeHead(404, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ status: 404, data: { error: { message: 'Rota não encontrada' } } }));
});

server.listen(PORT, '0.0.0.0', () => {
  console.log('Brain Max relay ouvindo em 0.0.0.0:' + PORT);
});