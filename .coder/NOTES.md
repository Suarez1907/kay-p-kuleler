# Kayıp Kuleler — repo notları

- Amaç: Godot 4.8 ile yapılan 3B programlama bulmacası; Android APK/AAB yayınları GitHub Releases üzerinden.
- Yapı: `godot-program/` (Godot projesi), `tools/` (export ve Play uyumluluk betikleri), `android/keystore/` (kalıcı imza anahtarı), `.github/workflows/godot-program-android.yml` (APK yayın iş akışı).
- Sürüm kaynağı: `godot-program/project.godot` → `config/version`; workflow bu değeri okuyup `vX.Y.Z` etiketiyle release açar. `export_presets.cfg` içindeki `version/code` CI'da 2000+run no ile ezilir.
- Sürüm notları: kök `CHANGELOG.md`.
- Build/test: CI'da Godot headless testleri (seviye, tema, parça, varlık, sinematik, perf, layout, uiaudit) + APK/AAB dışa aktarımı; aynı iş akışı `ci_wait` ile izlenir.
- CI iş akışı: `.github/workflows/ci.yml` (zaman aşımı korumalı; adımlar 180 sn'lik `timeout` sarmalayıcısıyla koşar, takılan Godot headless/import işlemi bu süre sonunda öldürülür). Headless test komutları: `godot --headless --script res://tests/run_features.gd`, `godot --headless --script res://tests/run_clarity.gd`, `godot --headless --script res://tests/run_cinematics.gd`, `godot --headless --script res://tests/run_assets.gd`, `godot --headless --script res://tools/level_database_builder.gd -- --check` ve `godot --headless -- --autotest`.
- Android import: `.github/workflows/godot-program-android.yml` Godot import önbelleğini (`~/.cache/godot`, proje `.godot/` klasörü) adımlar arasında saklar; soğuk önbellekte import kilitlenmesini önlemek için import adımı 180 sn timeout ile sınırlıdır.
- PBR öncesi içe aktarma: `.github/workflows/tests.yml` ve Android iş akışı, Godot'u çalıştırmadan önce `tools/configure_pbr_imports.py` ile `*.import` dosyalarını yapılandırır; böylece VRAM sıkıştırma ayarları CI'ya taşınır.
- Tuzaklar: `*.import` dosyaları depoda tutulmalı (VRAM sıkıştırma ayarları CI'ya gitmezse bozulur); temiz içe aktarma ~1 saat sürer, önbellek şart; ışık haritaları ASTC, masaüstü biçimleri kapalı.
- Tuzak: `godot-program/tools/level_database_builder.gd` sıkıştırma API'si (günlük üretici `daily_generator.gd` tarafından çağrılır) `Dictionary` bekler; kökteki byte sarmalayıcısıyla karıştırılmamalıdır.
