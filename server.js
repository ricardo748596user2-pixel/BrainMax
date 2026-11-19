// Brain Max — servidor local (PC)
// Serve o frontend (web/) e faz as chamadas HTTPS às APIs dos provedores.
// As chaves de API e conversas ficam salvas em JSON aqui no PC (data/), nunca no iPad.
// O navegador do iPad (iOS 9.3, sem fetch/async/ES6) só fala HTTP com este servidor.
'use strict';

const http = require('http');
const https = require('https');
const fs = require('fs');
const path = require('path');
const { URL } = require('url');

const PORT = process.env.BRAINMAX_PORT ? parseInt(process.env.BRAINMAX_PORT, 10) : 8890;
const WEB_DIR = path.join(__dirname, 'web');
const DATA_DIR = path.join(__dirname, 'data');
const KEYS_FILE = path.join(DATA_DIR, 'keys.json');
const CHATS_FILE = path.join(DATA_DIR, 'chats.json');

// ---- Provedores prontos (base URL). Todos OpenAI-compatible (/models e /chat/completions).
const PROVIDERS = {
  'OpenRouter': 'https://openrouter.ai/api/v1',
  'Groq': 'https://api.groq.com/openai/v1',
  'NVIDIA Build': 'https://integrate.api.nvidia.com/v1',
  'AMD Token Lab': 'https://api.tokenlab.amd.com/v1',
  '9Router': process.env.BRAINMAX_NINEROUTER || 'http://127.0.0.1:11434/v1'
};

// ---- Persistência em JSON (no PC) ----
function ensureDataDir() {
  if (!fs.existsSync(DATA_DIR)) fs.mkdirSync(DATA_DIR, { recursive: true });
}
function readJson(file) {
  try {
    ensureDataDir();
    if (!fs.existsSync(file)) return null;
    return JSON.parse(fs.readFileSync(file, 'utf8'));
  } catch (e) { return null; }
}
function writeJson(file, obj) {
  ensureDataDir();
  fs.writeFileSync(file, JSON.stringify(obj, null, 2));
}
function readKeys() { return readJson(KEYS_FILE) || []; }
function writeKeys(keys) { writeJson(KEYS_FILE, keys); }
function readChats() { return readJson(CHATS_FILE) || []; }
function writeChats(chats) { writeJson(CHATS_FILE, chats); }
function nextId(arr) {
  let max = 0;
  for (let i = 0; i < arr.length; i++) if (arr[i].id && arr[i].id > max) max = arr[i].id;
  return max + 1;
}

// ---- HTTP helper para falar com as APIs ----
function apiRequest(url, options, bodyBuf) {
  return new Promise((resolve, reject) => {
    let u;
    try { u = new URL(url); } catch (e) { return reject(new Error('URL inválida: ' + url)); }
    const mod = u.protocol === 'https:' ? https : http;
    const req = mod.request({
      protocol: u.protocol,
      hostname: u.hostname,
      port: u.port || (u.protocol === 'https:' ? 443 : 80),
      path: u.pathname + (u.search || ''),
      method: options.method || 'GET',
      headers: options.headers || {}
    }, (res) => {
      const chunks = [];
      res.on('data', c => chunks.push(c));
      res.on('end', () => resolve({ status: res.statusCode || 0, data: Buffer.concat(chunks).toString('utf8') }));
    });
    req.on('error', e => reject(e));
    if (bodyBuf) req.write(bodyBuf);
    req.end();
  });
}

// Detecta se um modelo aceita imagem.
// OpenRouter: campo modalities com 'image'. Demais: heurística no nome.
function detectVision(model, provider) {
  if (provider === 'OpenRouter') {
    // Confia em modalities do /models se presente; o servidor checa isso no fetchModels.
    return false; // preenchido abaixo pelo campo modalities
  }
  const n = String(model.id || model || '').toLowerCase();
  return /(vision|vl|llava|gemini|4o|omni|qwen3?-?vl|claude.*vision|gpt-4o|pixtral|nano-omni)/.test(n);
}

// Extrai a lista de modelos [{id, vision}] da resposta /models (OpenAI-compatible).
function parseModels(body, provider) {
  const list = [];
  try {
    const obj = JSON.parse(body);
    const arr = (obj && obj.data) ? obj.data : (obj && obj.models) ? obj.models : null;
    if (Array.isArray(arr)) {
      for (const m of arr) {
        const id = m.id || m.model || null;
        if (!id) continue;
        let vision = false;
        // OpenRouter: modalities contém 'image'
        if (provider === 'OpenRouter' && Array.isArray(m.modalities) && m.modalities.indexOf('image') !== -1) {
          vision = true;
        } else {
          vision = detectVision(id, provider);
        }
        list.push({ id: String(id), vision: vision });
      }
    }
  } catch (e) { /* resposta não-JSON */ }
  return list;
}

// Busca os modelos de uma chave chamando GET {base}/models.
async function fetchModels(prov, key, custom) {
  let base;
  if (custom && custom.url) {
    base = custom.url;
  } else {
    base = PROVIDERS[prov];
    if (!base) throw new Error('Provedor desconhecido: ' + prov);
  }
  base = String(base).replace(/\/+$/, '');
  const url = base + '/models';
  const headers = { 'Content-Type': 'application/json' };
  if (key) headers['Authorization'] = 'Bearer ' + key;
  const r = await apiRequest(url, { method: 'GET', headers: headers }, null);
  if (r.status >= 400) {
    throw new Error('Falha ao buscar modelos (HTTP ' + r.status + '): ' + r.data.slice(0, 200));
  }
  let models = parseModels(r.data, prov);
  // Se o provedor Personalizado veio com lista manual, usa ela (mas preserva vision manual).
  if (custom && custom.manual && custom.manual.length) {
    const manual = [];
    for (const mId of custom.manual) {
      const trimmed = String(mId).trim();
      if (!trimmed) continue;
      const found = models.filter(x => x.id === trimmed)[0];
      manual.push(found ? found : { id: trimmed, vision: detectVision(trimmed, prov) });
    }
    if (manual.length) models = manual;
  }
  return models;
}

// ---- Configurações da requisição de chat ----
function chatConfig(prov, custom) {
  let base;
  if (custom && custom.url) base = custom.url;
  else base = PROVIDERS[prov];
  return String(base).replace(/\/+$/, '') + '/chat/completions';
}

// Monta o corpo multimodal (com imagem se houver).
function buildChatBody(model, messages, imageBase64) {
  const openaiMsgs = [];
  for (let i = 0; i < messages.length; i++) {
    const m = messages[i];
    if (typeof m === 'string') {
      openaiMsgs.push({ role: 'user', content: m });
    } else if (m && typeof m === 'object') {
      openaiMsgs.push({ role: m.role || 'user', content: m.content });
    }
  }
  // Anexa a imagem à última mensagem do usuário, se houver.
  if (imageBase64) {
    for (let i = openaiMsgs.length - 1; i >= 0; i--) {
      if (openaiMsgs[i].role === 'user') {
        const prev = openaiMsgs[i].content;
        openaiMsgs[i].content = [
          { type: 'text', text: typeof prev === 'string' ? prev : '' },
          { type: 'image_url', image_url: { url: 'data:image/jpeg;base64,' + imageBase64 } }
        ];
        break;
      }
    }
  }
  return {
    model: model,
    messages: openaiMsgs,
    stream: false
  };
}

// ---- Leitor de corpo JSON ----
function readBody(req) {
  return new Promise((resolve) => {
    const chunks = [];
    req.on('data', c => chunks.push(c));
    req.on('end', () => {
      const raw = Buffer.concat(chunks).toString('utf8');
      let obj = null;
      try { obj = JSON.parse(raw); } catch (e) { obj = null; }
      resolve(obj);
    });
  });
}

// ---- Helpers de resposta ----
function sendJSON(res, code, obj) {
  res.writeHead(code, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify(obj));
}
function sendFile(res, filePath) {
  fs.readFile(filePath, (err, data) => {
    if (err) { res.writeHead(404); res.end('Not found'); return; }
    const ext = path.extname(filePath).toLowerCase();
    const ctype = ext === '.js' ? 'application/javascript'
      : ext === '.css' ? 'text/css'
      : ext === '.html' ? 'text/html; charset=utf-8'
      : ext === '.png' ? 'image/png'
      : ext === '.svg' ? 'image/svg+xml'
      : 'application/octet-stream';
    res.writeHead(200, { 'Content-Type': ctype });
    res.end(data);
  });
}

// ---- Roteador ----
const server = http.createServer(async (req, res) => {
  // CORS liberado para a rede local (qualquer origem na intranet).
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') { res.writeHead(204); res.end(); return; }

  const url = new URL(req.url, 'http://localhost');
  const pathname = url.pathname;

  try {
    // --- Buscar modelos (sem salvar chave) ---
    if (req.method === 'POST' && pathname === '/models') {
      const body = await readBody(req);
      if (!body || !body.key) { sendJSON(res, 400, { error: 'Chave vazia' }); return; }
      let prov = body.prov, custom = body.custom || null;
      if (prov === 'Personalizado') {
        if (!custom || !custom.url) { sendJSON(res, 400, { error: 'Personalizado exige URL base' }); return; }
      }
      try {
        const models = await fetchModels(body.prov, body.key, custom);
        sendJSON(res, 200, { models: models });
      } catch (e) {
        sendJSON(res, 200, { error: String(e.message) });
      }
      return;
    }

    // --- Chaves ---
    if (req.method === 'GET' && pathname === '/keys') {
      const keys = readKeys().map(k => ({
        id: k.id, prov: k.prov, name: k.name,
        keyTail: k.key ? String(k.key).slice(-4) : '',
        models: k.models || []
      }));
      sendJSON(res, 200, { keys: keys });
      return;
    }
    if (req.method === 'POST' && pathname === '/keys') {
      const body = await readBody(req);
      if (!body || !body.key) { sendJSON(res, 400, { error: 'Chave vazia' }); return; }
      let prov = body.prov, custom = body.custom || null;
      if (prov === 'Personalizado') {
        if (!custom || !custom.url || !body.name) { sendJSON(res, 400, { error: 'Personalizado exige nome e URL base' }); return; }
        prov = body.name;
      }
      let models = [];
      try {
        models = await fetchModels(prov, body.key, custom);
      } catch (e) {
        // Busca falhou (chave inválida / sem rede). Guarda com lista vazia e informa.
        const keys = readKeys();
        const id = nextId(keys);
        keys.push({ id: id, prov: prov, name: body.name || prov, key: body.key, custom: custom, models: [] });
        writeKeys(keys);
        sendJSON(res, 200, { id: id, prov: prov, name: body.name || prov, keyTail: String(body.key).slice(-4), models: [], error: String(e.message) });
        return;
      }
      const keys = readKeys();
      const id = nextId(keys);
      keys.push({ id: id, prov: prov, name: body.name || prov, key: body.key, custom: custom, models: models });
      writeKeys(keys);
      sendJSON(res, 200, { id: id, prov: prov, name: body.name || prov, keyTail: String(body.key).slice(-4), models: models });
      return;
    }
    if (req.method === 'DELETE' && /^\/keys\/\d+$/.test(pathname)) {
      const id = parseInt(pathname.split('/')[2], 10);
      const keys = readKeys().filter(k => k.id !== id);
      writeKeys(keys);
      sendJSON(res, 200, { ok: true });
      return;
    }

    // --- Conversas ---
    if (req.method === 'GET' && pathname === '/chats') {
      const chats = readChats().map(c => ({ id: c.id, title: c.title, date: c.date, keyId: c.keyId, model: c.model }));
      sendJSON(res, 200, { chats: chats });
      return;
    }
    if (req.method === 'GET' && /^\/chats\/\d+$/.test(pathname)) {
      const id = parseInt(pathname.split('/')[2], 10);
      const chats = readChats();
      const c = chats.filter(x => x.id === id)[0];
      if (!c) { sendJSON(res, 404, { error: 'Conversa não encontrada' }); return; }
      sendJSON(res, 200, { chat: c });
      return;
    }
    if (req.method === 'POST' && pathname === '/chats') {
      const body = await readBody(req);
      if (!body || !body.chat) { sendJSON(res, 400, { error: 'Dados inválidos' }); return; }
      const chats = readChats();
      const chat = body.chat;
      if (!chat.id) chat.id = nextId(chats);
      const idx = chats.findIndex(x => x.id === chat.id);
      if (idx !== -1) chats[idx] = chat; else chats.push(chat);
      writeChats(chats);
      sendJSON(res, 200, { chat: chat });
      return;
    }
    if (req.method === 'DELETE' && /^\/chats\/\d+$/.test(pathname)) {
      const id = parseInt(pathname.split('/')[2], 10);
      const chats = readChats().filter(c => c.id !== id);
      writeChats(chats);
      sendJSON(res, 200, { ok: true });
      return;
    }

    // --- Chat (enviar mensagem) ---
    if (req.method === 'POST' && pathname === '/chat') {
      const body = await readBody(req);
      if (!body || !body.keyId || !body.model) { sendJSON(res, 400, { error: 'Faltam keyId/model' }); return; }
      const keys = readKeys();
      const k = keys.filter(x => x.id === body.keyId)[0];
      if (!k) { sendJSON(res, 404, { error: 'Chave não encontrada' }); return; }
      const endpoint = chatConfig(k.prov, k.custom);
      const chatBody = buildChatBody(body.model, body.messages, body.imageBase64);
      const payload = JSON.stringify(chatBody);
      const headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ' + k.key
      };
      const r = await apiRequest(endpoint, { method: 'POST', headers: headers }, Buffer.from(payload, 'utf8'));
      if (r.status >= 400) {
        let msg = 'Erro da API (HTTP ' + r.status + ')';
        try {
          const j = JSON.parse(r.data);
          msg += ': ' + (j.error && j.error.message ? j.error.message : r.data.slice(0, 200));
        } catch (e) { msg += ': ' + r.data.slice(0, 200); }
        sendJSON(res, 200, { error: msg });
        return;
      }
      // Extrai o texto da resposta OpenAI.
      let reply = null;
      try {
        const j = JSON.parse(r.data);
        if (j.choices && j.choices[0] && j.choices[0].message && j.choices[0].message.content) {
          reply = j.choices[0].message.content;
        }
      } catch (e) { /* não-JSON */ }
      if (reply === null) { sendJSON(res, 200, { error: 'Resposta vazia ou formato inesperado.' }); return; }
      sendJSON(res, 200, { reply: reply });
      return;
    }

    // --- Arquivos estáticos (frontend) ---
    if (req.method === 'GET') {
      let filePath;
      if (pathname === '/' || pathname === '/index.html') filePath = path.join(WEB_DIR, 'index.html');
      else if (pathname === '/app.js') filePath = path.join(WEB_DIR, 'app.js');
      else filePath = path.join(WEB_DIR, pathname.replace(/^\/+/, ''));
      // Segurança: não deixa escapar do diretório web.
      const resolved = path.resolve(filePath);
      if (!resolved.startsWith(path.resolve(WEB_DIR))) { res.writeHead(403); res.end('Forbidden'); return; }
      if (!fs.existsSync(resolved) || fs.statSync(resolved).isDirectory()) { res.writeHead(404); res.end('Not found'); return; }
      sendFile(res, resolved);
      return;
    }

    sendJSON(res, 404, { error: 'Rota não encontrada' });
  } catch (e) {
    sendJSON(res, 500, { error: 'Erro interno: ' + (e.message || String(e)) });
  }
});

server.listen(PORT, '0.0.0.0', () => {
  console.log('Brain Max servidor ouvindo em 0.0.0.0:' + PORT);
  console.log('Abra no iPad:  http://SEU-IP:' + PORT + '  (sem HTTPS)');
});