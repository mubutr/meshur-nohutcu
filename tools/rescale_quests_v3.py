"""quests.json'u v3 ekonomisine uyarlar: hedefleri ölçekler ve yeni ürün/sos görevleri ekler.

Her zaman tools/data_backup/quests_v2.json'dan okur (tekrar çalıştırmak güvenlidir).
Çalıştır: python -I tools/rescale_quests_v3.py   (nohut-durumu klasöründe)
"""
import json
import math
from pathlib import Path

SRC = Path("tools/data_backup/quests_v2.json")
DST = Path("assets/data/quests.json")

# hedef türüne göre çarpan: müşteri sayısı ~1.7×, fiyatlar ~2.2× oldu
FACTOR = {"serve": 2.1, "riddle": 1.6, "earn": 4.2, "tip": 2.2}
MIN_SCALED = 4  # 1–3 gibi küçük "olay" hedefleri (maskeli, itfaiyeci) ölçeklenmez

j = json.loads(SRC.read_text(encoding="utf-8"))


def scale(o):
    f = FACTOR.get(o["type"])
    if f and o["target"] >= MIN_SCALED:
        t = o["target"] * f
        o["target"] = int(round(t / 5) * 5) if t >= 100 else int(math.ceil(t))


for q in j["quests"].values():
    for o in q["objectives"]:
        scale(o)

for t in j["daily"]:
    if t["type"] == "serve":
        t["targets"] = [int(math.ceil(x * 1.5)) for x in t["targets"]]

# ----------------------------------------------------------- yeni ürün / sos görevleri
NEW = {
    "c2q8": ("Soslu Sofra", "Soslu (ketçap, mayonez, sos…) 8 dürümü tam isabetle ver.",
             [{"type": "serve", "target": 8, "filter": {"verdict": "great", "sauce": True}}], 260, 1, 2),
    "c3q8": ("Dönerin Tadı", "Döner dürümü 6 kez tam isabetle ver. (Döner şişi yeni geldi.)",
             [{"type": "serve", "target": 6, "filter": {"verdict": "great", "wrap": "doner"}}], 350, 1, 3),
    "c4q8": ("Kavurma Ustası", "Kavurma dürümü 6 kez tam isabetle ver.",
             [{"type": "serve", "target": 6, "filter": {"verdict": "great", "wrap": "kavurma"}}], 450, 1, 4),
    "c4q9": ("Acılı Çiğ Köfte", "Çiğ köfte dürümü 6 kez tam isabetle ver.",
             [{"type": "serve", "target": 6, "filter": {"verdict": "great", "wrap": "cigkofte"}}], 450, 1, 4),
    "c5q8": ("Çıtır Çıtır", "Kızartma dürümü 6 kez tam isabetle ver.",
             [{"type": "serve", "target": 6, "filter": {"verdict": "great", "wrap": "kizartma"}}], 700, 1, 5),
    "c5q9": ("Sabah Çorbası", "Beyranı 4 kez tam isabetle ver.",
             [{"type": "serve", "target": 4, "filter": {"verdict": "great", "wrap": "beyran"}}], 800, 1, 5),
}
for qid, (title, desc, objs, money, stars, ch) in NEW.items():
    j["quests"][qid] = {"title": title, "desc": desc, "objectives": objs, "reward": {"money": money, "stars": stars}}
    chap = next(c for c in j["chapters"] if c["id"] == ch)
    chap["quests"].insert(len(chap["quests"]) - 1, qid)  # son (büyük) görevden önce

# ----------------------------------------------------------- yeni günlük görev şablonları
def daily(id, title, type_, targets, money, flt, **kw):
    j["daily"].append({"id": id, "title": title, "type": type_, "targets": targets, "money": money, "filter": flt, **kw})


daily("d_sauce", "{n} soslu dürüm ver", "serve", [3, 4, 6], [80, 110, 150], {"sauce": True}, minChapter=2)
daily("d_fried", "{n} kızartmalı dürüm ver", "serve", [2, 3, 4], [80, 110, 140], {"fried": True}, minChapter=2)
daily("d_doner", "{n} döner dürümü ver", "serve", [2, 3, 4], [110, 150, 190], {"wrap": "doner"}, minChapter=3)
daily("d_kavurma", "{n} kavurma dürümü ver", "serve", [2, 3], [130, 170], {"wrap": "kavurma"}, minChapter=4)
daily("d_cigkofte", "{n} çiğ köfte dürümü ver", "serve", [2, 3], [120, 160], {"wrap": "cigkofte"}, minChapter=4)
daily("d_kizartma", "{n} kızartma dürümü ver", "serve", [2, 3], [120, 160], {"wrap": "kizartma"}, minChapter=5)
daily("d_beyran", "{n} beyran ver", "serve", [1, 2], [150, 220], {"wrap": "beyran"}, minChapter=5)

DST.write_text(json.dumps(j, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print("quests.json güncellendi:", len(j["quests"]), "görev,", len(j["daily"]), "günlük şablon")
