# Luma

Mac’te Discord’u ve PlayStation 5’i bağlamak için küçük bir macOS uygulaması.

- **Mac’te Discord:** Discord’u Luma üzerinden açarsın, bağlanır.
- **PS5:** Mac’in internet bağlantısını aynı evdeki PS5’inle paylaşır.

Hesap açman, VPN alman ya da başka bir şey kurman gerekmez. Her şey uygulamanın içinde.

---

## Kurulum

### Önce şunlara bak

- **Mac’in Apple Silicon olmalı** (M1, M2, M3, M4…). Emin değilsen sol üstteki  menüsü → **Bu Mac Hakkında**’ya tıkla. “Çip” satırında **Apple M…** yazıyorsa tamamsın. **Intel** yazıyorsa Luma bu Mac’te çalışmaz.
- **macOS 14 (Sonoma) veya daha yenisi** olmalı. Aynı pencerede yazar.
- **Discord kurulu olmalı.** Yoksa önce [discord.com](https://discord.com/download)’dan indirip kur.

### 1. İndir

👉 **[Luma’yı indir (Luma-macOS-arm64.zip)](../../releases/latest/download/Luma-macOS-arm64.zip)**

Bağlantı çalışmazsa sağ taraftaki **Releases** bölümüne gir. En üstteki sürümün altından **Luma-macOS-arm64.zip** dosyasına tıkla.

### 2. Uygulamalar klasörüne at

1. İndirilenler klasörüne git. Zip dosyasına çift tıkla, **Luma** uygulaması çıkacak.
2. **Luma**’yı tutup Finder’ın solundaki **Uygulamalar** (Applications) klasörüne sürükle.

> ⚠️ Bu adımı atlama. Luma, Uygulamalar klasöründe değilse PS5 paylaşımı çalışmayabilir.

### 3. İlk açılış (sadece bir kere)

Luma, Apple’a para verilip “onaylatılmış” bir uygulama değil. Bu yüzden macOS ilk açılışta seni uyaracak. Bu normal, şöyle geçiyorsun:

1. Uygulamalar klasöründe **Luma**’ya çift tıkla.
2. “Luma açılamıyor” ya da “Apple doğrulayamadı” gibi bir uyarı çıkar. **Bitti** (Done) de. **Çöp Sepetine Taşı deme.**
3.  menüsü → **Sistem Ayarları** → soldan **Gizlilik ve Güvenlik**’e gir.
4. Sayfanın en altına in. **“Luma engellendi…”** yazısının yanında **Yine de Aç** düğmesi var, ona bas.
5. Mac şifreni ister, gir.
6. Bir uyarı daha çıkarsa **Yine de Aç** de.

Bu kadar. Bir daha sormaz, artık normal açılır.

<details>
<summary>“Yine de Aç” düğmesini bulamadım</summary>

Önce 1. adımı bir kez daha yap, düğme ancak Luma’yı açmayı denedikten sonra çıkar. Yine yoksa **Terminal**’i aç (Spotlight’a “Terminal” yaz), şunu yapıştırıp Enter’a bas:

```bash
xattr -dr com.apple.quarantine /Applications/Luma.app
```

Sonra Luma’yı normal şekilde aç.
</details>

---

## Mac’te Discord’u bağlama

1. Luma’yı aç.
2. **Discord açıksa önce tamamen kapat**: Discord’a tıkla, klavyede **⌘ + Q**’ya bas.
3. Luma’da **Bağlantıyı aç** düğmesine bas. Luma bağlantıyı kurar ve Discord’u kendisi açar.

Bu kadar. 🎉

**Önemli:** Discord’u bundan sonra hep **Luma’dan** aç (**Discord’u aç** düğmesi). Dock’tan ya da Launchpad’den açarsan bağlanmaz.

Luma’nın penceresini kapatabilirsin. Uygulama üstteki menü çubuğunda (saatin yanında) çalışmaya devam eder. Tamamen kapatmak için menü çubuğundaki Luma simgesi → **Çık**.

---

## PS5’e bağlantı paylaşma

Mac ile PS5 **aynı modeme** bağlı olmalı (aynı ev ağı). Mac Wi-Fi’dan bağlı olabilir, kablo gerekmez.

### A. PS5’in adresini öğren

PS5’te: **Ayarlar → Ağ → Bağlantı Durumu → Bağlantı Durumunu Görüntüle**. **IPv4 Adresi** satırını bir kenara yaz. `192.168.1.35` gibi bir şeydir.

### B. Luma’da ayarla

1. Luma’da soldan **PS5 kurulumu**’na gir.
2. PS5’in adresini kutuya yaz.
3. **Paylaşım iznini ayarla** düğmesine bas. Sistem Ayarları açılır. **Giriş Öğeleri ve Uzantılar** bölümünde **Luma**’nın düğmesini aç. Mac şifreni isterse gir. Bunu sadece ilk seferde yaparsın.
4. Luma’ya dön, **Paylaşımı başlat**’a bas.
5. Ekranda **PS5 ağ ayarları** listesi çıkar (IP adresi, alt ağ maskesi, ağ geçidi, DNS). Bu ekranı açık bırak.

### C. PS5’e bu ayarları gir

1. PS5’te: **Ayarlar → Ağ → Ayarlar → İnternet Bağlantısını Kur**.
2. Şu an kullandığın bağlantının üstüne gel, kumandada **Options** tuşuna bas → **Gelişmiş Ayarlar**.
3. **IP Adresi Ayarları**’nı **Manuel** yap. Luma’daki değerleri tek tek gir:
   - **IP adresi**: PS5’in adresi
   - **Alt ağ maskesi**: Luma’da ne yazıyorsa
   - **Varsayılan ağ geçidi**: Luma’daki **Ağ geçidi** değeri (bu Mac’in adresidir)
   - **Birincil DNS**: `1.1.1.1`
   - **İkincil DNS**: `1.0.0.1`
4. **MTU**: Otomatik. **Proxy sunucusu**: Kullanma.
5. Kaydet, sonra **İnternet Bağlantısını Test Et**.

*(Menü adları PS5 yazılım sürümüne göre biraz farklı olabilir.)*

### Normale dönmek

1. PS5’te aynı yere girip **IP Adresi Ayarları**’nı tekrar **Otomatik** yap. DNS’i de **Otomatik** yap.
2. Sonra Luma’da **Paylaşımı durdur**’a bas.

> 💡 Paylaşım açıkken Mac açık kalmalı. Dizüstünün kapağını kapatma, Mac uyursa PS5’in interneti gider. Ekranı kapatmak sorun değil.

> 💡 PS5’in adresi arada değişiyorsa her seferinde Luma’ya yeniden yazman gerekir. Bunu önlemek için modem ayarlarından PS5’e sabit adres verebilirsin (“DHCP rezervasyonu”).

---

## Bir şey ters giderse

| Sorun | Ne yapmalı |
|---|---|
| Discord açılıyor ama bağlanmıyor | Luma’da **Yeniden bağlan**’a bas. Discord kapanıp doğru ayarlarla açılır. |
| Discord “Update failed” ekranında takılıyor | Luma’da **Bağlantıyı kapat** → **Ayarlar** → yöntemi **Uyumlu TLS** yap → **Bağlantıyı aç**. |
| Hâlâ olmuyor | **Ayarlar**’dan diğer bağlantı yöntemlerini tek tek dene. Her değişiklikten önce bağlantıyı kapatman gerekir. |
| Neyin bozuk olduğunu anlamak istiyorum | Soldan **Bağlantı kontrolü** → **Kontrolleri çalıştır**. Hangi adımın kırmızı olduğuna bak. |
| PS5’te internet yok | Mac uyanık mı? Luma’da paylaşım **açık** mı? PS5’in adresi değişmiş olabilir, A adımını tekrar kontrol et. |
| “Paylaşım iznini ayarla” hata veriyor | Luma’nın **Uygulamalar** klasöründe olduğundan emin ol, Luma’yı kapatıp tekrar aç. |

Çözemezsen **Issues** sekmesinden yaz. **Bağlantı kontrolü** ekranındaki **Raporu kaydet** dosyasını da ekle. Bu dosyada IP adresin veya kişisel bilgin yoktur.

---

## Güncelleme

Yeni sürüm çıkınca kurulumdaki gibi yeni zip’i indir. Luma’yı kapat (menü çubuğu → **Çık**). Yeni Luma’yı Uygulamalar klasörüne sürükleyip **Değiştir** de. İlk açılış adımlarını yeniden yapman gerekebilir.

## Kaldırma

1. PS5’i normale döndür (yukarıdaki **Normale dönmek** adımları).
2. Luma’da **Bağlantıyı kapat**’a bas.
3. **Ayarlar** → **Paylaşım yardımcısı** → **Kaydı kaldır**.
4. Luma’dan çık, Uygulamalar klasöründen Luma’yı Çöp Sepeti’ne at.

---

## Bilmen gerekenler

- Luma bir VPN değildir. Seni gizlemez, IP adresini değiştirmez.
- Hesap, reklam ya da veri toplama yoktur. Hiçbir yere bilgi göndermez.
- Discord veya Sony ile resmî bir bağlantısı yoktur.
- Çalışıp çalışmaması internet sağlayıcına göre değişebilir.
- Uygulama Apple Developer ID ile imzalı ve Apple noter onaylı değildir. İlk açılıştaki uyarı bu yüzden çıkar.

---

## Geliştiriciler için

### Derleme ve test

Apple Command Line Tools ve Swift 6 veya üzeri gerekir.

```sh
./scripts/build.sh
./scripts/test.sh
python3 scripts/integration_test.py dist/Luma.app
python3 scripts/supervisor_test.py dist/Luma.app
```

Ağ testlerinden önce uygulamadaki motoru durdurun. Derleme bağımlılıkları sabit sürüm ve SHA-256 ile doğrulanır. Çıktı Spotlight’ın taramadığı `dist.noindex/` klasörüne yazılır, `dist` bu klasöre bağlantıdır.

Varsayılan derleme yerel ad-hoc imza kullanır. Developer ID ile imzalama ve noter onayı için [dağıtım adımları](docs/DISTRIBUTION.md)’na bakın.

### Sürüm yayınlama

1. `Resources/Info.plist` ve `Sources/LumaCore/Core.swift` içindeki sürümü artırın, `docs/RELEASE-<sürüm>.md` notunu yazın.
2. Commit’leyip etiketleyin: `git tag v0.2.5 && git push origin main v0.2.5`
3. [Release iş akışı](.github/workflows/release.yml) testleri çalıştırır, uygulamayı derler ve GitHub Release’e `Luma-macOS-arm64.zip` ile `SHA256SUMS.txt` dosyalarını yükler.

### Gizlilik ve güvenlik

Proxy’ler yalnızca loopback üzerinde dinler. Yönetici yardımcısı uygulamanın imzasını doğrular ve yalnızca seçilen konsolu yönlendirir. Ağ ayarları kapatmada geri alınır. Konsol adresi yalnızca kullanıcının kendi macOS tercih alanında saklanır.

[Kullanım](docs/KULLANIM.md) · [Mimari](docs/ARCHITECTURE.md) · [Güvenlik](SECURITY.md) · [Test planı](docs/TESTING.md)

### Lisanslar

Luma MIT lisanslıdır. ByeDPI v0.17.3 (MIT) ve tun2socks v2.7.0 (MIT) kullanır. ByeDPI için macOS kapanış düzeltmesi `patches/` altındadır. Bileşenlerin ve bağımlılıkların lisansları `Resources/Licenses` altında ve uygulamanın Hakkında bölümünde yer alır.
