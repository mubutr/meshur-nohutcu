# Yayın kurulumu: GitHub → TestFlight + Google Play

`main` dalına her push iki iş akışını başlatır (`.github/workflows/`):

| İş akışı | Ne yapar | Nereye gider |
|---|---|---|
| **Android Release (Google Play)** | analiz + test → imzalı `.aab` | Google Play **Dahili test** kanalı |
| **iOS Release (TestFlight)** | analiz + test → `.ipa` | **TestFlight** |

`server/`, `tools/`, `store/` ve `*.md` değişiklikleri mağaza derlemesi **başlatmaz**.
Secret'lar eksikse iş akışları **hata vermez**: analiz + testi çalıştırır, imza/yükleme adımlarını atlar ve sarı uyarıda eksik secret adını yazar.

**Uygulama kimliği (iOS ve Android aynı):** `com.bigsoft.meshurnohutcu` — mağazaya ilk yüklemeden sonra değiştirilemez.
**Sertifika notu:** iOS için `.p12` / provisioning profile hazırlamana **gerek yok**. App Store Connect API anahtarı (Admin) ile Apple, dağıtım sertifikasını ve profili ilk koşuda kendisi oluşturur (bulutta yönetilen imza).

Gizli değerleri (şifre, anahtar, JSON) **sohbete yapıştırma, depoya koyma**: yalnızca GitHub → Settings → Secrets bölümüne gir.

---

## 1. GitHub'da secret nasıl eklenir
1. https://github.com/mubutr/meshur-nohutcu → **Settings** → soldaki **Secrets and variables** → **Actions**.
2. **Secrets** sekmesi → **New repository secret** → *Name* alanına aşağıdaki adı **birebir** yaz, *Secret* alanına değeri yapıştır → **Add secret**.
3. Tüm secret'lar: `APPLE_TEAM_ID`, `APP_STORE_CONNECT_KEY`, `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`, `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`, `PLAY_SERVICE_ACCOUNT_JSON` (toplam 9).

---

## 2. iOS → TestFlight

### 2.1 Apple Developer üyeliği ve Team ID
1. https://developer.apple.com/account → üyelik **aktif** olmalı (yıllık 99 USD). Bireysel→kurumsal geçiş talebi bekliyorsa üyelik geçici "aktif değil" görünür; derleme "Team ID is not associated with an active membership" hatası verir.
2. Aynı sayfada **Membership details** → **Team ID** (10 karakter, örn. `AB12CD34EF`) → secret **`APPLE_TEAM_ID`**.

### 2.2 Bundle ID'yi kaydet
1. https://developer.apple.com/account/resources/identifiers/list → **+** → **App IDs** → Continue → **App** → Continue.
2. Description: `Meşhur Nohutçu`; Bundle ID: **Explicit** → `com.bigsoft.meshurnohutcu`. Capability seçmene gerek yok → Continue → **Register**.

### 2.3 App Store Connect'te uygulamayı oluştur (elle; API ile yapılamaz)
1. https://appstoreconnect.apple.com → **Apps** → **+** → **New App**.
2. Platforms: **iOS**; Name: `Meşhur Nohutçu` (başkası almışsa ad değişir; sonra değiştirilebilir); Primary Language: **Turkish**; Bundle ID: listeden `com.bigsoft.meshurnohutcu`; SKU: `meshurnohutcu`; User Access: Full Access → **Create**.

### 2.4 API anahtarı (.p8)
1. App Store Connect → **Users and Access** → **Integrations** → **App Store Connect API** → **Team Keys** → **Generate API Key** (ilk kez ise önce "Request Access").
2. Name: `GitHub Actions`; Access: **Admin** (otomatik imza için gerekli) → Generate.
3. Listede **Download API Key**: `AuthKey_XXXXXXXXXX.p8` dosyası **yalnızca bir kez** indirilir; güvenli yerde sakla.
4. Aynı sayfada: **Issuer ID** (üstte, `xxxxxxxx-xxxx-…` biçiminde) ve anahtarın **Key ID**'si (10 karakter).

### 2.5 iOS secret'larını gir
| Secret | Değer |
|---|---|
| `APP_STORE_CONNECT_KEY` | `.p8` dosyasını Not Defteri ile aç → **tüm metni** kopyala (`-----BEGIN PRIVATE KEY-----` ve `-----END PRIVATE KEY-----` satırları dahil) |
| `APP_STORE_CONNECT_KEY_ID` | Key ID |
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID |
| `APPLE_TEAM_ID` | 2.1'deki Team ID |

### 2.6 İlk derleme ve TestFlight
1. GitHub → **Actions** → **iOS Release (TestFlight)** → **Run workflow** (ya da `main`'e push). 15–30 dk sürer.
2. Başarılıysa App Store Connect → uygulama → **TestFlight** sekmesinde derleme önce "Processing" görünür (5–30 dk), sonra hazır olur.
3. **İç test:** TestFlight → **Internal Testing** → **+** ile grup oluştur → testçileri ekle. (İç testçi, App Store Connect'te *Users and Access* altında kullanıcı olmalıdır.) Testçi telefonuna **TestFlight** uygulamasını kurup davet e-postasından açar.
4. Sonraki her push yeni derleme ekler; build numarası otomatiktir (`run_number`).
5. Mağazaya çıkış: App Store Connect → sürümü derlemeye bağla → **Submit for Review** (bu düğmeye sen basarsın).

**Sık hatalar:** *Team ID is not associated…* → üyelik aktif değil. *Cloud signing permission error / no profiles* → API anahtarı **Admin** değil. *No account for team* → `APPLE_TEAM_ID` yanlış. *Bundle ID bulunamadı* → 2.2 yapılmamış.

---

## 3. Android → Google Play

### 3.1 Play Console hesabı
https://play.google.com/console → geliştirici hesabı (25 USD, bir kez) + kimlik doğrulama. **Kişisel** hesapta üretime çıkmadan önce **12 test kullanıcısı ile 14 gün kapalı test** zorunludur (kurumsal hesapta yok). Dahili test bu zorunluluktan bağımsızdır.

### 3.2 Upload keystore üret (bir kez) ve YEDEKLE
Windows PowerShell (keytool JDK ile gelir; Android Studio varsa tam yol aşağıdaki gibidir):
```powershell
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -genkeypair -v -keystore "$HOME\upload-keystore.jks" -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```
- Sorulan **keystore şifresini** gir; "key password" sorusunda **Enter'a basarak aynısını kullan** (aynı şifre olsun).
- Ad/kurum sorularını doldur.
- `upload-keystore.jks` dosyasını ve şifreyi **iki ayrı güvenli yerde yedekle**. Dosyayı depoya **koyma** (`.gitignore` zaten engeller).

### 3.3 Keystore'u base64'e çevir
```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("$HOME\upload-keystore.jks")) | Set-Clipboard
```
Panoya kopyalanır → secret **`ANDROID_KEYSTORE_BASE64`** değeri olarak yapıştır.

### 3.4 Android keystore secret'ları
| Secret | Değer |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | 3.3'teki base64 metni |
| `ANDROID_KEYSTORE_PASSWORD` | keystore şifresi |
| `ANDROID_KEY_ALIAS` | `upload` |
| `ANDROID_KEY_PASSWORD` | key şifresi (3.2'de aynısını seçtiysen keystore şifresi) |

### 3.5 Uygulamayı Play Console'da oluştur ve İLK sürümü elle yükle
Paket adı ilk yüklemede kilitlenir; otomatik yükleme ancak bundan sonra çalışır.
1. Önce 3.4'teki 4 secret'ı gir; GitHub → Actions → **Android Release** → **Run workflow**. Bittiğinde koşunun sayfasında **Artifacts → `meshur-nohutcu-aab`** indir, zip'ten `app-release.aab` çıkar.
2. Play Console → **Uygulama oluştur**: ad `Meşhur Nohutçu`, varsayılan dil **Türkçe**, tür **Oyun**, **Ücretsiz**, beyanları işaretle → Oluştur.
3. Sol menü → **Test et ve yayınla** → **Dahili test** → **Yeni sürüm oluştur** → "Play Uygulama İmzalama"ya kaydol (varsayılan, **Devam**) → `app-release.aab` yükle → **Kaydet** → **Sürümü incele** → **Dahili test olarak yayınla**.
4. Dahili test → **Test kullanıcıları** sekmesi → e-posta listesi oluştur (Gmail adresleri) → kaydet. Aynı sayfadaki **"Katılma bağlantısı"** ile testçiler uygulamayı Play'den kurar.
5. Play Console, mağaza girişi ve "Uygulama içeriği" formlarını (gizlilik politikası, reklam beyanı, içerik derecelendirme, veri güvenliği, hedef kitle) tamamlamanı isteyecek; dahili test için hepsi şart değildir, üretim için şarttır (bölüm 5).

### 3.6 Servis hesabı (otomatik yükleme için)
1. https://console.cloud.google.com → üstten **proje oluştur** (örn. `meshur-nohutcu-yayin`).
2. **APIs & Services → Library** → "Google Play Android Developer API" → **Enable**.
3. **IAM & Admin → Service Accounts → Create service account**: ad `play-yayin` → Create → rol atamadan **Done**.
4. Oluşan hesaba tıkla → **Keys** → **Add key → Create new key → JSON** → dosya iner. (Bu JSON'u kimseyle paylaşma, depoya koyma.)
5. Hesabın e-postasını kopyala (`play-yayin@….iam.gserviceaccount.com`).
6. Play Console → **Kullanıcılar ve izinler** (Users and permissions) → **Yeni kullanıcı davet et** → e-posta olarak o adresi yapıştır → **Uygulama izinleri → Uygulama ekle → Meşhur Nohutçu** → izinlerden **Sürümleri yayınla / test kanallarına yayınla** ve **Mağaza girişini yönet** işaretle (üretim sürümü de istiyorsan "Üretim sürümlerini yönet") → Davet gönder.
7. JSON dosyasını Not Defteri ile aç, **tüm içeriği** kopyala → secret **`PLAY_SERVICE_ACCOUNT_JSON`**.
8. İzinlerin yayılması birkaç saati bulabilir; ilk otomatik yüklemede "permission" hatası alırsan bekleyip koşuyu **Re-run** değil, **Run workflow** ile yeniden başlat (versionCode artsın).

### 3.7 Sonrası
`main`'e her push → imzalı AAB → Play **Dahili test** kanalı. Üretime almak için Actions → Android Release → **Run workflow** → `track: production` (kişisel hesapta önce 14 günlük kapalı test koşulu tamamlanmış olmalı). `status: completed` ile üretimde incelemeye gider.
**Not:** `versionCode` her yüklemede öncekinden büyük olmalıdır; iş akışı `run_number + 100` kullanır. *Re-run jobs* aynı numarayı kullanır → yeni sürüm için yeni koşu başlat.

---

## 4. Çevrimiçi sıralama sunucusu (isteğe bağlı, sunucu canlıya alınınca)
Mağaza derlemeleri sunucu adresi olmadan yerel sıralama ile çalışır. Sunucu **https** ile yayında olunca:
- **Variables** sekmesi → **New repository variable** → `LEADERBOARD_URL` = `https://sunucu.adresin`
- **Secrets** → `LEADERBOARD_SECRET` = sunucudaki `SECRET` ile aynı değer
Sonraki derlemeler bunu otomatik kullanır. **Canlı sunucuda `ADMIN_TOKEN` verme** (test yönetim sayfası kapalı kalsın). HMAC anahtarı uygulamaya gömülür; yalnızca sıradan hileyi engeller.

## 5. Mağaza uyum listesi (reddedilmemek için)
- **Gizlilik Politikası URL'si** zorunlu (iki mağazada da). Toplanan veri: rastgele cihaz kimliği, takma ad, skorlar (yalnızca sunucu adresi verildiyse). Hesap/e-posta/konum/kamera yok → **hesap silme** gerekmez ("Uygulama hesap oluşturmuyor" beyanı).
- **Reklam:** oyundaki "reklam izle" şu an **test amaçlı sahte reklamdır**. Gerçek reklam SDK'sı bağlanmadan Play'de "Reklam içerir: Hayır", Apple'da reklam beyanı yok seçilir; SDK eklenince güncelle.
- **Yaş derecelendirmesi:** şiddet/kumar yok → düşük yaş grubu; Apple App Privacy anketi: "Veri toplanmıyor" (sunucu bağlanırsa "Tanımlayıcılar" + "Oyun içeriği/skor" ekle).
- **Ekran görüntüleri:** yatay oyun. Apple iPhone 6.9" için 2868×1320 (veya 1320×2868 tersi), Play için en az 2 telefon görüntüsü ve 1024×500 öne çıkan görsel. Simge: `store/icon_1024.png` (Apple, alfa kanalsız) ve `store/play_icon_512.png` (Play).
- Uygulama yalnızca iPhone ve yatay yönlüdür (iPad ekran görüntüsü gerekmez).

## 6. Her güncellemede
1. Kullanıcıya görünür değişiklik varsa `pubspec.yaml` içindeki `version: 1.0.0+1` kısmının ilk bölümünü artır (`1.0.1`). `+N` build numarasını CI ezer.
2. Commit → **"pushla"** → Actions'ta iki iş akışının yeşil olduğunu izle.
3. iOS: TestFlight'ta Processing bitince test et; Android: Play dahili test bağlantısından güncelle.
