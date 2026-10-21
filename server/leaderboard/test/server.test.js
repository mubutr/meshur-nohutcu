'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { Store, sign, WEEK_MS } = require('../store');
const { createApp } = require('../server');

const dev = (n) => n.toString(16).padStart(16, '0');
const sub = (o) => ({ device: dev(1), run: 'abc123', day: 1, score: 100, name: 'Rafık', ...o });

test('geçerli skor kabul edilir, tekrar gönderim yinelenmez', () => {
  const s = new Store();
  assert.equal(s.submit(sub()).status, 200);
  const dup = s.submit(sub());
  assert.equal(dup.duplicate, true);
  const lb = s.leaderboard('all', dev(1));
  assert.equal(lb.entries.length, 1);
  assert.equal(lb.entries[0].score, 100);
  assert.equal(lb.entries[0].days, 1);
  assert.equal(lb.entries[0].mine, true);
});

test('girdi doğrulaması', () => {
  const s = new Store();
  for (const bad of [{ device: 'x' }, { run: 'ZZ' }, { day: 0 }, { day: 1.5 }, { score: -1 }, { score: '9' }, { name: 'a' }, { name: 12 }]) {
    assert.equal(s.submit(sub(bad)).status, 400, JSON.stringify(bad));
  }
  assert.equal(s.submit(null).status, 400);
});

test('makul olmayan skor ve gün atlama reddedilir', () => {
  const s = new Store({ maxDayScore: 500 });
  assert.equal(s.submit(sub({ score: 501 })).status, 422);
  assert.equal(s.submit(sub({ day: 3 })).status, 422, 'gün 1 gönderilmeden gün 3 olmaz');
  assert.equal(s.submit(sub({ day: 1 })).status, 200);
  assert.equal(s.submit(sub({ day: 2 })).status, 200);
  assert.equal(s.submit(sub({ day: 4 })).status, 422);
});

test('imza zorunlu olduğunda doğrulanır', () => {
  const s = new Store({ secret: 'gizli' });
  const b = sub();
  assert.equal(s.submit({ ...b, sig: '' }).status, 403);
  assert.equal(s.submit({ ...b, sig: sign('yanlis', b.device, b.run, b.day, b.score) }).status, 403);
  assert.equal(s.submit({ ...b, sig: sign('gizli', b.device, b.run, b.day, b.score) }).status, 200);
  // imza skora bağlı: skoru değiştirmek imzayı bozar
  const t = sub({ day: 2, score: 50 });
  assert.equal(s.submit({ ...t, score: 9000, sig: sign('gizli', t.device, t.run, t.day, t.score) }).status, 403);
});

test('haftalık tablo yalnızca son 7 günü sayar; sıralama ve kendi sıran', () => {
  let t = 1_000_000_000_000;
  const s = new Store({ now: () => t });
  s.submit(sub({ device: dev(1), name: 'Eski', score: 900 }));
  t += WEEK_MS + 1000; // 1. cihazın kaydı haftadan eskileşti
  s.submit(sub({ device: dev(2), name: 'Orta', score: 300 }));
  s.submit(sub({ device: dev(3), name: 'Üst', score: 700 }));
  const w = s.leaderboard('week', dev(2));
  assert.deepEqual(w.entries.map((e) => e.name), ['Üst', 'Orta']);
  assert.deepEqual(w.entries.map((e) => e.rank), [1, 2]);
  const a = s.leaderboard('all', '');
  assert.equal(a.entries[0].name, 'Eski');
});

test('ilk 20 dışındaki oyuncu "me" ile görünür', () => {
  const s = new Store();
  for (let i = 1; i <= 25; i++) s.submit(sub({ device: dev(i), name: `Oyuncu${i}`, score: 1000 - i }));
  const lb = s.leaderboard('all', dev(25));
  assert.equal(lb.entries.length, 20);
  assert.equal(lb.me.rank, 25);
  assert.equal(lb.me.name, 'Oyuncu25');
});

test('takma ad temizlenir', () => {
  const s = new Store();
  s.submit(sub({ name: '  <b>Rafık</b>\n\t"x"  ' }));
  assert.equal(s.leaderboard('all', '').entries[0].name, 'bRafık/bx');
});

test('veri dosyaya yazılır ve yeniden açılınca korunur', () => {
  const file = path.join(fs.mkdtempSync(path.join(os.tmpdir(), 'lb-')), 'd.json');
  const a = new Store({ file });
  a.submit(sub({ score: 250 }));
  const b = new Store({ file });
  assert.equal(b.leaderboard('all', '').entries[0].score, 250);
  assert.equal(b.submit(sub({ day: 2 })).status, 200, 'gün sırası da yüklendi');
});

async function withServer(opts, fn) {
  const server = createApp({ store: new Store(opts.store), ...opts.app });
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  const base = `http://127.0.0.1:${server.address().port}`;
  try {
    await fn(base);
  } finally {
    await new Promise((r) => server.close(r));
  }
}

test('HTTP: POST /scores ve GET /leaderboard', async () => {
  await withServer({ store: {}, app: {} }, async (base) => {
    const post = (b) => fetch(`${base}/scores`, { method: 'POST', body: JSON.stringify(b) });
    assert.equal((await post(sub())).status, 200);
    assert.equal((await fetch(`${base}/scores`, { method: 'POST', body: '{bozuk' })).status, 400);
    const r = await fetch(`${base}/leaderboard?period=all&device=${dev(1)}`);
    assert.equal(r.headers.get('access-control-allow-origin'), '*');
    const j = await r.json();
    assert.equal(j.entries[0].name, 'Rafık');
    assert.equal(j.entries[0].mine, true);
    assert.equal((await fetch(`${base}/nope`)).status, 404);
  });
});

test('HTTP: büyük gövde ve hız sınırı', async () => {
  await withServer({ store: {}, app: {} }, async (base) => {
    const big = await fetch(`${base}/scores`, { method: 'POST', body: 'x'.repeat(5000) }).catch(() => ({ status: 413 }));
    assert.equal(big.status, 413);
    let last = 0;
    for (let i = 0; i < 260; i++) last = (await fetch(`${base}/health`)).status;
    assert.equal(last, 429);
  });
});

const prof = (o) => ({ device: dev(7), name: 'Hösün', money: 500, diamonds: 3, day: 4, chapter: 1, totalScore: 900, ack: 0, ...o });

test('profil: istemci durumu kaydedilir, yönetici düzenlemesi patch olarak döner, ack ile kapanır', () => {
  const s = new Store();
  assert.equal(s.profile(prof()).status, 200);
  assert.equal(s.adminList()[0].money, 500);
  assert.deepEqual(s.adminEdit(dev(7), { money: 9999, diamonds: 50 }), { status: 200, ok: true, rev: 1 });
  // henüz ack yok: istemcinin eski durumu sunucuyu ezmemeli, patch dönmeli
  const r1 = s.profile(prof({ money: 510 }));
  assert.equal(r1.patch.rev, 1);
  assert.equal(r1.patch.money, 9999);
  assert.equal(r1.patch.diamonds, 50);
  assert.equal(s.adminList()[0].money, 9999);
  // istemci uyguladı ve ack gönderdi
  const r2 = s.profile(prof({ money: 9999, diamonds: 50, ack: 1 }));
  assert.equal(r2.patch, null);
  assert.equal(s.adminList()[0].pending, false);
});

test('profil: doğrulama ve imza', () => {
  const s = new Store({ secret: 'gizli' });
  assert.equal(s.profile(prof()).status, 403);
  const { signProfile } = require('../store');
  const b = prof();
  b.sig = signProfile('gizli', b.device, b.money, b.diamonds, b.day, b.totalScore);
  assert.equal(s.profile(b).status, 200);
  assert.equal(new Store().profile(prof({ money: -1 })).status, 400);
  assert.equal(new Store().profile(prof({ device: 'x' })).status, 400);
});

test('yönetici: skor düzeltmesi sıralamaya yansır, silme oyuncuyu kaldırır', () => {
  const s = new Store();
  s.submit(sub({ device: dev(7), name: 'Hösün', score: 100 }));
  s.profile(prof());
  assert.equal(s.adminEdit(dev(7), { scoreAll: 5000 }).ok, true);
  assert.equal(s.leaderboard('all', dev(7)).entries[0].score, 5000);
  assert.equal(s.adminEdit(dev(7), { name: 'X' }).status, 400);
  assert.equal(s.adminEdit(dev(7), { money: -5 }).status, 400);
  assert.equal(s.adminEdit(dev(99), { money: 5 }).status, 404);
  assert.equal(s.adminDelete(dev(7)).ok, true);
  assert.equal(s.leaderboard('all', '').entries.length, 0);
});

test('HTTP: /admin anahtarsız kapalı, anahtarla çalışır', async () => {
  await withServer({ store: {}, app: { adminToken: 'tok123' } }, async (base) => {
    assert.equal((await fetch(`${base}/profile`, { method: 'POST', body: JSON.stringify(prof()) })).status, 200);
    assert.equal((await fetch(`${base}/admin/api/players`)).status, 401);
    const h = { 'x-admin-token': 'tok123' };
    const list = await (await fetch(`${base}/admin/api/players`, { headers: h })).json();
    assert.equal(list.players.length, 1);
    const ed = await fetch(`${base}/admin/api/players/${dev(7)}`, { method: 'POST', headers: h, body: JSON.stringify({ money: 123 }) });
    assert.equal(ed.status, 200);
    const p = await (await fetch(`${base}/profile`, { method: 'POST', body: JSON.stringify(prof()) })).json();
    assert.equal(p.patch.money, 123);
    const page = await fetch(`${base}/admin`);
    assert.equal(page.status, 200);
    assert.match(await page.text(), /Meşhur Nohutçu/);
  });
  await withServer({ store: {}, app: {} }, async (base) => {
    assert.equal((await fetch(`${base}/admin`)).status, 404);
    assert.equal((await fetch(`${base}/admin/api/players`, { headers: { 'x-admin-token': '' } })).status, 404);
  });
});
