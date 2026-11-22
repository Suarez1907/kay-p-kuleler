# Google Play hazırlığı

| Gereksinim | Durum |
|---|---|
| Android App Bundle (.aab) | CI'da `tools/godot-android-aab.sh` (Gradle, hedef SDK 35, min SDK 24) ile üretilir, sürümde APK'nın yanına eklenir. Adım `continue-on-error`: AAB başarısız olsa da APK yayınlanır — ilk çalıştırmada CI günlüğünü kontrol et. |
| Hedef API | AAB ön ayarı `target_sdk=35` (Play'in 2025+ zorunluluğu). |
| 64 bit | APK artık yalnızca arm64-v8a (32 bit armeabi-v7a çıkarıldı, ~25 MB küçüldü). AAB her iki mimariyi de içerir; Play cihaza uygun olanı dağıtır. |
| İmza | `android/keystore/kayipkuleler.jks` (APK ile aynı yükleme anahtarı; Play App Signing'e yüklenebilir). |
| Gizlilik politikası | `web/gizlilik.html` — veri toplanmaz, yalnızca cihazda kayıt. GitHub Pages ya da herhangi bir statik sunucuda yayınlanıp Play Console'a bağlantısı girilir. |
| Mağaza görselleri | `store/feature_graphic.png` (1024×500), `store/screenshots/*.png` (1920×1080). |
| Uygulama simgesi | `art/icon-4096.png` → `tools/make_icons.py` (512 px mağaza simgesi: `android/store/icon-512.png`). |
| İçerik derecelendirmesi | Şiddet/satın alma/reklam yok; anket "Herkes" sonucunu verir. |
