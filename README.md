# Meşhur Nohutçu

Gaziantep'te bir nohut dürümü dükkânında geçen, Flutter ile yazılmış 2.5D restoran oyunu (çalışma adı).
Müşteriler ve usta **Antep ağzıyla** konuşur. Tüm görseller ve sesler betikle sıfırdan üretilir.

> **Marka notu:** Oyun adı **Meşhur Nohutçu**; yapımcı markası **bigsoft games** (açılış ekranı). Mağaza yayınından önce ad için marka/mağaza taraması yapılmalıdır.
> **Temiz-oda ilkesi:** Kod, sanat, ses, metin, ürün/karakter adı ve denge değerlerinin tamamı bu depoda sıfırdan yazılmıştır; başka bir oyundan kopyalanmış hiçbir şey yoktur. Başka oyunlardan yalnızca tür düzeyindeki fikirler (bölümlü hikâye, günlük görevler, bahçe, paket servis, dedektiflik) alınmıştır.

## Oynanış
1. Müşteri gelir, **usta** karşılar ("Hoşgeldin Rafık"), müşteri siparişini ustaya söyler; usta siparişi **çırağa (sen)** iletir. Her balonda *kim → kime* yazar. Sipariş tek bir tonda, ürünü, porsiyonu, ekleri ve sosları eksiksiz söyleyen bir cümledir.
2. Ürünü seç (◀ ▶), tabanı al (**tırnaklı ekmek**; beyranda **kâse**), ana malzemeyi (nohut, döner…) porsiyon porsiyon ekle, piyaz / acı / kızartma / sosları ekle → **SAR** (beyran: **SERVİS ET**) → müşteriye ver. Her şey hem **dokunarak** hem **sürükleyerek** yapılır: malzemeyi tezgâha, hazır dürümü müşteriye sürükle. Tezgâhta **aynı anda 3 dürüm** hazırlanır; sıcak yemeklerin (ekmek, nohut, dürümler) üstünden buhar çıkar.
3. **Her malzeme kasadan para düşer**; satış fiyatı = malzeme maliyeti × 1,3 (**%30 kâr**). Çöpe atılan ya da yanlış yapılan dürümün parası geri gelmez. Kasa bitince usta günde bir kez avans verir.
4. Tam tutarsa tam ücret, 1 hata %60, 2+ hata %25. **Bahşiş kavanoza** düşer, kavanoza dokununca kasaya geçer. **Yetişemediğin müşteri −10 ₺** cezası getirir.
5. Gün 07:00'de başlar, müşteriler bitince 23:00'te kapanır; pencerede güneş ve ay yürür, akşam turuncu, gece mavi olur, lambalar yanar. Gün sonu bilançosu: kazanç, bahşiş, kira, malzeme (çöpe giden), ceza, net kâr, elmas.
6. Kapıya **Gezgin** gelirse (her 10 serviste bir) servis edince 1 **elmas** bırakır; Bölüm 4+'ta **kurye** kapıya gelir, dokununca ısı kutusundaki paketleri alıp ödeme yapar.

## Ürünler ve para birimleri
| Bölüm | Açılanlar |
|---|---|
| 1 | Nohut dürümü, piyaz, acı |
| 2 | Sos, ketçap, mayonez, sumak, kızartma eki |
| 3 | Döner dürümü, nar ekşisi |
| 4 | Kavurma dürümü, çiğ köfte dürümü |
| 5 | Kızartma dürümü, beyran (kâsede) |

- **₺ (para):** satıştan; **elmas:** reklam (günde 3), Gezgin müşteri (+1), **3 gün üst üste günlük görev** (+2). Elmas otomasyon modülleri (otomatik ekmek açıcı, nohut koyucu, sarıcı, ek malzeme) ve lüks dekor için harcanır; fiyatlar bölümle artar.
- **Tarif Defteri** (HUD'da *Tarif*): ürünlerin ne olduğu, görseli, maliyeti ve fiyatı; kilitli ürünler silüet.
- **Mekân temaları** bölümle lüksleşir: Mahalle Esnafı → Çarşı Lokantası → Antep Lokantası → Saray Sofrası; dekorlar para (+ elmas) ile alınır.
- Reklam şimdilik **sahte bir geri sayımdır** (`GameController._grantAd`); mağaza öncesi AdMob'a bağlanır.

## Bölümler (≈ 30+ oyun günü)
| # | Bölüm | Yenilik |
|---|---|---|
| 1 | Çırak Elleri | Öğretici, rakip dükkân, Gariban |
| 2 | Piyazın Sırrı | Bilmeceli siparişler, sumak, Taaf Nene |
| 3 | Gastronomi Şenliği | Yardımcı Çırak (otomasyon), itfaiyeci, yatırımcı |
| 4 | Sipariş Kapında | Arka bahçe (maydanoz/soğan/biber) ve Kapında paket servis (kutu + kurye) |
| 5 | Kayıp Tandır Taşı | Soruşturma: mekân incele, şüpheli sorgula, ipucu topla, suçla |

7. **5 hakkın** var: yetişemeyip giden her müşteri bir hak götürür. Haklar bitince oyun biter; **reklam izleyerek** (günde bir kez) kaldığın yerden devam edersin ya da günü baştan başlarsın.
8. Oyunu kapatıp açınca **DEVAM** ile yarım kalan günden devam edersin (müşteriler, tezgâhlar, sayaçlar kaydedilir). İlk açılışta kısa bir **oynanış tanıtımı** gösterilir (Ayarlar → *Oynanışı göster* ile tekrar).

Her bölümde ana görev zinciri, yan görevler ve her gün 3 günlük görev ("Usta'nın Defteri"). Gariban'a yardım edersen (iyilik) sonra yatırımcı olarak döner; Maskeli Müşteri yanlış siparişte kasadan para çalar.

## Ayarlar ve sıralama
- **Rahat mod** (müşteriler %25 daha sabırlı), **ses efektleri** aç/kapa — başlık ekranındaki *Ayarlar*.
- **Mahalle Sıralaması:** hafta / tüm zamanlar, kendi sıran, takma ad. Sunucu yoksa otomatik olarak bu cihazın kayıtlarına düşer.

### Çevrimiçi sıralama sunucusu (isteğe bağlı)
**Yerelde hızlı başlangıç:** `powershell -File server\leaderboard\start-local.ps1` (ilk çalıştırmada `.secret` anahtarını üretir; veri `data.json`'a yazılır, ikisi de git dışı). Web: `--dart-define=LEADERBOARD_URL=http://127.0.0.1:8787`; telefon: bilgisayarın yerel ağ adresi (`http://192.168.x.x:8787`, Windows güvenlik duvarında 8787 izni gerekir) — emülatörde `http://10.0.2.2:8787`. Debug APK'da düz http açıktır; **release derlemede https gerekir**. Canlıya taşırken yalnızca `LEADERBOARD_URL` değişir; `data.json` ve `.secret` dosyalarını yeni sunucuya kopyalarsan skorlar korunur.

`server/leaderboard/` bağımlılıksız Node (≥20) sunucusudur.
```powershell
cd server\leaderboard
$env:SECRET='uzun-rastgele-bir-anahtar'   # istemciyle aynı olmalı
node server.js                            # PORT=8787, DATA_FILE=data.json, MAX_DAY_SCORE=10000, TRUST_PROXY=1
node --test test/*.test.js                # sunucu testleri
```
Uygulamayı sunucuya bağlamak için derlerken: `flutter build apk --dart-define=LEADERBOARD_URL=https://sunucu.example --dart-define=LEADERBOARD_SECRET=...` (adres verilmezse yalnızca yerel sıralama çalışır).
**Canlı eşitleme ve yönetim sayfası (yalnızca test amaçlı):** oyun her ~3 sn'de para/elmas/gün/toplam puanını `POST /profile` ile bildirir. `ADMIN_TOKEN` ortam değişkeni verilirse `http://sunucu/admin` sayfası açılır (`start-local.ps1` bunu `.admin` dosyasından üretir ve yazdırır); oradan oyuncunun para, elmas, gün, skor ve takma adı düzenlenir ya da oyuncu silinir, oyun değişikliği birkaç saniye içinde alır (sürüm numarası + ack protokolü; değişiklik oyuncunun eski durumuyla ezilmez). Sıralama ekranı açıkken 3 sn'de bir kendini yeniler. **Canlıya geçerken `ADMIN_TOKEN` verme: yönetim sayfası ve API kapanır.**
Sunucu: `POST /scores`, `POST /profile`, `GET /leaderboard?period=week|all&device=…`, `/admin` (anahtarlı), istek başına hız sınırı, gövde sınırı, skor üst sınırı, gün sırası ve imza (HMAC) denetimi, tekrar gönderim engeli.
**Sınırlama:** HMAC anahtarı uygulamanın içinde olduğu için yalnızca sıradan oynamayı engeller; kararlı bir hileciyi durdurmaz. Takma ad dışında kişisel veri toplanmaz; yayından önce bir gizlilik metni eklenmelidir.
Gerçek sunucuya karşı uçtan uca deneme: sunucuyu başlatıp `$env:LB_URL='http://127.0.0.1:8787'; flutter test test/e2e_leaderboard_test.dart`.

## Karakterler ve konuşma kuralları
- **20 müşteri:** 10 kadın (Fatma, Hattuç, Zennup, Şehriban, Emine, Hayce, Ayyuş, Yumma, Lütfiye, Şakire) ve 10 erkek (Maamed, Hösün, Ökkeş, Cımaali, Mustafa, Ahmet, Ali, Mehmet Ali, Höggeş, Memik); her birinin kendine ait ad ve görünümü var. Yaşlı erkeğe usta **"ammi"** der (Antep ağzındaki söyleyiş), yaşlı kadına "deze" (teyze), genç kadına "bacı", genç erkeğe "Rafık".
- **Hikâye karakterleri:** Gariban, Taaf Nene, Galaycı Nuru, İtfaiyeci Mömet, Maskeli Müşteri (iç kimlikleri `dayi / nine / antikaci / itfaiyeci / maskeli`).
- **Hayırlı işler / bereket versin:** Müşteri giderken **"hayırlı işler"** der, "bereket versin" demez; **"bereket versin"i yalnızca usta söyler** (`usta_bereket`). Kural `test/dialog_rules_test.dart` ile korunur.
- **Açılış:** Her yeni günün başında kepenk açılır, ekranda **"Ya Fettah, Ya Rezzak"** yazar (`assets/sfx/yafettah.mp3` kullanıcının kaydı + üretilmiş `kepenk.wav`); dokununca atlanır (`lib/ui/intro_overlay.dart`).
- Kadro betiği: `tools/set_customer_roster.py`; sprite'lar `tools/blender/chars.py` (`CHARS` içinde ad = sprite öneki).

## Klasörler
| Yol | İçerik |
|---|---|
| `lib/game/` | Oyun durumu (`game_controller.dart`), olaylar, puanlama |
| `lib/quest/` | Görev motoru (bölüm, ana/yan/günlük görevler) |
| `lib/modes/` | Bahçe, paket servis, soruşturma |
| `lib/leaderboard/`, `lib/audio/` | Sıralama istemcisi (yerel + uzak), ses |
| `lib/dialog/antep_dialog.dart` | Replik motoru (`kim → kime`); metinler `assets/dialog/*.json` |
| `lib/ui/` | Sahne, bileşenler, ekranlar |
| `assets/data/` | `game.json` (denge), `quests.json`, `riddles.json`, `detective.json` |
| `assets/sprites/`, `assets/sfx/` | Blender çıktıları (PNG), üretilmiş ses efektleri (WAV) |
| `tools/` | `blender/` sprite betikleri (`chars`, `items`, `items2`, `bg` temaları, `decor`), `gen_dialog.py`, `add_v3_economy.py`, `rescale_quests_v3.py`, `gen_sfx.py`, `contact_sheet.py` |
| `server/leaderboard/` | Sıralama sunucusu + testleri |
| `test/` | Birim, widget ve ekran görüntüsü testleri |

## Komutlar
```powershell
C:\src\flutter\bin\flutter.bat test
C:\src\flutter\bin\flutter.bat analyze
C:\src\flutter\bin\flutter.bat run -d chrome
C:\src\flutter\bin\flutter.bat build apk --debug

# Ekran görüntüleri (gerçek yazı tipiyle)
$env:SHOTS='C:\atmp\review\shots'; C:\src\flutter\bin\flutter.bat test test/shots_test.dart

# Görselleri Blender ile yeniden üret (TEMP kısa yolda olmalı)
$env:TEMP='C:\atmp'; $env:TMP='C:\atmp'
& 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe' -b -P tools\blender\build_assets.py -- assets\sprites items   # items | chars | bg | decor

python tools/gen_sfx.py assets/sfx      # ses efektleri
```
Android derlemesi için JDK 21 ve Android SDK (platform 36, NDK 28.2) gerekir; `TEMP`/`java.io.tmpdir` kısa yolda (`C:\atmp`) olmalıdır.

## Antep ağzı
Kaynak: Kültür Portalı "Antep Ağzı" sayfası ve örnekler ("Hoşgeldin Rafık", "Hoşbuldum Rafık", "Hele bi nohut dürümü ver de yiyek yav"). Replikler `assets/dialog/` altındadır; **"gari" gibi yerel olmayan sözcükler yasaktır (test zorlar)** ve metinler **bir Antepli tarafından gözden geçirilmelidir**.
