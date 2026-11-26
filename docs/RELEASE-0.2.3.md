# Luma 0.2.3 · build 11

Discord güncelleyicisinin TLS 1.2 bağlantısında mevcut yöntemlerle takılabildiği bir ağ durumu için **Uyumlu TLS** yöntemi eklendi. Bu yöntem, ByeDPI'nin `--tlsrec 1` ayarını kullanır; TLS sertifika doğrulaması ve şifreleme korunur. Önceki yöntemler kullanılabilir durumda kalır.

Bağlantı kontrolü artık güncelleme sunucusunu hem normal TLS seçimiyle hem TLS 1.2 ile kontrol eder. Normal istek başarılı olsa da güncelleyici uyumluluğu başarısızsa bunu ayrı gösterir ve Uyumlu TLS yöntemini önerir. Yeniden bağlanma başlarken önceki durum bildirimi temizlenir.

23 birim testi ve Uyumlu TLS seçeneğiyle 11 motor entegrasyon kontrolü geçti. Bu sonuçlar konsolda ses testi veya yönetici yardımcısı kurulumu testi değildir.

ARM64 ad-hoc imzalı geliştirme sürümüdür; Apple noter onayı yoktur. PS5 yardımcısının önceki geliştirme sürümlerinden kalan imza/kayıt sorunu bu Mac odaklı düzeltmenin kapsamında değildir.
