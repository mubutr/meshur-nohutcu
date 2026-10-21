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

module.exports = { Store, sign, cleanName, TOP, WEEK_MS };
