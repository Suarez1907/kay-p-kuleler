# Kayıp Kuleler — repo notları

- Amaç: Godot 4.8 ile yapılan 3B programlama bulmacası; Android APK/AAB yayınları GitHub Releases üzerinden.
- Yapı: `godot-program/` (Godot projesi), `tools/` (export ve Play uyumluluk betikleri), `android/keystore/` (kalıcı imza anahtarı), `.github/workflows/godot-program-android.yml` (APK yayın iş akışı).
- Sürüm kaynağı: `godot-program/project.godot` → `config/version`; workflow bu değeri okuyup `vX.Y.Z` etiketiyle release açar. `export_presets.cfg` içindeki `version/code` CI'da 2000+run no ile ezilir.
- Sürüm notları: kök `CHANGELOG.md`.
- Build/test: CI'da Godot headless testleri (seviye, tema, parça, varlık, sinematik, perf, layout, uiaudit) + APK/AAB dışa aktarımı; aynı iş akışı `ci_wait` ile izlenir.
- Tuzaklar: `*.import` dosyaları depoda tutulmalı (VRAM sıkıştırma ayarları CI'ya gitmezse bozulur); temiz içe aktarma ~1 saat sürer, önbellek şart; ışık haritaları ASTC, masaüstü biçimleri kapalı.
