'use strict';
// Sıralama verisi: bellekte tutulur, her değişiklikte JSON dosyasına atomik yazılır.
const fs = require('node:fs');
const crypto = require('node:crypto');

const WEEK_MS = 7 * 24 * 3600 * 1000;
const TOP = 20;

function cleanName(raw) {
  if (typeof raw !== 'string') return null;
  const n = raw.replace(/[\u0000-\u001f\u007f<>&"']/g, '').replace(/\s+/g, ' ').trim().slice(0, 16);
  return n.length >= 2 ? n : null;
}

function sign(secret, device, run, day, score) {
  return crypto.createHmac('sha256', secret).update(`${device}|${run}|${day}|${score}`).digest('hex');
}

function signProfile(secret, device, money, diamonds, day, totalScore) {
  return crypto.createHmac('sha256', secret).update(`${device}|${money}|${diamonds}|${day}|${totalScore}`).digest('hex');
}

function safeEqual(a, b) {
  const x = Buffer.from(String(a));
  const y = Buffer.from(String(b));
  return x.length === y.length && crypto.timingSafeEqual(x, y);
}

class Store {
  constructor({ file = null, secret = '', maxDayScore = 10000, now = () => Date.now() } = {}) {
    this.file = file;
    this.secret = secret;
    this.maxDayScore = maxDayScore;
    this.now = now;
    this.devices = new Map(); // id -> {name}
    this.scores = new Map(); // "device|run|day" -> {device, run, day, score, at}
    this.maxDay = new Map(); // "device|run" -> en yüksek gönderilen gün
    if (file && fs.existsSync(file)) this._load();
  }

  _load() {
    const j = JSON.parse(fs.readFileSync(this.file, 'utf8'));
    for (const [id, d] of Object.entries(j.devices || {})) this.devices.set(id, d);
    for (const s of j.scores || []) this._index(s);
  }

  _index(s) {
    this.scores.set(`${s.device}|${s.run}|${s.day}`, s);
    const k = `${s.device}|${s.run}`;
    this.maxDay.set(k, Math.max(this.maxDay.get(k) || 0, s.day));
  }

  _persist() {
    if (!this.file) return;
    const tmp = `${this.file}.tmp`;
    fs.writeFileSync(tmp, JSON.stringify({ devices: Object.fromEntries(this.devices), scores: [...this.scores.values()] }));
    fs.renameSync(tmp, this.file);
  }

  /** @returns {{status:number, ok:boolean, reason?:string, duplicate?:boolean}} */
  submit(b) {
    if (!b || typeof b !== 'object') return { status: 400, ok: false, reason: 'gövde' };
    const { device, run, day, score } = b;
    if (typeof device !== 'string' || !/^[0-9a-f]{16,64}$/.test(device)) return { status: 400, ok: false, reason: 'device' };
    if (typeof run !== 'string' || !/^[0-9a-f]{6,32}$/.test(run)) return { status: 400, ok: false, reason: 'run' };
    if (!Number.isInteger(day) || day < 1 || day > 3650) return { status: 400, ok: false, reason: 'day' };
    if (!Number.isInteger(score) || score < 0) return { status: 400, ok: false, reason: 'score' };
    const name = cleanName(b.name);
    if (!name) return { status: 400, ok: false, reason: 'name' };
    if (this.secret && !safeEqual(b.sig || '', sign(this.secret, device, run, day, score))) return { status: 403, ok: false, reason: 'sig' };
    if (score > this.maxDayScore) return { status: 422, ok: false, reason: 'makul olmayan skor' };

    const key = `${device}|${run}|${day}`;
    if (this.scores.has(key)) {
      this._rename(device, name);
      return { status: 200, ok: true, duplicate: true };
    }
    // gün atlanamaz: yeni gün, bu serinin en yüksek gününden en fazla 1 fazla olabilir
    if (day > (this.maxDay.get(`${device}|${run}`) || 0) + 1) return { status: 422, ok: false, reason: 'gün sırası' };

    this._index({ device, run, day, score, at: this.now() });
    this._rename(device, name, true);
    this._persist();
    return { status: 200, ok: true };
  }

  _rename(device, name, force = false) {
    const d = this.devices.get(device);
    if (!d || force || d.name !== name) {
      this.devices.set(device, { name });
      this._persist();
    }
  }

  /** İstemci durum bildirimi (para, elmas, gün, toplam puan). Yönetici düzenlemesi (patch) varsa onu döndürür. */
  profile(b) {
    if (!b || typeof b !== 'object') return { status: 400, ok: false, reason: 'gövde' };
    const { device } = b;
    if (typeof device !== 'string' || !/^[0-9a-f]{16,64}$/.test(device)) return { status: 400, ok: false, reason: 'device' };
    const int = (v, lo, hi) => Number.isInteger(v) && v >= lo && v <= hi;
    if (!int(b.money, 0, 1e9) || !int(b.diamonds, 0, 1e6) || !int(b.day, 1, 3650) || !int(b.totalScore, 0, 1e9)) return { status: 400, ok: false, reason: 'değer' };
    const chapter = int(b.chapter, 1, 20) ? b.chapter : 1;
    const ack = int(b.ack, 0, 1e9) ? b.ack : 0;
    if (this.secret && !safeEqual(b.sig || '', signProfile(this.secret, device, b.money, b.diamonds, b.day, b.totalScore))) return { status: 403, ok: false, reason: 'sig' };
    const d = this.devices.get(device) || { name: 'Çırak' };
    d.rev = d.rev || 0;
    const name = cleanName(b.name);
    if (ack >= d.rev) {
      // istemci son yönetici düzenlemesini aldı: bildirdiği durum geçerli
      d.money = b.money;
      d.diamonds = b.diamonds;
      d.day = b.day;
      d.chapter = chapter;
      d.totalScore = b.totalScore;
      d.patch = null;
      if (name) d.name = name;
    }
    d.seen = this.now();
    this.devices.set(device, d);
    this._persist();
    return { status: 200, ok: true, patch: d.patch && d.rev > ack ? { rev: d.rev, ...d.patch } : null };
  }

  _rawTotals(device) {
    let all = 0;
    let week = 0;
    const since = this.now() - WEEK_MS;
    for (const s of this.scores.values()) {
      if (s.device !== device) continue;
      all += s.score;
      if (s.at >= since) week += s.score;
    }
    return { all, week };
  }

  /** Yönetim sayfası listesi. */
  adminList() {
    const rows = [];
    for (const [id, d] of this.devices) {
      const raw = this._rawTotals(id);
      rows.push({
        device: id,
        name: d.name,
        money: d.money ?? null,
        diamonds: d.diamonds ?? null,
        day: d.day ?? null,
        chapter: d.chapter ?? null,
        totalScore: d.totalScore ?? null,
        scoreAll: Math.max(0, raw.all + (d.adjust || 0)),
        scoreWeek: Math.max(0, raw.week + (d.adjust || 0)),
        seen: d.seen || null,
        pending: Boolean(d.patch),
      });
    }
    return rows.sort((a, b) => (b.seen || 0) - (a.seen || 0));
  }

  /** Yönetici düzenlemesi: oyun bir sonraki eşitlemede alır ("anlık"). */
  adminEdit(device, f) {
    const d = this.devices.get(device);
    if (!d) return { status: 404, ok: false, reason: 'oyuncu yok' };
    const int = (v, lo, hi) => Number.isInteger(v) && v >= lo && v <= hi;
    const patch = {};
    if (f.money !== undefined) {
      if (!int(f.money, 0, 1e9)) return { status: 400, ok: false, reason: 'para' };
      patch.money = f.money;
    }
    if (f.diamonds !== undefined) {
      if (!int(f.diamonds, 0, 1e6)) return { status: 400, ok: false, reason: 'elmas' };
      patch.diamonds = f.diamonds;
    }
    if (f.day !== undefined) {
      if (!int(f.day, 1, 3650)) return { status: 400, ok: false, reason: 'gün' };
      patch.day = f.day;
    }
    if (f.scoreAll !== undefined) {
      if (!int(f.scoreAll, 0, 1e9)) return { status: 400, ok: false, reason: 'skor' };
      d.adjust = f.scoreAll - this._rawTotals(device).all; // sıralama toplamı istenen değere eşitlenir
      patch.totalScore = f.scoreAll;
    }
    if (f.name !== undefined) {
      const n = cleanName(f.name);
      if (!n) return { status: 400, ok: false, reason: 'ad' };
      d.name = n;
    }
    if (Object.keys(patch).length) {
      d.rev = (d.rev || 0) + 1;
      d.patch = { ...(d.patch || {}), ...patch };
      Object.assign(d, { money: patch.money ?? d.money, diamonds: patch.diamonds ?? d.diamonds, day: patch.day ?? d.day, totalScore: patch.totalScore ?? d.totalScore });
    }
    this._persist();
    return { status: 200, ok: true, rev: d.rev || 0 };
  }

  adminDelete(device) {
    if (!this.devices.delete(device)) return { status: 404, ok: false, reason: 'oyuncu yok' };
    for (const [k, v] of [...this.scores]) {
      if (v.device === device) this.scores.delete(k);
    }
    for (const k of [...this.maxDay.keys()]) {
      if (k.startsWith(`${device}|`)) this.maxDay.delete(k);
    }
    this._persist();
    return { status: 200, ok: true };
  }

  /** period: 'week' | 'all' */
  leaderboard(period, device) {
    const since = period === 'week' ? this.now() - WEEK_MS : 0;
    const agg = new Map();
    for (const s of this.scores.values()) {
      if (s.at < since) continue;
      const a = agg.get(s.device) || { device: s.device, score: 0, days: 0 };
      a.score += s.score;
      a.days += 1;
      agg.set(s.device, a);
    }
    // yönetici puan düzeltmesi (test amaçlı): toplamlara eklenir; yalnızca düzeltmesi olan oyuncu da listelenir
    for (const [id, d] of this.devices) {
      if (!d.adjust) continue;
      const a = agg.get(id) || { device: id, score: 0, days: 0 };
      a.score = Math.max(0, a.score + d.adjust);
      agg.set(id, a);
    }
    const sorted = [...agg.values()].sort((x, y) => y.score - x.score || x.days - y.days || (x.device < y.device ? -1 : 1));
    const mk = (a, i) => ({ rank: i + 1, name: (this.devices.get(a.device) || { name: 'Çırak' }).name, score: a.score, days: a.days, mine: a.device === device });
    const entries = sorted.slice(0, TOP).map(mk);
    let me = null;
    if (device && !entries.some((e) => e.mine)) {
      const i = sorted.findIndex((a) => a.device === device);
      if (i >= 0) me = mk(sorted[i], i);
    }
    return { entries, me };
  }
}

module.exports = { Store, sign, signProfile, cleanName, TOP, WEEK_MS };
