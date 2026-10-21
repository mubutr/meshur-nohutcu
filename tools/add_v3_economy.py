"""game.json'a v3 ekonomisini ekler (ürünler, soslar, maliyetler, marj, elmas yükseltmeleri, yeni dekor).

Çalıştır: python -I tools/add_v3_economy.py   (nohut-durumu klasöründe). Tekrar çalıştırmak güvenlidir.
"""
import json
from pathlib import Path

P = Path("assets/data/game.json")
j = json.loads(P.read_text(encoding="utf-8"))

j.pop("prices", None)
j["margin"] = 1.3  # satış fiyatı = malzeme maliyeti x 1.3  (%30 kâr)
j["costs"] = {"bread": 24, "bowl": 14, "piyaz": 12, "aci": 5, "fried": 18}

ALL = ["piyaz", "aci", "fried", "sauce", "sumak"]
j["products"] = [
    {"id": "nohut", "name": "Nohut Dürümü", "fillName": "nohut", "minChapter": 1, "unit": 18, "maxAmount": 3, "weight": 5, "allow": ALL,
     "desc": "Tırnaklı ekmeğin içine haşlanmış sıcak nohut, üstüne piyaz. Antep'in sabah dürümü."},
    {"id": "doner", "name": "Döner Dürümü", "fillName": "döner", "minChapter": 3, "unit": 44, "maxAmount": 2, "weight": 3, "allow": ALL,
     "desc": "Dikey şişten ince kesilmiş döner, tırnaklı ekmekte; piyaz ve sosla."},
    {"id": "kavurma", "name": "Kavurma Dürümü", "fillName": "kavurma", "minChapter": 4, "unit": 52, "maxAmount": 2, "weight": 3, "allow": ALL,
     "desc": "Kendi yağında kavrulmuş kuzu kavurma; tırnaklı ekmeğe sıcak sıcak."},
    {"id": "cigkofte", "name": "Çiğ Köfte Dürümü", "fillName": "çiğ köfte", "minChapter": 4, "unit": 34, "maxAmount": 2, "weight": 3, "allow": ALL,
     "desc": "Acılı, isotlu çiğ köfte; marul ve nar ekşisiyle sarılır."},
    {"id": "kizartma", "name": "Kızartma Dürümü", "fillName": "kızartma", "minChapter": 5, "unit": 28, "maxAmount": 2, "weight": 3, "allow": ALL,
     "desc": "Patates, patlıcan ve biber kızartması; ekmeğin içinde çıtır çıtır."},
    {"id": "beyran", "name": "Beyran", "fillName": "beyran", "minChapter": 5, "unit": 66, "maxAmount": 1, "weight": 2, "bowl": True, "allow": ["aci"],
     "desc": "Antep'in sabah çorbası: kuzu etli, pirinçli, acı yağlı. Dürüm değil, kâsede servis edilir."},
]
j["sauces"] = [
    {"id": "sos", "name": "Sos", "desc": "Dükkânın acılı kırmızı sosu.", "cost": 5, "minChapter": 2},
    {"id": "ketcap", "name": "Ketçap", "desc": "Tatlı domates sosu.", "cost": 5, "minChapter": 2},
    {"id": "mayonez", "name": "Mayonez", "desc": "Yumuşak, beyaz sos.", "cost": 5, "minChapter": 2},
    {"id": "sumak", "name": "Sumak", "desc": "Ekşi, kırmızı toz; Antep'in baharı.", "cost": 6, "minChapter": 2},
    {"id": "nar", "name": "Nar ekşisi", "desc": "Koyu, ekşi, kıvamlı. Döner ve çiğ köfteye yakışır.", "cost": 8, "minChapter": 3},
]

d = j["day"]
d.update({"customersBase": 8, "customersPerDay": 2, "customersMax": 30, "spawnGapBase": 11.0, "spawnGapMin": 6.0, "spawnGapDropPerDay": 0.4})

e = j["economy"]
for k in ("supplyPerServe", "supplySumak"):
    e.pop(k, None)
e.update({
    "tipRate": 0.2,            # bahşiş = fiyat x tipRate x sabır x müşteri x yükseltme
    "leavePenalty": 10,        # müşteri küserse kasadan düşen
    "avans": 150,              # gün başında (ve günde bir kez kasa bitince) usta kasayı buna tamamlar
    "friedMinChapter": 2,
    "friedChance": 0.25,
    "sauceChance": 0.22,
    "bonusEvery": 10,          # her 10 servis sonunda bonus müşteri
    "bonusDiamonds": 1,
    "bonusTipMul": 2.0,
    "adMoneyBase": 60,         # reklamla kazanılan para = base + perChapter x bölüm
    "adMoneyPerChapter": 40,
    "adMoneyMax": 3,           # günlük sınır
    "adDiamondMax": 3,
    "adSeconds": 5,
    "streakDays": 3,           # ardışık günlük görev günü
    "streakDiamonds": 2,
    "lives": 5,                # günlük müşteri kaçırma hakkı (bitince oyun kaybedilir; reklamla devam)
    "introSeconds": 3.7,      # "Ya Fettah, Ya Rezzak" kepenk açılışı (ses 3.26 sn + payı)
    "courierWait": 12,         # kurye dokunulmazsa gitmeden önce bekleme (sn)
})

# elmasla satın alınan otomasyon modülleri (kalıcı); fiyatları bölümle artar
UP_IDS = {u["id"] for u in j["upgrades"]}
for u in [
    {"id": "auto_ekmek", "name": "Otomatik Ekmek Açıcı", "desc": "Bekleyen müşteri varken ekmeği kendisi tezgâha serer.", "max": 1, "costs": [4], "perLevel": 0, "minChapter": 2, "currency": "diamond"},
    {"id": "auto_ana", "name": "Otomatik Nohut Koyucu", "desc": "Siparişteki ana malzemeyi (nohut, döner…) porsiyon porsiyon koyar.", "max": 1, "costs": [6], "perLevel": 0, "minChapter": 2, "currency": "diamond"},
    {"id": "auto_sar", "name": "Otomatik Sarıcı", "desc": "Dürüm tamamlanınca kendisi sarar.", "max": 1, "costs": [8], "perLevel": 0, "minChapter": 3, "currency": "diamond"},
    {"id": "auto_ek", "name": "Otomatik Ek Malzeme", "desc": "Piyaz, acı, kızartma ve sosları siparişe göre ekler.", "max": 1, "costs": [10], "perLevel": 0, "minChapter": 3, "currency": "diamond"},
]:
    if u["id"] not in UP_IDS:
        j["upgrades"].append(u)

# Yardımcı Çırak son seviyesi artık "Otomatik Usta": hatasız hazırlar (kod: helperAccuracy)

# mevcut dekora elmas bedeli + yeni dekor
dia = {"fener": 1, "fistik": 1, "foto": 2, "bakir2": 3, "isik": 4}
for dd in j["decor"]:
    if dd["id"] in dia:
        dd["diamonds"] = dia[dd["id"]]
have = {dd["id"] for dd in j["decor"]}
for dd in [
    {"id": "kilim2", "name": "İkinci Kilim", "desc": "Kapı önüne serilen kalın Antep kilimi.", "cost": 1200, "diamonds": 2, "layer": "back", "bonus": 0.03, "minChapter": 2},
    {"id": "neon", "name": "Neon Tabela", "desc": "Gece sokağı aydınlatan nohut dürümü tabelası.", "cost": 1800, "diamonds": 4, "layer": "back", "bonus": 0.03, "minChapter": 3},
    {"id": "akvaryum", "name": "Akvaryum", "desc": "Bekleyenlerin gözünü dinlendiren balıklar.", "cost": 2400, "diamonds": 5, "layer": "back", "bonus": 0.04, "minChapter": 3},
    {"id": "avize", "name": "Kristal Avize", "desc": "Tavanda ışıl ışıl dönen avize.", "cost": 3200, "diamonds": 6, "layer": "back", "bonus": 0.05, "minChapter": 4},
    {"id": "altinsaat", "name": "Altın Saat", "desc": "Duvarda ağır ağır tıkırdayan altın kaplama saat.", "cost": 3000, "diamonds": 7, "layer": "back", "bonus": 0.05, "minChapter": 5},
    {"id": "sutun", "name": "Mermer Sütun", "desc": "Saray sofrasına yakışır iki mermer sütun.", "cost": 4000, "diamonds": 8, "layer": "back", "bonus": 0.06, "minChapter": 5},
]:
    if dd["id"] not in have:
        j["decor"].append(dd)

# v3'te günlük gelir arttı: para yükseltmeleri ve süsler bir kez 1.5× pahalılaşır (işaretli, tekrar çalıştırmada uygulanmaz)
if not j.get("_costScaleV3"):
    for u in j["upgrades"]:
        if u.get("currency", "money") == "money":
            u["costs"] = [int(round(c * 1.5 / 10) * 10) for c in u["costs"]]
    for dd in j["decor"]:
        dd["cost"] = int(round(dd["cost"] * 1.5 / 10) * 10) if dd["id"] not in ("kilim2", "neon", "akvaryum", "avize", "altinsaat", "sutun") else dd["cost"]
    j["_costScaleV3"] = True

P.write_text(json.dumps(j, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print("game.json güncellendi:", len(j["products"]), "ürün,", len(j["sauces"]), "sos,", len(j["upgrades"]), "yükseltme,", len(j["decor"]), "dekor")
