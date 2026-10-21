"""assets/data/detective.json üretici: Bölüm 5 soruşturması (özgün kurgu).

Suçlu: Galaycı Nuru. Doğru suçlama için gerekli ipuçları: needs listesi.
Her replik {who, to='cirak', t}; konuşan kişi = şüpheli/tanık kimliği.
"""
import json
from pathlib import Path

CLUES = {
    "kul_izi": ("Tandır Arkasında Kül İzi", "Tandırın arka kapısında taze kül izi var: taşı kızakla sürüklemişler."),
    "kapi_kilit": ("Zorlanmamış Kilit", "Kilit kırılmamış. Ya anahtar kopyalanmış ya da biri akşam içerde saklanmış."),
    "kizak_izi": ("Kızak İzleri", "Arka sokakta iki tahta kızak izi çarşı yönüne gidiyor; ağır bir yük çekilmiş."),
    "kagit_parcasi": ("Yırtık Fiş", "Yerde 'Eski Çarşı Antika' yazılı yırtık bir fiş parçası duruyor."),
    "bilezik": ("Kırık Bakır Bilezik", "Çarşıda yerde yarım bir bakır bilezik buldun. Zanaat işi, eskiden kalma bir model."),
    "kalayci_alibi": ("Kalaycı'nın Mazereti", "Kalaycı, o gece şenlik hesabı yaptığını söyledi; mahalle bekçisi onu gördü."),
    "nuri_sordu": ("Nuru Taşı Sormuş", "Kalaycı'ya göre Galaycı Nuru geçen hafta tandır taşının fiyatını sormuş."),
    "maskeli_alibi": ("Maskeli'nin Mazereti", "Maskeli Müşteri, o gece hastanede kuzenini beklediğini söyledi; İtfaiyeci Mömet de orada imiş."),
    "bilezik_nuri": ("Bilezik Nuru'nun Tarzı", "Maskeli, bileziğin Galaycı Nuru'nun dükkânında satılan türden olduğunu söyledi."),
    "dayi_tanik": ("Gariban'ın Tanıklığı", "Gariban, gece yarısı çarşıya kızak çeken bir adam gördüğünü anlattı."),
    "dayi_bilezik": ("Adamın Bileziği", "Gariban, o adamın koluna tam böyle bir bakır bilezik taktığını, kızağı çekerken düştüğünü hatırladı."),
    "nuri_merak": ("Nuru'nun Merakı", "Nuru taşı sorduğunu inkâr etmedi: 'Meraklıyım, satılık mı diye baktım' dedi."),
    "nuri_yalan": ("Nuru'nun Tutarsızlığı", "Nuru 'evde uyuyordum' dedi ama bekçi Hasan o saatte onun dükkânının ışığının yandığını söylemiş."),
    "nuri_kacamak": ("Nuru Kaçamak Yaptı", "Bileziği sorunca Nuru 'benim dükkânımdan çok bilezik çıkar' diyerek konuyu değiştirdi."),
}

LOCATIONS = [
    {"id": "firin", "name": "Tandır ve Arka Kapı", "desc": "Taşın durduğu yer. Zemin, kül ve kapı izleri.",
     "inspect": [{"clue": "kul_izi"}, {"clue": "kapi_kilit"}]},
    {"id": "sokak", "name": "Arka Sokak", "desc": "Dükkânın arkasından çarşıya inen dar sokak.",
     "inspect": [{"clue": "kizak_izi"}, {"clue": "kagit_parcasi"}]},
    {"id": "carsi", "name": "Eski Çarşı", "desc": "Antikacıların, kalaycıların sokağı.",
     "inspect": [{"clue": "bilezik"}]},
]

SUSPECTS = [
    {"id": "rakip", "name": "Kalaycı", "title": "Rakip nohutçu", "intro": "Karşı sokağın parlak nohutçusu. Taşa ilgisi olur mu?"},
    {"id": "maskeli", "name": "Maskeli Müşteri", "title": "Gizemli müşteri", "intro": "Kasa başında dolaşan, yüzünü hiç göstermeyen biri."},
    {"id": "dayi", "name": "Gariban", "title": "Mahallenin gözü", "intro": "Geceleri sokaklarda dolaşır; çok şey görür, az konuşur."},
    {"id": "antikaci", "name": "Galaycı Nuru", "title": "Eski eşya satıcısı", "intro": "Çarşıda tarihî eşya satıyor; tandır taşına meraklı."},
]


def line(who, t):
    return {"who": who, "to": "cirak", "t": t}


TALK = {
    "rakip": [
        {"id": "r1", "q": "Dün gece neredeydin?",
         "a": [line("rakip", "Ben mi? Şenlik hesabını yapıyordum, bekçi Hasan beni dükkânda gördü. Sorsana ona.")], "clue": "kalayci_alibi"},
        {"id": "r2", "q": "Tandır taşından haberin var mı?",
         "a": [line("rakip", "Ben taşla uğraşmam, nohutla uğraşırım. Ama geçen hafta Galaycı Nuru bana o taşın fiyatını sormuştu, ona bak.")], "clue": "nuri_sordu"},
    ],
    "maskeli": [
        {"id": "m1", "q": "Dün gece neredeydin?",
         "a": [line("maskeli", "Hastanede kuzenimi bekledim. İtfaiyeci Mömet de oradaydı, istersen sor.")], "clue": "maskeli_alibi"},
        {"id": "m2", "q": "Bu bilezik sana tanıdık geldi mi?", "requires": ["bilezik"],
         "a": [line("maskeli", "Bakır bilezik... Benim değil. Bu işi çarşıda satanı bilirim: Galaycı Nuru'nun dükkânında görürsün.")], "clue": "bilezik_nuri"},
    ],
    "dayi": [
        {"id": "d1", "q": "Gariban, gece bir şey gördün mü?",
         "a": [line("dayi", "Gördüm evladım. Gece yarısı çarşıya doğru bi adam kızak çekiyordu. Yüzünü seçemedim.")], "clue": "dayi_tanik"},
        {"id": "d2", "q": "Adamın üstünde ya da elinde ayırt edici bir şey var mıydı?", "requires": ["dayi_tanik"],
         "a": [line("dayi", "Koluna bakır bi bilezik takmıştı. Kızağı çekerken düştü, ışıkta parladı. Hiç unutmam.")], "clue": "dayi_bilezik"},
    ],
    "antikaci": [
        {"id": "a1", "q": "Tandır taşını sorduğun doğru mu?",
         "a": [line("antikaci", "Meraklıyım, sorarım tabii. Satılık mı diye baktım. Suç mu bu?")], "clue": "nuri_merak"},
        {"id": "a2", "q": "Dün gece neredeydin?", "requires": ["kizak_izi"],
         "a": [line("antikaci", "Evde uyuyordum, nerede olacağım?"), line("antikaci", "(Bekçi Hasan o saatte dükkânının ışığının yandığını söylemişti...)")], "clue": "nuri_yalan"},
        {"id": "a3", "q": "Bu bilezik senin dükkânından mı?", "requires": ["bilezik"],
         "a": [line("antikaci", "Benim dükkânımdan çok bilezik çıkar usta... Bakır bilezik her yerde var."), line("antikaci", "(Konuyu çabuk değiştirdi.)")], "clue": "nuri_kacamak"},
    ],
}

OUT = {
    "_not": "Bölüm 5 soruşturma verisi. tools/gen_case.py ile üretilir. Özgün kurgu.",
    "culprit": "antikaci",
    "needs": ["kul_izi", "bilezik_nuri", "dayi_bilezik"],
    "actionsPerNight": 2,
    "wrongPenalty": 150,
    "clues": {k: {"title": v[0], "text": v[1]} for k, v in CLUES.items()},
    "locations": LOCATIONS,
    "suspects": SUSPECTS,
    "talk": TALK,
}

if __name__ == "__main__":
    p = Path(__file__).resolve().parent.parent / "assets" / "data" / "detective.json"
    p.write_text(json.dumps(OUT, ensure_ascii=False, indent=1), encoding="utf-8")
    print(len(CLUES), "ipucu ->", p)
