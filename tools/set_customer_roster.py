"""game.json'daki müşteri kadrosunu (10 kadın + 10 erkek) ve hikâye karakteri adlarını ayarlar.

Her müşteri tek bir ad + tek bir görünüm taşır; sprite öneki = id (ör. fatma_normal.png).
Çalıştır: python -I tools/set_customer_roster.py   (nohut-durumu klasörü). Tekrar çalıştırmak güvenlidir.
"""
import json
from pathlib import Path

P = Path("assets/data/game.json")
j = json.loads(P.read_text(encoding="utf-8"))


def person(pid, ad, gender, age):
    """age: 'yasli' | 'genc'. Yaşlı erkek 'ammi', kadın 'bacı', genç erkek ustaya/ustadan 'Rafık'."""
    if gender == "kadin":
        ref, dat, hitap, usta = f"{ad} bacı", f"{ad} bacıya", None, "usta"
        patience, tip, weight = (1.15, 1.1, 2) if age == "yasli" else (1.0, 1.1, 2)
    elif age == "yasli":
        ref, dat, hitap, usta = f"{ad} ammi", f"{ad} ammiye", None, "usta"
        patience, tip, weight = 1.2, 1.0, 2
    else:
        ref, dat, hitap, usta = ad, f"{ad}'ye" if False else ad, "Rafık", "Rafık"
        patience, tip, weight = 0.8, 1.3, 1
    name = {"n": ad, "ref": ref, "dat": dat}
    if hitap:
        name["hitap"] = hitap
    return {"id": pid, "gender": gender, "age": age, "patience": patience, "tip": tip, "weight": weight, "ustaHitap": usta, "names": [name]}


ROSTER = [
    # kadınlar
    person("fatma", "Fatma", "kadin", "yasli"),
    person("hattuc", "Hattuç", "kadin", "yasli"),
    person("zennup", "Zennup", "kadin", "yasli"),
    person("sehriban", "Şehriban", "kadin", "yasli"),
    person("emine", "Emine", "kadin", "genc"),
    person("hayce", "Hayce", "kadin", "genc"),
    person("ayyus", "Ayyuş", "kadin", "genc"),
    person("yumma", "Yumma", "kadin", "genc"),
    person("lutfiye", "Lütfiye", "kadin", "genc"),
    person("sakire", "Şakire", "kadin", "genc"),
    # erkekler
    person("maamed", "Maamed", "erkek", "yasli"),
    person("huseyin", "Hüseyin", "erkek", "yasli"),
    person("okkes", "Ökkeş", "erkek", "yasli"),
    person("cimaali", "Cımaali", "erkek", "yasli"),
    person("mustafa", "Mustafa", "erkek", "genc"),
    person("ahmet", "Ahmet", "erkek", "genc"),
    person("ali", "Ali", "erkek", "genc"),
    person("mehmetali", "Mehmet Ali", "erkek", "genc"),
    person("hoggeş".replace("ş", "s"), "Höggeş", "erkek", "genc"),
    person("memik", "Memik", "erkek", "genc"),
]
# genç erkekte yönelme hâli: ad + "'e/'a" yerine yalın ad kullanılır (ustanın konuşması ref/hitap ile kurulur)
for r in ROSTER:
    n = r["names"][0]
    if r["gender"] == "erkek" and r["age"] == "genc":
        n["dat"] = n["ref"]

j["customers"] = ROSTER

# hikâye karakterleri
NAMES = {
    "garip": {"n": "Gariban", "ref": "Gariban", "dat": "Garibana", "hitap": "Gariban"},
    "nine": {"n": "Nene", "ref": "Taaf Nene", "dat": "Taaf Neneye", "hitap": "Nene"},
    "itfaiyeci": {"n": "Mömet", "ref": "İtfaiyeci Mömet", "dat": "İtfaiyeci Mömete", "hitap": "Mömet"},
    "maskeli": {"n": "Maskeli", "ref": "Maskeli Müşteri", "dat": "Maskeli Müşteriye", "hitap": "müşteri"},
}
for s in j["specials"]:
    if s["kind"] in NAMES:
        s["name"] = NAMES[s["kind"]]

P.write_text(json.dumps(j, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print(len(ROSTER), "müşteri;", sum(1 for r in ROSTER if r["gender"] == "kadin"), "kadın,", sum(1 for r in ROSTER if r["gender"] == "erkek"), "erkek")
