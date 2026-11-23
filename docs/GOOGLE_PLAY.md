# Google Play hazırlığı

| Gereksinim | Durum |
|---|---|
| Android App Bundle (.aab) | CI'da `tools/godot-android-aab.sh` (Gradle, hedef SDK 36, min SDK 24) ile üretilir, sürümde APK'nın yanına eklenir. Adım `continue-on-error`: AAB başarısız olsa da APK yayınlanır — ilk çalıştırmada CI günlüğünü kontrol et. |
| Hedef API | AAB ön ayarı `target_sdk=36` (Play: yeni uygulama ve güncellemeler 31 Ağustos 2026 — uzatmayla 1 Kasım 2026 — sonrası API 36). APK da Godot 4.8 varsayılanıyla API 36 hedefler. |
| 64 bit | APK artık yalnızca arm64-v8a (32 bit armeabi-v7a çıkarıldı, ~25 MB küçüldü). AAB her iki mimariyi de içerir; Play cihaza uygun olanı dağıtır. |
| İmza | `android/keystore/kayipkuleler.jks` (APK ile aynı yükleme anahtarı; Play App Signing'e yüklenebilir). |
| Gizlilik politikası | `web/gizlilik.html` — veri toplanmaz, yalnızca cihazda kayıt. GitHub Pages ya da herhangi bir statik sunucuda yayınlanıp Play Console'a bağlantısı girilir. |
| Mağaza görselleri | `store/feature_graphic.png` (1024×500), `store/screenshots/*.png` (1920×1080). |
| Uygulama simgesi | `art/icon-4096.png` → `tools/make_icons.py` (512 px mağaza simgesi: `android/store/icon-512.png`). |
| İçerik derecelendirmesi | Şiddet/satın alma/reklam yok; anket "Herkes" sonucunu verir. |

## Gönderim öncesi denetim (`tools/check_play_compliance.py`)

[mjmirza/app-store-compliance](https://github.com/mjmirza/app-store-compliance) kural setinin bu projeye uyan Android
kuralları, derlenmiş APK/AAB manifestine uygulanır (o betik Gradle kaynak dosyası arar; Godot bunları dışa aktarımda
ürettiği için doğrudan çıktı okunur). CI her sürümde çalıştırır; kritik bulguda iş kırmızıya döner.

| Kural | Durum (v3.0.2) |
|---|---|
| GOOGLE-TARGET-API (≥ 36) | APK 36 ✓ · AAB 35 ✗ → AAB betiği 36'ya çekildi |
| ANDROID-DEBUGGABLE-RELEASE | ✓ |
| ANDROID-INSECURE-BACKUP | allowBackup=false ✓ |
| Hassas izinler (SMS, konum, kişiler, AD_ID, tüm dosyalar, medya…) | hiçbiri istenmiyor ✓ |
| 64 bit | arm64-v8a ✓ |

Elle yapılacaklar (tarama bunları göremez):
* **Veri Güvenliği formu:** veri toplanmıyor, paylaşılmıyor (analitik / reklam SDK'sı yok). Fotoğraf modu kareleri
  yalnızca cihaza yazılır.
* **Gizlilik politikası URL'si:** `web/gizlilik.html` yayınlanıp girilir.
* **İçerik derecelendirmesi (IARC):** şiddet / satın alma / reklam yok.
* **Yeni kişisel geliştirici hesabı:** üretime çıkmadan önce en az **12 testçi ile 14 gün kesintisiz kapalı test**.
* **1 Şubat 2027:** AB/Birleşik Krallık için her hesapta "tüccar / tüccar değil" beyanı.

