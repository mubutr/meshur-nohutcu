"""assets/dialog/antep.json üretici.

Her replik {who, to, t} biçimindedir (konuşan, muhatap, metin). Sipariş cümleleri, tutarlı tonlu 3 varyanttan
(A/B/C) önceden birleştirilip tam cümle olarak yazılır; oyun çalışırken parça birleştirmez.
Çalıştır: python -I tools/gen_dialog.py  (nohut-durumu klasöründe)
"""
import json
from pathlib import Path

LINES = {}


def add(cat, who, to, *texts):
    LINES.setdefault(cat, []).extend({"who": who, "to": to, "t": t} for t in texts)


# ------------------------------------------------------------- karşılama (usta <-> müşteri)
add("greet_usta", "usta", "musteri",
    "Hoşgeldin {hitap}!",
    "Gel hele gel, hoşgeldin {hitap}.",
    "Buyur {hitap}, hoşgeldin. Ne yiyek bugün?",
    "Hoşgeldin {hitap}, nohutlar daha yeni haşlandı.",
    "Aaa hoşgeldin {hitap}, gözümüz yollarda kaldı yav.")
add("greet_reply", "musteri", "usta",
    "Hoşbuldum {ustaHitap}.",
    "Hoşbulduk {ustaHitap}, eline sağlık.",
    "Hoşbuldum hele, karnım zil çalıyo.",
    "Hoşbuldum {ustaHitap}, bugün de kalabalık maşallah.")

# ------------------------------------------------------------- sipariş (müşteri -> usta): bileşenli dilbilgisi
# Sipariş tek bir tonda (A/B/C) kurulur; oyun çalışırken AntepDialog.composeOrder cümlecikleri birleştirir.
# Her varyantta ürün + porsiyon + piyaz + acı + kızartma + soslar eksiksiz söylenir (tutarlı ton).
SAUCE_NAMES = {"sos": "sos", "ketcap": "ketçap", "mayonez": "mayonez", "nar": "nar ekşisi", "sumak": "sumak"}
PRODUCTS = ["nohut", "doner", "kavurma", "cigkofte", "kizartma", "beyran"]
WORD = {"nohut": "nohut dürümü", "doner": "döner dürümü", "kavurma": "kavurma dürümü", "cigkofte": "çiğ köfte dürümü", "kizartma": "kızartma dürümü"}

GRAMMAR = {
    "A": {
        "open": {
            **{k: f"Hele bi {WORD[k]} {'ver de' if i % 2 == 0 else 'sar da'} yiyek yav." for i, k in enumerate(PRODUCTS[:5])},
            "beyran": "Hele bi kâse beyran ver de içek yav.",
        },
        "amount": {
            "nohut": {"1": "Nohudu az koy, ekmek görünsün.", "2": "Nohudu kararında koy.", "3": "Nohudu bol koy, gıcı gibi koyma."},
            "doner": {"1": "Döner bi kat olsun.", "2": "Dönerden bol koy, çift kat olsun."},
            "kavurma": {"1": "Kavurma az olsun.", "2": "Kavurmayı bol koy hele."},
            "cigkofte": {"1": "Köfte az olsun, acısı yeter.", "2": "Köfteyi bol koy yav."},
            "kizartma": {"1": "Kızartma az olsun.", "2": "Kızartmayı bol koy hele."},
            "beyran": {"1": "Etini eksik etme."},
        },
        "piyaz": {"yes": "Piyazı da at hele.", "no": "Piyaz koyma, soğan sevmem."},
        "aci": {"yes": "Bi tutam da acı at yav.", "no": "Acı olmasın, mideme dokunur."},
        "fried": {"yes": "Yanına kızartma da koy hele.", "no": "Kızartma koyma."},
        "sauceYes": "Üstüne {liste} da sür hele.",
        "sauceNo": "Sos sürme, sumak da serpme.",
        "sauceNames": SAUCE_NAMES,
    },
    "B": {
        "open": {
            **{k: f"Usta, bi {WORD[k]} sar da yiyek." for k in PRODUCTS[:5]},
            "beyran": "Usta, bi beyran ver de içek.",
        },
        "amount": {
            "nohut": {"1": "Nohut azıcık olsun.", "2": "Nohut orta olsun yav.", "3": "Nohudu doldur hele, bol olsun."},
            "doner": {"1": "Döner tek kat olsun.", "2": "Döner çift kat olsun."},
            "kavurma": {"1": "Kavurma azıcık olsun.", "2": "Kavurmayı doldur hele."},
            "cigkofte": {"1": "Köfte azıcık olsun.", "2": "Köfteyi doldur hele."},
            "kizartma": {"1": "Kızartma azıcık olsun.", "2": "Kızartmayı doldur hele."},
            "beyran": {"1": "Beyranın eti bol olsun."},
        },
        "piyaz": {"yes": "Piyazı eksik etme.", "no": "Piyazsız olsun yav."},
        "aci": {"yes": "Acıdan esirgeme.", "no": "Acısız olsun hele."},
        "fried": {"yes": "Kızartmayı da unutma.", "no": "Kızartmasız olsun."},
        "sauceYes": "Üstüne {liste} sür, unutma.",
        "sauceNo": "Sossuz olsun, sumak da yok.",
        "sauceNames": SAUCE_NAMES,
    },
    "C": {
        "open": {
            **{k: f"Hele çabuk bi {WORD[k]} sar yav, açlıktan gözüm karardı." for k in PRODUCTS[:5]},
            "beyran": "Hele çabuk bi beyran ver yav, karnım zil çalıyo.",
        },
        "amount": None,  # A ile aynı
        "piyaz": None,
        "aci": None,
        "fried": None,
        "sauceYes": "Üstüne {liste} da sür yav.",
        "sauceNo": "Sos da sumak da istemem.",
        "sauceNames": SAUCE_NAMES,
    },
}
for k in ("amount", "piyaz", "aci", "fried"):
    GRAMMAR["C"][k] = GRAMMAR["A"][k]

# ------------------------------------------------------------- özel müşteriler
add("relay_riddle", "usta", "cirak",
    "Çırak, {ad} bilmece sordu! Ne istediğini iyi düşün evlat.",
    "Hele çırak, {ad} bilmeceyle sipariş verdi. Kulak ver!")
add("usta_riddle_intro", "usta", "cirak",
    "Evlat, bilmecede 'tutam' az, 'avuç' orta, 'dağ gibi' bol demek. Kırmızı toz sumak, kırmızı pul acıdır.")
add("react_riddle_great", "musteri", "usta",
    "Bildin evlat, bildin! Helal olsun usta, çırağın akıllıymış. Hayırlı işler.",
    "Tam istediğim bu! Bilmeceyi çözen çırak ender bulunur usta, hayırlı işler.")
add("react_riddle_bad", "musteri", "usta",
    "Bilemedin bilmeceyi usta. Çırak biraz daha dinlemeyi öğrensin, hayırlı işler.",
    "Yav bu mu benim istediğim? Bilmeceyi iyi dinlemeli! Hayırlı işler usta.")
add("usta_riddle_great", "usta", "cirak",
    "Bilmeceyi çözdün evlat, aferin!",
    "Maşallah çırak, akıl da el de yerinde.")
add("usta_riddle_bad", "usta", "cirak",
    "Bilmeceyi bilemedin çırak, bi dahaki sefere iyi dinle.",
    "Olsun evlat, bilmece zor iştir. Bi daha dene.")

add("garip_greet", "usta", "musteri",
    "Buyur Gariban, hoşgeldin. Yorulmuşsun, otur biraz.",
    "Hoşgeldin Gariban, nohutlar daha sıcak.")
add("garip_ask", "musteri", "usta",
    "Usta, bu garibin karnı aç. Bi lokma nohut dürümü verir misin? Allah razı olsun.",
    "Usta, param yok ama karnım aç. Bi dürüm sevabına ver.")
add("garip_relay", "usta", "cirak",
    "Çırak, Gariban aç gelmiş. İstersen bi dürüm sar, sevabı bol.",
    "Evlat, Gariban'ın karnı aç. Elin açık olsun, bi dürüm sar.")
add("garip_thanks", "musteri", "usta",
    "Allah razı olsun usta, hayırlı işler. Bu iyiliği unutmam.",
    "Sağ ol evladım, hayırlı işler. Bu iyiliği unutmam.")
add("garip_leave", "musteri", "usta",
    "Zahmet verdim usta, Allah kolaylık versin. Ben gidek, hayırlı işler.")
add("usta_garip_praise", "usta", "cirak",
    "Hayırlı iş yaptın evlat, Allah kabul etsin.",
    "İyi ki verdin çırak, bu dükkânın bereketi budur.")
add("usta_garip_left", "usta", "cirak",
    "Olsun çırak, Gariban yine uğrar. Bi dahaki sefere verirsin.")

add("maskeli_greet", "usta", "musteri",
    "Buyur müşteri, ne olacak?")
add("maskeli_relay", "usta", "cirak",
    "Çırak, bu Maskeli Müşteri. Dikkat et, hata yaparsan kasadan para alır!",
    "Evlat, maskeli geldi. Siparişi tam yap yoksa kasayı boşaltır!")
add("maskeli_great", "musteri", "usta",
    "Hm, tam dediğim gibi. Bu sefer bahşişi hak ettin usta, hayırlı işler.",
    "Fena değil usta, bu sefer kasayı bırakıyorum. Hayırlı işler.")
add("maskeli_steal", "musteri", "usta",
    "Yanlış dürüm! Hakkım kasada, hayırlı işler usta.",
    "Bu mu benim siparişim? Kasadan hakkımı alıyorum usta, hayırlı işler!")
add("usta_stolen", "usta", "cirak",
    "Eyvah çırak, Maskeli kasadan {miktar} lira aldı! Bi dahaki sefere dikkat et.")

# ------------------------------------------------------------- ustanın siparişi çırağa iletmesi (usta -> çırak)
add("relay", "usta", "cirak",
    "Çırak, {adDat} {ozet} lazım.",
    "Evlat, {ad} bekliyo. {ozet} olacak, tez ol.",
    "Hele çırak, {adDat} {ozet} hazırla.")

# ------------------------------------------------------------- bekleme (müşteri -> usta; usta -> çırak)
add("wait_mid", "musteri", "usta",
    "Usta, nohut mu haşlanıyo daha?",
    "Hele çabuk ol yav, karnım zil çalıyo.",
    "Usta, bi el at yav, hep mi bekleyek?")
add("wait_low", "musteri", "usta",
    "Usta, bu kadar bekletirsen gidek biz!",
    "Yav ben mi sabırlıyım, çabuk ol hele!",
    "Usta, gözüm ekmekte kaldı yav.")
add("usta_push", "usta", "cirak",
    "Çırak, {ad} sabırsızlandı, tez ol!",
    "Evlat, {ad} gidecek, yetiş!")

# ------------------------------------------------------------- servis tepkisi (müşteri -> usta)
add("react_great", "musteri", "usta",
    "Eline sağlık usta, tam dediğim gibi! Hayırlı işler.",
    "Ekmeği de nohudu da tam kararında usta, hayırlı işler.",
    "Vallaa böylesini görmedim, helal olsun usta! Hayırlı işler.")
add("react_great_tip", "musteri", "usta",
    "Eline sağlık usta, tam dediğim gibi! Üstü kalsın, hayırlı işler.",
    "Helal olsun usta, bu da bahşiş olsun. Hayırlı işler.",
    "Üstünü alma yav usta, hayırlı işler.")
add("react_ok", "musteri", "usta",
    "Fena del yav, ama bi daha dikkat edin. Hayırlı işler usta.",
    "Idare eder usta, yiyek bakak. Hayırlı işler.")
add("react_bad", "musteri", "usta",
    "Yav ben bunu mu dedim usta? Neyse, hayırlı işler.",
    "Bu ne yav, ağzıma bi şey uymadı! Hayırlı işler usta.",
    "Dediğim gibi del bu usta! Hayırlı işler.")
add("leave", "musteri", "usta",
    "Hadi hayırlı işler usta, ben başka yerde yiyek.",
    "Çok bekledim yav, gidek biz. Hayırlı işler usta, sağ ol.")
add("usta_meh", "usta", "cirak",
    "Fena del evlat, ama {ad} tam memnun olmadı.",
    "Olur çırak, bi dahaki sefere siparişe iyi bak.")
add("usta_scold", "usta", "cirak",
    "Evlat, bu ne böyle? {ad} kızdı!",
    "Dikkat et çırak, siparişi iyi dinle.")
add("usta_after_leave", "usta", "cirak",
    "Eyvah evlat, {ad} küsüp gitti.",
    "Olsun çırak, bi dahaki sefere çabuk ol.")
add("usta_trash", "usta", "cirak",
    "Boşver evlat, yenisini yapak ama malzeme parası çöpe gitti, dikkat et.",
    "Olur öyle şeyler çırak, yalnız harcanan para geri gelmez.")

# ------------------------------------------------------------- Bölüm 4: paket servis ve bahçe (usta -> çırak)
add("usta_delivery_new", "usta", "cirak",
    "Çırak, Kapında'dan yeni paket siparişi düştü! Dürümü sar, kartına dokun.",
    "Evlat, paket siparişi geldi. Kurye yakında, ısı kutusunu hazırla.")
add("usta_delivery_ok", "usta", "cirak",
    "Paket zamanında gitti evlat, Kapında'ya inat!",
    "Kurye memnun gitti çırak, sıcak sıcak teslim oldu.")
add("usta_delivery_cold", "usta", "cirak",
    "Paket kutuda soğumuş evlat, kuryeyi bekletme!",
    "Dürüm kutuda soğudu çırak, kurye gelmeden hazırla.")
add("usta_delivery_late", "usta", "cirak",
    "Paket geç kaldı evlat, müşteri söylenmiş.",
    "Teslimat gecikti çırak, bi dahaki sefere tez ol.")
add("usta_delivery_fail", "usta", "cirak",
    "Eyvah çırak, paket yetişmedi, sipariş iptal oldu!",
    "Paket siparişini kaçırdık evlat, kurye boş döndü.")
add("usta_garden_hint", "usta", "cirak",
    "Akşam bahçeye uğra çırak, sulamayı unutma!",
    "Evlat, bahçedeki bitkiler susamasın, bi su ver.")

# ------------------------------------------------------------- gün akışı (usta -> çırak)
add("usta_intro", "usta", "cirak",
    "Hoşgeldin çırak! Önce ekmeği al, nohudu koy, sar, sonra müşteriye uzat.")
add("usta_day_start", "usta", "cirak",
    "Hayırlı işler çırak, tırnaklı ekmek taptaze!",
    "Bugün de bereket versin evlat, dükkânı açak.")
add("usta_day_end", "usta", "cirak",
    "Gün bitti evlat, yorulduk ama kazandık.",
    "Eline sağlık çırak, bugün de çok şükür.")
add("usta_shop", "usta", "cirak",
    "Kazandığımızı dükkâna koyak evlat.",
    "Hele şunu da alak evlat, dükkân güzelleşsin.")
add("usta_hint_bread", "usta", "cirak", "Önce tırnaklı ekmeği tezgâha al çırak.")
add("usta_hint_wrap", "usta", "cirak", "Malzeme tamamsa dürümü sar çırak.")
add("usta_hint_serve", "usta", "cirak", "Şimdi dürümü müşteriye ver evlat, bekletme.")


# ------------------------------------------------------------- v3: kasa, bonus müşteri, kurye
add("usta_no_money", "usta", "cirak",
    "Evlat, kasada para kalmadı! Bahşiş kavanozuna bak ya da bi reklam izle.",
    "Çırak, malzemeye para yok. Kavanozdaki bahşişi kasaya al.")
add("usta_avans", "usta", "cirak",
    "Kasa boşalmış evlat, bu avansı al, geri vermek yok. Bu sefer dikkatli ol.",
    "Çırak, cebimden kasaya avans koydum. Bi daha çöpe atma.")
add("usta_tipjar", "usta", "cirak",
    "Bahşiş kavanozu doldu evlat, kasaya dök.",
    "Çırak, kavanozdaki bahşişi unutma.")
add("usta_penalty", "usta", "cirak",
    "Müşteri küsünce kasadan {ceza} lira gider evlat, çabuk ol.",
    "Eyvah çırak, küsen müşteri {ceza} liraya mal oldu.")
add("bonus_greet", "usta", "musteri",
    "Hoşgeldin gezgin, uzak yoldan mı geldin?",
    "Buyur gezgin, hoşgeldin. Antep'in nohudunu tatmadan gitme.")
add("bonus_reply", "musteri", "usta",
    "Hoşbuldum usta, yollarda adın duyuldu.",
    "Hoşbuldum usta, burnuma güzel koku geldi.")
add("usta_bonus", "usta", "cirak",
    "Çırak, bu gezgin kıymetli misafir. Güzel yap, bi hatıra bırakır.",
    "Evlat, gezgin geldi! Hatasız bi dürüm yap, eli boş gitmez.")
add("bonus_thanks", "musteri", "usta",
    "Eline sağlık usta. Bu elması hatıra bırakıyorum, hayırlı işler.",
    "Sana bi elmas armağan usta, hayırlı işler. Bi daha uğrarım.")
add("kurye_ask", "musteri", "usta",
    "Usta, paketler hazır mı? Kapında bekletmez!",
    "Usta, kurye geldi. Kutudakileri alayım da gidek.")
add("kurye_thanks", "musteri", "usta",
    "Eyvallah usta, paketler yolda. Hesap tamam, hayırlı işler!",
    "Sağ ol usta, müşteriler bekliyor, hayırlı işler, ben kaçtım.")
add("kurye_leave", "musteri", "usta",
    "Boş kaldım usta, gidiyom. Hayırlı işler, bi dahaki sefere hazır olsun.",
    "Yetişemedik usta, kurye mola vermez. Hayırlı işler.")
add("kurye_greet", "usta", "musteri",
    "Hoşgeldin kurye, bi bakak paketlere.",
    "Gel kurye, kutuya bi göz atalım.")
add("usta_courier", "usta", "cirak",
    "Çırak, kurye geldi! Dokun da paketleri versin.",
    "Evlat, kurye kapıda, paketleri teslim et.")
add("usta_courier_paid", "usta", "cirak",
    "Kurye paketleri aldı evlat, ödeme kasada.",
    "Paketler yola çıktı çırak, hesap tamam.")
add("usta_courier_left", "usta", "cirak",
    "Kurye paketleri almadan gitti evlat, kutu soğur!",
    "Eyvah çırak, kurye boş döndü, bi sonrakini kaçırma.")

# ------------------------------------------------------------- usta -> müşteri: bereket versin (müşteri "hayırlı işler" der, usta "bereket versin" der)
add("usta_bereket", "usta", "musteri",
    "Bereket versin {hitap}, yine bekleriz.",
    "Sağ ol {hitap}, bereket versin. Yolun açık olsun.",
    "Bereket versin {hitap}, bi daha uğra.",
    "Hayrını gör {hitap}, bereket versin.")
add("usta_bereket_garip", "usta", "musteri",
    "Bereket versin Gariban, kapımız sana hep açık.")

# ------------------------------------------------------------- kaybetme ve reklamla devam
add("usta_game_over", "usta", "cirak",
    "Eyvah evlat, çok müşteri küstü, dükkân bugün zora girdi!",
    "Çırak, yetişemedik; müşteriler dağıldı. Ne yapak şimdi?")
add("usta_revive", "usta", "cirak",
    "Hadi evlat, kalan müşteriler geri döndü, bu sefer yetişelim!",
    "Maşallah çırak, bi şans daha verdik, tez ol!")

OUT = {
    "_not": "Antep ağzı replikleri. who/to: konuşan ve muhatap (usta, musteri, cirak). {hitap}: ustanın müşteriye hitabı, "
            "{ad}: müşteriden bahsederken adı, {adDat}: yönelme hâli, {ustaHitap}: müşterinin ustaya hitabı. "
            "Bu dosya tools/gen_dialog.py ile üretilir. Yerel ağız doğruluğu için gözden geçirilmeli.",
    "banned": ["gari"],
    "order": GRAMMAR,
    "lines": LINES,
}

if __name__ == "__main__":
    p = Path(__file__).resolve().parent.parent / "assets" / "dialog" / "antep.json"
    p.write_text(json.dumps(OUT, ensure_ascii=False, indent=1), encoding="utf-8")
    print(len(LINES), "kategori,", sum(len(v) for v in LINES.values()), "replik ->", p)
