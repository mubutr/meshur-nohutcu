"""quests.json'a Bölüm 4 ve 5'i ekler (tekrar çalıştırılabilir; var olanı değiştirir)."""
import json
from pathlib import Path

p = Path(__file__).resolve().parent.parent / "assets" / "data" / "quests.json"
j = json.loads(p.read_text(encoding="utf-8"))

chapters = {c["id"]: c for c in j["chapters"]}
chapters[4] = {"id": 4, "title": "Sipariş Kapında", "subtitle": "Paket servis ve arka bahçe", "intro": "c4_intro", "outro": "c4_outro",
               "quests": [f"c4q{i}" for i in range(1, 8)], "reward": {"money": 1500, "stars": 5}}
chapters[5] = {"id": 5, "title": "Kayıp Tandır Taşı", "subtitle": "Soruşturma zamanı", "intro": "c5_intro", "outro": "c5_outro",
               "quests": [f"c5q{i}" for i in range(1, 8)], "reward": {"money": 3000, "stars": 6}}
j["chapters"] = [chapters[k] for k in sorted(chapters)]

Q = j["quests"]
Q.update({
    "c4q1": {"title": "Arka Bahçe", "desc": "Arka bahçeye tohum ek, sula ve 8 birim ürün hasat et. (Gün sonunda Bahçe.)",
             "objectives": [{"type": "harvest", "target": 8}], "reward": {"money": 300, "stars": 1}},
    "c4q2": {"title": "Parsel Açılsın", "desc": "Bahçeye yeni bir parsel aç (Yükseltmeler).",
             "objectives": [{"type": "upgrade", "target": 1, "filter": {"id": "parsel", "level": 1}}], "reward": {"money": 400, "stars": 1}},
    "c4q3": {"title": "İlk Paketler", "desc": "Kapında'dan düşen 4 paket siparişini teslim et. Dürümü sar, sağdaki sipariş kartına dokun; kurye alır.",
             "objectives": [{"type": "deliver", "target": 4}], "reward": {"money": 400, "stars": 1}},
    "c4q4": {"title": "Zamanında Teslimat", "desc": "10 paketi zamanında teslim et.",
             "objectives": [{"type": "deliver", "target": 10, "filter": {"onTime": True}}], "reward": {"money": 600, "stars": 1}},
    "c4q5": {"title": "Yeşil Parmaklar", "desc": "Toplam 12 birim maydanoz hasat et.",
             "objectives": [{"type": "harvest", "target": 12, "filter": {"crop": "maydanoz"}}], "reward": {"money": 500, "stars": 1}},
    "c4q6": {"title": "Dağıtım Motoru", "desc": "Dağıtım Motoru'nu al (Yükseltmeler): kurye sıklaşır, ısı kutusu artar.",
             "objectives": [{"type": "upgrade", "target": 1, "filter": {"id": "dagitim", "level": 1}}], "reward": {"money": 600, "stars": 1}},
    "c4q7": {"title": "Kapında'ya Karşı", "desc": "Kalaycı'nın zincirine inat: toplam 9000 ₺ kazan.",
             "objectives": [{"type": "earn", "target": 9000}], "reward": {"money": 900, "stars": 2}},

    "c5q1": {"title": "Boş Kalan Yer", "desc": "Soruşturma Defteri'nden bir ipucu bul. (Gün sonunda Soruşturma; gece 2 hamle hakkın var.)",
             "objectives": [{"type": "clue", "target": 1}], "reward": {"money": 500, "stars": 1}},
    "c5q2": {"title": "İz Sürücü", "desc": "Toplam 4 ipucu bul.",
             "objectives": [{"type": "clue", "target": 4}], "reward": {"money": 700, "stars": 1}, "scene": "c5_mid"},
    "c5q3": {"title": "Dükkân İşi Aksamasın", "desc": "Soruşturma sürerken 30 dürümü tam isabetle ver.",
             "objectives": [{"type": "serve", "target": 30, "filter": {"verdict": "great"}}], "reward": {"money": 800, "stars": 1}},
    "c5q4": {"title": "Tanıklar", "desc": "Toplam 8 ipucu bul.",
             "objectives": [{"type": "clue", "target": 8}], "reward": {"money": 900, "stars": 1}},
    "c5q5": {"title": "Masraf Büyük", "desc": "Soruşturma masrafı için toplam 10000 ₺ kazan.",
             "objectives": [{"type": "earn", "target": 10000}], "reward": {"money": 1000, "stars": 1}},
    "c5q6": {"title": "Suçlama", "desc": "Yeterli kanıtı topla ve doğru kişiyi suçla.",
             "objectives": [{"type": "clue", "target": 1, "filter": {"id": "solved"}}], "reward": {"money": 1500, "stars": 2}, "scene": "c5_solved"},
    "c5q7": {"title": "Tandır Taşı Yerinde", "desc": "Bir günde en az 12 müşteriye servis yap, memnuniyet %88'in üstünde olsun.",
             "objectives": [{"type": "day_rep", "target": 88, "filter": {"minServed": 12}}], "reward": {"money": 1500, "stars": 2}},
})

p.write_text(json.dumps(j, ensure_ascii=False, indent=1), encoding="utf-8")
print(len(j["chapters"]), "bölüm,", len(Q), "görev")
