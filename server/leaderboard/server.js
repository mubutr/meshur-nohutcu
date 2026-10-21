'use strict';
// Bağımlılıksız Node sunucusu.  Çalıştırma:  node server.js
// Ortam değişkenleri: PORT (8787), DATA_FILE (./data.json), SECRET, MAX_DAY_SCORE (10000), TRUST_PROXY=1
const http = require('node:http');
const path = require('node:path');
const fs = require('node:fs');
const crypto = require('node:crypto');
const { Store } = require('./store');

const BODY_LIMIT = 2048;
const RATE_PER_MIN = 240; // oyun her 3 sn'de bir eşitler + yönetim sayfası

function createApp({ store, trustProxy = false, now = () => Date.now(), adminToken = '' }) {
  const hits = new Map(); // ip -> {start, n}
  const limited = (ip) => {
    const t = now();
    const h = hits.get(ip);
    if (!h || t - h.start > 60000) {
      hits.set(ip, { start: t, n: 1 });
      return false;
    }
    h.n += 1;
    return h.n > RATE_PER_MIN;
  };

  const send = (res, status, obj) => {
    const body = JSON.stringify(obj);
    res.writeHead(status, {
      'content-type': 'application/json; charset=utf-8',
      'access-control-allow-origin': '*',
      'access-control-allow-headers': 'content-type',
      'access-control-allow-methods': 'GET,POST,OPTIONS',
      'cache-control': 'no-store',
    });
    res.end(body);
  };

  return http.createServer((req, res) => {
    const fwd = trustProxy ? String(req.headers['x-forwarded-for'] || '').split(',')[0].trim() : '';
    const ip = fwd || req.socket.remoteAddress || '?';
    const url = new URL(req.url, 'http://x');
    if (req.method === 'OPTIONS') return send(res, 204, {});
    if (limited(ip)) return send(res, 429, { ok: false, reason: 'çok sık' });

    if (req.method === 'GET' && url.pathname === '/leaderboard') {
      const period = url.searchParams.get('period') === 'all' ? 'all' : 'week';
      const device = url.searchParams.get('device') || '';
      return send(res, 200, store.leaderboard(period, /^[0-9a-f]{16,64}$/.test(device) ? device : ''));
    }
    if (req.method === 'GET' && url.pathname === '/health') return send(res, 200, { ok: true });

    const readBody = (cb) => {
      let size = 0;
      const chunks = [];
      let dead = false;
      req.on('data', (c) => {
        size += c.length;
        if (size > BODY_LIMIT && !dead) {
          dead = true;
          send(res, 413, { ok: false, reason: 'büyük' });
          req.destroy();
        } else if (!dead) chunks.push(c);
      });
      req.on('end', () => {
        if (dead) return;
        let body;
        try {
          body = JSON.parse(Buffer.concat(chunks).toString('utf8') || '{}');
        } catch {
          return send(res, 400, { ok: false, reason: 'json' });
        }
        cb(body);
      });
    };

    // oyun -> sunucu: durum bildirimi; yanıtta yönetici düzenlemesi (varsa)
    if (req.method === 'POST' && url.pathname === '/profile') {
      return readBody((body) => {
        const r = store.profile(body);
        send(res, r.status, { ok: r.ok, reason: r.reason, patch: r.patch || null });
      });
    }

    // ---- yönetim (test amaçlı; ADMIN_TOKEN verilmezse kapalıdır)
    if (url.pathname === '/admin' && req.method === 'GET') {
      if (!adminToken) return send(res, 404, { ok: false });
      res.writeHead(200, { 'content-type': 'text/html; charset=utf-8', 'cache-control': 'no-store' });
      return res.end(fs.readFileSync(path.join(__dirname, 'admin.html'), 'utf8'));
    }
    if (url.pathname.startsWith('/admin/api/')) {
      if (!adminToken) return send(res, 404, { ok: false });
      const given = String(req.headers['x-admin-token'] || '');
      const a = Buffer.from(given);
      const b = Buffer.from(adminToken);
      if (a.length !== b.length || !crypto.timingSafeEqual(a, b)) return send(res, 401, { ok: false, reason: 'yetkisiz' });
      if (req.method === 'GET' && url.pathname === '/admin/api/players') return send(res, 200, { ok: true, players: store.adminList() });
      const m = url.pathname.match(/^\/admin\/api\/players\/([0-9a-f]{16,64})(\/delete)?$/);
      if (m && req.method === 'POST') {
        if (m[2]) {
          const r = store.adminDelete(m[1]);
          return send(res, r.status, { ok: r.ok, reason: r.reason });
        }
        return readBody((body) => {
          const r = store.adminEdit(m[1], body);
          send(res, r.status, { ok: r.ok, reason: r.reason, rev: r.rev });
        });
      }
      return send(res, 404, { ok: false });
    }

    if (req.method === 'POST' && url.pathname === '/scores') {
      let size = 0;
      const chunks = [];
      let dead = false;
      req.on('data', (c) => {
        size += c.length;
        if (size > BODY_LIMIT && !dead) {
          dead = true;
          send(res, 413, { ok: false, reason: 'büyük' });
          req.destroy();
        } else if (!dead) chunks.push(c);
      });
      req.on('end', () => {
        if (dead) return;
        let body;
        try {
          body = JSON.parse(Buffer.concat(chunks).toString('utf8'));
        } catch {
          return send(res, 400, { ok: false, reason: 'json' });
        }
        const r = store.submit(body);
        send(res, r.status, { ok: r.ok, reason: r.reason, duplicate: r.duplicate });
      });
      return;
    }
    send(res, 404, { ok: false });
  });
}

if (require.main === module) {
  const store = new Store({
    file: process.env.DATA_FILE || path.join(__dirname, 'data.json'),
    secret: process.env.SECRET || '',
    maxDayScore: Number(process.env.MAX_DAY_SCORE) || 10000,
  });
  const port = Number(process.env.PORT) || 8787;
  const adminToken = process.env.ADMIN_TOKEN || '';
  createApp({ store, trustProxy: process.env.TRUST_PROXY === '1', adminToken }).listen(port, () => {
    console.log(`Sıralama sunucusu http://localhost:${port}  (imza: ${store.secret ? 'açık' : 'KAPALI'})`);
    console.log(adminToken ? `Yönetim sayfası (TEST): http://localhost:${port}/admin   (anahtar: ADMIN_TOKEN)` : 'Yönetim sayfası kapalı (ADMIN_TOKEN verilmedi).');
  });
}

module.exports = { createApp };
