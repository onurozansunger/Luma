# Luma 0.2.1 · build 8

- Genel bakış ve menü çubuğuna bağlantı aç/kapat kontrolü eklendi.
- Kapatma, önce PS5 yönlendirmesini temizler; ardından motoru durdurup proxy portlarının kapandığını doğrular. Paylaşım durdurulamazsa motor açık bırakılır ve hata gösterilir.
- Discord için Yeniden bağlan eklendi. Kullanıcı onayından sonra Discord normal şekilde kapatılır ve Luma proxy ayarlarıyla yeniden açılır. Zorla kapatma uygulanmaz.
- Uygulama penceresi açıkken bağlantı kapalı kalabilir. PS5 paylaşımı otomatik başlamaz.

Yerel doğrulama: Mac Discord arkadaşlar ekranı ve çevrim içi durumu; yeniden bağlanma; yalnız motoru kapatma; PS5 ve motoru birlikte kapatma; yönlendirme ayarlarının geri alınması ve motorun launchd kaydının kaldırılması kontrol edildi. Birim test sonuçları ayrı doğrulama raporundadır.

ARM64 ad-hoc imzalı geliştirme sürümüdür; Developer ID ve Apple noter onayı yoktur. Güncellemeden sonra macOS eski yardımcı imzasını tutarsa, paylaşım kapalıyken Sistem Ayarları → Genel → Giriş Öğeleri içindeki Luma arka plan iznini kapatıp yeniden açmak kayıt yenilemesini sağlar. Genel dağıtım öncesi temiz Mac ve imzalı güncelleme testleri gereklidir.
