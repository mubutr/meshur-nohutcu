"""Kısa ses efektlerini sıfırdan üretir (yalnızca standart kütüphane; telifsiz, özgün).

Kullanım:  python tools/gen_sfx.py assets/sfx
"""
import math
import random
import struct
import sys
import wave
from pathlib import Path

SR = 22050


def env(i, n, attack=0.01, release=0.2):
    t = i / SR
    d = n / SR
    a = min(1.0, t / attack) if attack > 0 else 1.0
    r = min(1.0, max(0.0, (d - t) / release)) if release > 0 else 1.0
    return a * r


def tone(freq, dur, vol=0.5, attack=0.005, release=0.15, shape="sine", slide=0.0):
    n = int(SR * dur)
    out = []
    phase = 0.0
    for i in range(n):
        f = freq + slide * (i / n)
        phase += 2 * math.pi * f / SR
        if shape == "sine":
            s = math.sin(phase)
        elif shape == "tri":
            s = 2 / math.pi * math.asin(math.sin(phase))
        else:  # yumuşak kare
            s = math.tanh(3 * math.sin(phase))
        out.append(vol * s * env(i, n, attack, release))
    return out


def noise(dur, vol=0.3, attack=0.002, release=0.08, lp=0.3):
    rnd = random.Random(7)
    n = int(SR * dur)
    out, y = [], 0.0
    for i in range(n):
        y += lp * (rnd.uniform(-1, 1) - y)  # basit alçak geçiren
        out.append(vol * y * env(i, n, attack, release))
    return out


def mix(*parts):
    n = max(len(p) for p in parts)
    return [sum(p[i] for p in parts if i < len(p)) for i in range(n)]


def seq(*parts, gap=0.0):
    out = []
    for p in parts:
        out += p + [0.0] * int(SR * gap)
    return out


def delay(p, sec):
    return [0.0] * int(SR * sec) + p


def save(path, samples):
    peak = max(1e-6, max(abs(s) for s in samples))
    scale = min(1.0, 0.9 / peak)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s * scale)) * 32767)) for s in samples))


def kepenk(dur=2.6):
    """Kepenk (rulo metal kapı) açılışı: alçak gümbürtü + şeritlerin düzensiz tıkırtısı + sonda tok durma sesi."""
    rnd = random.Random(3)
    n = int(SR * dur)
    out = [0.0] * n
    y = 0.0
    for i in range(n):  # gümbürtü
        t = i / SR
        y += 0.02 * (rnd.uniform(-1, 1) - y)
        out[i] += 0.5 * y * (0.6 + 0.4 * math.sin(2 * math.pi * 7 * t)) * env(i, n, 0.15, 0.25)
    t = 0.05
    while t < dur - 0.35:  # şerit tıkırtıları
        gap = 0.07 + 0.025 * math.sin(t * 5) + rnd.uniform(-0.01, 0.01)
        k = int(t * SR)
        ln = int(0.012 * SR)
        yy = 0.0
        for j in range(ln):
            if k + j >= n:
                break
            yy += 0.6 * (rnd.uniform(-1, 1) - yy)
            out[k + j] += 0.35 * (rnd.uniform(-1, 1) * 0.7 + yy * 0.3) * math.exp(-j / (ln * 0.25)) * (0.6 + 0.4 * rnd.random())
        f = 900 + rnd.choice([0, 180, 420])
        for j in range(int(0.05 * SR)):
            if k + j >= n:
                break
            out[k + j] += 0.05 * math.sin(2 * math.pi * f * j / SR) * math.exp(-j / (0.05 * SR * 0.2))
        t += gap
    k = int((dur - 0.3) * SR)  # sonda "tak"
    for i, v in enumerate(mix(tone(95, 0.22, 0.6, 0.001, 0.18, "sine", slide=-30), noise(0.03, 0.5, 0.0005, 0.02, lp=0.7))):
        if k + i < n:
            out[k + i] += v
    return out


def main(out_dir):
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    fx = {
        # malzeme eklemek: yumuşak "pıt"
        "pop": mix(tone(520, 0.09, 0.5, 0.002, 0.08, "sine", slide=-180), noise(0.04, 0.12)),
        # ekmek: kısa hışırtı
        "bread": mix(noise(0.16, 0.35, 0.01, 0.12, lp=0.5), tone(180, 0.1, 0.15, 0.005, 0.08)),
        # sarma: hışırtı + tok vuruş
        "wrap": seq(noise(0.18, 0.4, 0.01, 0.14, lp=0.6), mix(tone(140, 0.12, 0.5, 0.002, 0.1, "tri"), noise(0.05, 0.2))),
        # para: iki ince çıngırak
        "coin": seq(tone(1320, 0.07, 0.35, 0.002, 0.06, "tri"), tone(1760, 0.18, 0.35, 0.002, 0.16, "tri")),
        # tam isabet: üçlü ferah akor
        "great": mix(tone(784, 0.35, 0.3, 0.005, 0.3, "tri"), delay(tone(988, 0.3, 0.3, 0.005, 0.25, "tri"), 0.07), delay(tone(1175, 0.4, 0.3, 0.005, 0.35, "tri"), 0.14)),
        # orta: tek yumuşak nota
        "ok": tone(660, 0.22, 0.4, 0.005, 0.18, "tri"),
        # hata / küsme: aşağı kayan nota
        "bad": tone(300, 0.35, 0.45, 0.005, 0.3, "sq", slide=-130),
        # müşteri geldi: kapı zili
        "bell": mix(tone(1568, 0.5, 0.25, 0.002, 0.45, "sine"), tone(2093, 0.4, 0.15, 0.002, 0.35, "sine")),
        # hasat / görev tamam: yukarı çıkan üç nota
        "quest": seq(tone(523, 0.1, 0.35, 0.004, 0.08, "tri"), tone(659, 0.1, 0.35, 0.004, 0.08, "tri"), tone(784, 0.28, 0.35, 0.004, 0.24, "tri")),
        # kepenk açılışı (günün başı)
        "kepenk": kepenk(),
        # sulama: su sesi
        "water": mix(noise(0.45, 0.4, 0.05, 0.3, lp=0.15), tone(900, 0.4, 0.06, 0.05, 0.3, "sine", slide=400)),
    }
    for name, s in fx.items():
        save(out / f"{name}.wav", s)
        print("yazıldı", name, f"{len(s) / SR:.2f}s")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "assets/sfx")
