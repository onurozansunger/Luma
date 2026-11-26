# Luma

Discord ve PlayStation 5 için yerel macOS bağlantı yöneticisi.

## Kullanım

1. Uygulamayı Uygulamalar klasörüne taşıyın.
2. Mac’te Discord için **Bağlan** düğmesini kullanın. Discord zaten açıksa bir kez tamamen kapatıp uygulamadan yeniden açın.
3. **PS5 kurulumu** bölümüne kendi konsolunuzun IPv4 adresini girin. İlk kurulumda bu alan boştur. Mac’in adresi, alt ağ maskesi ve router adresi bağlı olduğunuz ağdan otomatik okunur.
4. macOS paylaşım iznini tamamlayın ve paylaşımı başlatın.
5. Ekrandaki değerleri PS5’te ayrı bir LAN profiline kaydedin. Normal otomatik profilinizi saklayın.

Mac ve konsol aynı özel IPv4 alt ağında olmalıdır. Ek kablo gerekmez; Mac Wi-Fi kullanabilir. Paylaşım boyunca Mac açık kalmalıdır. Adresler değişiyorsa router’da DHCP rezervasyonu kullanın.

Luma bir VPN veya anonimlik hizmeti değildir. Erişim ağ operatörüne göre değişebilir. Discord ve Sony ile resmî bağlantısı yoktur.

## Gereksinimler

- macOS 14 veya üzeri.
- Paketin mimarisiyle uyumlu Mac. Hazır ARM64 paketi Apple Silicon içindir; Intel için ayrı derleme gerekir.
- Mac özelliği için ayrıca kurulmuş Discord.
- PS5 paylaşımı için macOS’un yönetici yardımcısı izni.

Python, Homebrew, SplitWire veya VPN aboneliği çalışma sırasında gerekmez. Motorlar uygulamayla birlikte gelir.

## Derleme ve test

Apple Command Line Tools ve Swift 6 veya üzeri gereklidir.

```sh
./scripts/build.sh
./scripts/test.sh
python3 scripts/integration_test.py dist/Luma.app
python3 scripts/supervisor_test.py dist/Luma.app
```

Ağ testlerinden önce uygulamadaki motoru durdurun. Derleme bağımlılıkları sabit sürüm ve SHA-256 ile doğrulanır. Kaynak ve hata ayıklama yolları anonimleştirilir; kullanıcı ayarları pakete eklenmez.

Varsayılan derleme yerel ad-hoc imza kullanır. Bu, Apple noter onayı değildir. Genel dağıtım için kendi Developer ID kimliğinizi kullanın ve [dağıtım adımlarını](docs/DISTRIBUTION.md) tamamlayın.

## Gizlilik ve güvenlik

Hesap ve telemetri yoktur. Proxy’ler yalnızca loopback üzerinde dinler. Yönetici yardımcısı, uygulamanın imzasını doğrular ve yalnızca seçilen konsolu yönlendirir. Ağ ayarları kapatmada geri alınır. Tanılama raporu kişisel ağ adreslerini ve oturum bilgilerini içermez.

Konsol adresi yalnızca kullanıcının kendi macOS tercih alanında saklanır. Sürüm paketi konsol profili, yerel ayar, ağ kaydı veya kullanıcı kimliği içermez.

[Kullanım](docs/KULLANIM.md) · [Mimari](docs/ARCHITECTURE.md) · [Güvenlik](SECURITY.md) · [Test planı](docs/TESTING.md)

## Lisanslar

Luma MIT lisanslıdır. ByeDPI v0.17.3 ve tun2socks v2.7.0 kullanır. ByeDPI için macOS kapanış düzeltmesi `patches/` altında bulunur. Bileşenlerin ve bağımlılıkların lisansları `Resources/Licenses` altında ve uygulamanın Hakkında bölümünde yer alır.
