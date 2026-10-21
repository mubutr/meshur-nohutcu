"""assets/dialog/story.json üretici: bölüm giriş/çıkış sahneleri ve görev sahneleri.

Her replik {who, to, t}. Roller: usta, cirak (oyuncu), rakip (Kalaycı), nine (Taaf Nene), dayi (Gariban),
yatirimci (Gariban'ın yeni hâli), maskeli, itfaiyeci, antikaci, anlatici (anlatıcı).
Bu hikâye bu proje için özgün yazılmıştır.
"""
import json
from pathlib import Path

SCENES = {}


def scene(sid, *lines):
    SCENES[sid] = [{"who": w, "to": t, "t": x} for (w, t, x) in lines]


# ====================================================================== BÖLÜM 1
scene("c1_intro",
      ("anlatici", "cirak", "Gaziantep, Bey Mahallesi. Sabahın köründe tandırın külü daha sıcak, nohut kazanı fokur fokur."),
      ("usta", "cirak", "Hoşgeldin çırak! Bu dükkânı babamdan devraldım. Tırnaklı ekmeğimizin, nohudumuzun adı bütün mahalleye yayılmıştı."),
      ("usta", "cirak", "Ama şu karşıya bak evlat. Kalaycı Nohut Evi açılmış. Neon ışık, davul zurna... Müşteri hep oraya akıyor."),
      ("rakip", "usta", "Günaydın usta! Eski usul nohut kaç gün dayanır bakalım? Mahalle yenilikten hoşlanır."),
      ("usta", "cirak", "Sakın tırsma evlat. Bizim elimiz ekmek bilir. Sen dürümü hazırla, ben müşteriyle konuşurum."),
      ("usta", "cirak", "Önce ekmeği al, nohudu kararında koy, sar, müşteriye uzat. Siparişi iyi dinle! Hadi, hayırlı işler!"))

scene("c1_outro",
      ("usta", "cirak", "Gördün mü evlat? Mahalle bizi unutmamış. Kalaycı'nın neonu bir yere kadar."),
      ("rakip", "usta", "Hele hele... Çıraklık fena değilmiş usta. Ama şenlik yaklaşıyor, asıl sınav orada."),
      ("usta", "cirak", "Şenlikten önce mahallenin Taaf Nene'si dükkânları sınar evlat. Sumak kâsesini de hazırlayalım, işimiz artacak."))

# ====================================================================== BÖLÜM 2
scene("c2_intro",
      ("anlatici", "cirak", "Mahallenin en yaşlı kadını Taaf Nene, şenlikten önce her dükkânı bilmeceyle sınar."),
      ("nine", "usta", "Usta, çırağın kulağı mı açık yoksa eli mi? Ben siparişimi bilmeceyle veririm. Doğru yaparsan şenliğe adın yazılır."),
      ("usta", "cirak", "Evlat, bilmecede 'tutam' az, 'avuç' orta, 'dağ gibi' bol demek. Kırmızı toz sumaktır, kırmızı pul acıdır."),
      ("usta", "cirak", "Bilmece soran müşterinin yanında seçenek rozeti olmaz. Kulak ver, düşün, sonra hazırla!"),
      ("anlatici", "cirak", "Dükkâna sumak kâsesi geldi. Siparişler artık daha lezzetli, daha zor."))

scene("c2_dayi_thanks",
      ("dayi", "usta", "Allah razı olsun usta, hayırlı işler. Bu iyiliği unutmam."),
      ("usta", "cirak", "Gördün mü evlat, kimi zaman bir lokma bir ömre değer. Gariban'a kapımız hep açık."))

scene("c2_outro",
      ("nine", "usta", "Eline sağlık usta, çırağın akıllıymış. Şenlik defterinde adınız var."),
      ("rakip", "usta", "Şenlikte görüşürüz usta. Jüri benim dürümümü de tadacak."),
      ("usta", "cirak", "Yarın şenlik başlıyor evlat. Dükkânın adı, mahallenin adı için en iyi dürümü yapacağız."))

# ====================================================================== BÖLÜM 3
scene("c3_intro",
      ("anlatici", "cirak", "Gaziantep Gastronomi Şenliği başladı! Bütün mahalle sokağa dökülmüş, tezgâhlar boy boy dizilmiş."),
      ("rakip", "usta", "Şenlikte jüri benim dürümüme bakacak usta. Sen nohuduna bakarsın."),
      ("usta", "cirak", "Kalabalık çok olacak evlat. Tek başımıza yetişemeyiz; bi yardımcı çırak tutmanın zamanı geldi."),
      ("usta", "cirak", "Şenlik boyunca para biriktirelim, Yardımcı Çırak'ı işe alak. Jüri 'Yılın Nohut Ustası'nı seçecek!"))

scene("c3_outro",
      ("nine", "usta", "Yılın Nohut Ustası bu dükkân oldu! Ben söylemiştim, bu çocuğun elinde hayır var."),
      ("rakip", "usta", "Bu sefer sen kazandın usta... Ama bitmedi. Kapında diye bir teslimat zinciri kuruyorum. Yakında kapına kurye yağacak."),
      ("usta", "cirak", "Dinleme onu evlat. Biz de paket servise başlarız, arka bahçeyi de ekeriz. Malzemeyi kendimiz yetiştirelim."))

scene("c3_investor",
      ("yatirimci", "usta", "Beni tanımadın mı usta? Bir zamanlar kapınıza aç geldim, bir dürüm verdiniz. Hiç unutmadım."),
      ("yatirimci", "usta", "Şimdi işlerim yoluna girdi. Bu dükkâna yatırım yapmak istiyorum. Al şu kesemi, sevabın karşılığı."),
      ("usta", "cirak", "Gördün mü evlat, yapılan iyilik yerde kalmaz. Bundan sonra her dürümden payımız bereketlenecek."))

# ====================================================================== BÖLÜM 4
scene("c4_intro",
      ("anlatici", "cirak", "Kalaycı Nohut Evi 'Kapında' adlı bir teslimat zinciri kurdu. Sokak motorlu kuryelerle doldu."),
      ("rakip", "usta", "Usta, artık müşteri dükkâna gelmiyor; biz müşterinin kapısına gidiyoruz. Yetiş bakalım!"),
      ("usta", "cirak", "Biz de Kapında'ya katılırız evlat. Ama bizim paketimiz sıcak gider: dürümü sar, sağdaki sipariş kartına dokun, ısı kutusuna girsin."),
      ("usta", "cirak", "Kurye belli aralıkla gelir, kutudakileri alır. Kutuda çok bekletirsen soğur, geç kalırsan para kırılır. Aklında olsun!"),
      ("usta", "cirak", "Bi de arka bahçeyi açtım. Maydanoz, soğan, biber... Her akşam gün bitince bahçeye uğra, tohum ek, sula, olgunlaşanı topla."),
      ("usta", "cirak", "Taze malzeme masrafı düşürür, dürümün tadı da artar. Sulamayı unutma çırak, susuz kalan bitki kurur!"))

scene("c4_outro",
      ("usta", "cirak", "Paket de bahçe de yoluna girdi evlat. Kalaycı'nın zinciri bizim sıcak dürümümüze yetişemedi."),
      ("antikaci", "usta", "Hoş geldiniz usta... Kalaycı'ya karşı güzel dayandınız. Ben eski eşyaya meraklıyım; sizin tandırdaki o tarihî taşı hep merak ederim."),
      ("usta", "cirak", "O taşı bilirsin evlat, babamdan kalma emanet. Gözün üstünde olsun, kimseye de emanet etme."))

# ====================================================================== BÖLÜM 5
scene("c5_intro",
      ("anlatici", "cirak", "Bir sabah usta dükkânı açtı ve tandırın yanındaki tarihî taşın yerinde olmadığını gördü."),
      ("usta", "cirak", "Evlat, babamın bana emaneti tandır taşı kayıp! Kapı kilitliydi, kimse bir şey görmemiş."),
      ("usta", "cirak", "Dükkâna da bakacağız, soruşturmaya da. Her akşam dükkân kapanınca iz süreriz; geceleri iki yere bakabiliriz."),
      ("nine", "usta", "Taşın başına bi hal gelirse mahallenin huzuru gider usta. Ben de kulak kesilirim."))

scene("c5_mid",
      ("usta", "cirak", "İzler çarşıya doğru gidiyor evlat. Ama kimseyi peşin suçlama; yanlış suçlamanın bedeli ağırdır."),
      ("dayi", "usta", "Usta, gece yarısı çarşıda bi adam gördüm. Elinde kızak vardı. Yüzünü seçemedim ama ışıkta bi şey parladı."))

scene("c5_solved",
      ("usta", "cirak", "Tamam evlat, suçlu belli. Galaycı Nuru'yu çağırın!"),
      ("antikaci", "usta", "Beni yakaladınız usta... Taşı bi koleksiyoncuya satacaktım. Borcum vardı, aklımı kaybettim."),
      ("usta", "cirak", "Taş yerine konsun. Nuru'nun borcu için de mahalle bi çare bulur; ama bu dükkânın kapısı hırsıza kapalıdır."),
      ("nine", "usta", "Bilmece çözüldü usta. Çırağın hem eli hem aklı yerinde."))

scene("c5_outro",
      ("anlatici", "cirak", "Tandır taşı yerine kondu. Mahalle sokağa dökülüp Bey Mahallesi'nin ustasını ve çırağını alkışladı."),
      ("rakip", "usta", "Kapında'nın kapısına bi tabela asıyorum usta: 'Bey Mahallesi'nin nohudunu kimse geçemez.' Eyvallah."),
      ("usta", "cirak", "Artık çırak değilsin evlat. Bu dükkânın kalbi senin elinde. Hayırlı olsun, hadi iş başına!"),
      ("anlatici", "cirak", "Hikâye burada biter, dükkân açık kalır. Yeni siparişler, yeni bilmeceler, yeni müşteriler seni bekliyor."))

OUT = {"_not": "Hikâye sahneleri. tools/gen_story.py ile üretilir.", "scenes": SCENES}

if __name__ == "__main__":
    p = Path(__file__).resolve().parent.parent / "assets" / "dialog" / "story.json"
    p.write_text(json.dumps(OUT, ensure_ascii=False, indent=1), encoding="utf-8")
    print(len(SCENES), "sahne,", sum(len(v) for v in SCENES.values()), "replik ->", p)
