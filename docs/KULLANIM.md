# Luma — yerel deneme sürümü

Luma, Discord bağlantı motorunu ve PS5 paylaşımını tek bir macOS uygulamasında toplar. SplitWire’ın kurulu olması gerekmez.

## Mac’te Discord

1. Uygulamayı Uygulamalar klasörüne taşı.
2. **Bağlan ve Discord’u aç** düğmesine bas.
3. Discord zaten açıksa tamamen kapatıp Luma’dan tekrar başlat. Luma, devam eden görüşmeni zorla sonlandırmaz.
4. **Bağlantı kontrolü** ekranından erişimi sınayabilirsin.

Discord’un kendi güncelleme mekanizması açık kalır; Luma uygulama trafiği ile güncelleyiciye uygun bağlantı ayarlarını birlikte verir. Bağlantı yöntemini değiştirmek için Ayarlar’dan motoru durdur, yöntemi seç ve tekrar başlat.

## PS5

Mac ve PS5 aynı yerel IPv4 ağında olmalı. PS5’in Ethernet kablosu router’da kalabilir; Mac Wi-Fi kullanabilir.

1. **PS5 kurulumu** ekranına konsolun IP adresini gir.
2. Paylaşım yardımcısını macOS üzerinden bir kez onayla. Yönetici parolanı yalnızca macOS’un kendi izin ekranına gir.
3. Paylaşımı başlat ve ekrandaki IP, alt ağ, ağ geçidi ve DNS değerleriyle PS5’te ayrı bir LAN profili oluştur.
4. Eski otomatik LAN profilini sakla. Normal bağlantıya dönmek için PS5’te onu seç; sonra Luma paylaşımını durdur.

Mac paylaşım boyunca açık ve uyanık kalmalı. Ekranı kapatmakla dizüstünün kapağını kapatmak aynı şey değildir. Adreslerin değişmemesi için router’da DHCP rezervasyonu yapılması önerilir.

Bu paylaşım IPv4 içindir. PSN oturumu, iki yönlü Discord sesi, oyun bağlantısı ve NAT tipi ayrıca kontrol edilmelidir. Tanılama ekranındaki başarılı HTTPS testleri konsoldaki ses testinin yerine geçmez.

## Kaldırma

Önce PS5’i normal LAN profiline geçir. Luma’da paylaşımı ve motoru durdur. Ayarlar → **Yardımcı kaydını kaldır** seçeneğini kullan, varsa açılışta başlatmayı kapat, ardından uygulamadan çıkıp uygulamayı kaldır.

## Bu paketin durumu

Yerel paket ad-hoc imzalıdır; Apple tarafından noter onayı verilmiş bir genel dağıtım değildir. Yayımlamadan önce dağıtım kimliğiyle imzalama, Apple noter onayı ve temiz cihaz testleri tamamlanmalıdır. Güvenlik uyarılarını kapatmak veya atlamak kurulum yöntemi değildir.

## Açma, kapatma ve yeniden bağlanma

Genel bakış ekranındaki **Bağlantıyı aç / Bağlantıyı kapat** düğmesi ortak motoru yönetir. Kapatınca PS5 paylaşımı da durur; konsolda normal LAN profilini seçin. Uygulama penceresini açık tutmanız bağlantının açık olması anlamına gelmez.

Discord açık olduğu halde bağlanmıyorsa **Yeniden bağlan** seçeneğini kullanın. Onay verdikten sonra Discord normal şekilde kapanıp doğru proxy ayarlarıyla yeniden açılır; devam eden görüşme kesilir.

Discord güncelleme ekranında “Update failed” döngüsünde kalırsa motoru durdurun, Ayarlar → **Uyumlu TLS** yöntemini seçin, ardından Discord’u **Yeniden bağlan** ile açın. Bağlantı kontrolündeki TLS 1.2 testi bu uyumsuzluğu ayrıca sınar. Ağınıza göre diğer yöntemler daha uygun olabilir.

Discord büyük bir güncellemeyi kurduktan sonra kendini Luma proxy ayarları olmadan yeniden başlatabilir. Güncelleme sonrası tekrar hata ekranı gelirse Luma’daki **Yeniden bağlan** düğmesini bir kez kullanın. Discord’u Dock’tan doğrudan açmak yerine Luma’dan açın.

## Discord güncellemeleri

Luma bağlantısı açıkken “Discord bağlantısını otomatik koru” seçeneği, güncelleme sonrası bağlantı ayarlarını kaybeden Discord'u otomatik yeniden açar. Discord kendi güncellemelerini kendisi kontrol eder ve yükler. Luma penceresini kapatabilirsiniz; uygulama ve bağlantı açık kalmalıdır. Bağlantıyı kapatırsanız otomatik düzeltme de durur. Art arda yeniden açılma algılanırsa denemeler durdurulur ve hata gösterilir.
