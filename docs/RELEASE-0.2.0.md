# Luma 0.2.0 · build 7

## Değişiklikler

- Açık renkli, yerel macOS kenar çubuğu ve araç çubuğuyla sade arayüz.
- Yeni Luma adı ve uygulama ikonu; tanıtım sloganları ve arayüzdeki açık kaynak bölümü kaldırıldı.
- İlk kurulumda boş konsol adresi alanı. Mac ağ bilgileri otomatik algılanır; konsol adresi kullanıcı tarafından girilir ve alt ağa göre doğrulanır.
- Kişisel kurulumdan ayar içe aktarma kaldırıldı. Kaynak ve derleme yolları dağıtımda kişisel bilgi taşımayacak şekilde düzenlendi.
- Lisanslar Hakkında bölümünden erişilebilir.

## Doğrulama kapsamı

Apple Silicon üzerinde macOS 27 ile: 23 birim testi, 10 motor entegrasyon kontrolü ve 3 launchd kurtarma kontrolü geçti. Boş/geçersiz konsol girdisinde başlatmanın engellendiği arayüzde doğrulandı. Yerel kurulumda yeni yönetici yardımcısının çalıştığı ve paylaşımın açıldığı doğrulandı. Önceki geliştirme sürümünde konsoldan çift yönlü Discord sesi kullanıcı tarafından doğrulandı; bu, farklı ağlar için uyumluluk garantisi değildir.

Bu paket ARM64 için ad-hoc imzalı sürüm adayıdır. Developer ID imzası ve Apple noter onayı yoktur. Genel son kullanıcı dağıtımından önce docs/DISTRIBUTION.md adımları ve temiz Mac kabul testleri tamamlanmalıdır. Intel, macOS 14–26, uyku/yeniden başlatma ve farklı router kombinasyonları bu sürümde doğrulanmadı.

Ürün, kaynak kod ve servis adları Luma olarak yenilendi. Yerel tercihler dağıtım paketine dahil edilmez.
