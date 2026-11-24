#!/usr/bin/env bash
# Godot projesini Android APK olarak dışa aktarır (yerelde ve GitHub Actions'ta aynı betik).
# PROJECT: proje klasörü (varsayılan godot; programlama prototipi için godot-program).
# RELEASE_KEYSTORE / RELEASE_KEY_ALIAS / RELEASE_KEY_PASS: sürüm imzası için kalıcı anahtar (verilmezse debug anahtarı).
# Gerekenler: GODOT (Godot 4.x çalıştırılabilir yolu; klasik proje 4.3, godot-program 4.8 beta),
# ANDROID_HOME (veya ANDROID_SDK_ROOT), JAVA_HOME (JDK 17),
# ~/.local/share/godot/export_templates/<sürüm>/android_{debug,release}.apk (ör. 4.3.stable, 4.8.beta4)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-godot}"
SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
OUT="${1:-$ROOT/godot-build/android/KayipKuleler-godot.apk}"
MODE="${2:-debug}"   # debug | release
[ -n "$SDK" ] || { echo "ANDROID_HOME tanımlı değil"; exit 1; }
[ -n "${JAVA_HOME:-}" ] || JAVA_HOME="$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")"
KS_DIR="$HOME/.local/share/godot/keystores"
KS="$KS_DIR/debug.keystore"
mkdir -p "$KS_DIR" "$(dirname "$OUT")"
if [ ! -f "$KS" ]; then
  "$JAVA_HOME/bin/keytool" -genkeypair -v -keystore "$KS" -storepass android -alias androiddebugkey \
    -keypass android -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US" >/dev/null 2>&1
fi
# Editör ayarlarını oluştur (bir kez başsız editör açılır) ve Android yollarını yaz
# Editör ayar dosyası sürüme göre adlandırılır (editor_settings-4.3.tres, editor_settings-4.8.tres ...)
GODOT_MM="$("$GODOT" --headless --version 2>/dev/null | tail -1 | cut -d. -f1-2)"
CFG="$HOME/.config/godot/editor_settings-${GODOT_MM}.tres"
PROJECT="${PROJECT:-godot}"
if [ ! -f "$CFG" ]; then (cd "$ROOT/$PROJECT" && timeout 180 "$GODOT" --headless --editor --quit >/dev/null 2>&1 || true); fi
[ -f "$CFG" ] || { mkdir -p "$(dirname "$CFG")"; printf '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n' > "$CFG"; }
set_cfg() { if grep -q "^$1 = " "$CFG"; then sed -i "s|^$1 = .*|$1 = $2|" "$CFG"; else echo "$1 = $2" >> "$CFG"; fi; }
set_cfg 'export/android/android_sdk_path' "\"$SDK\""
set_cfg 'export/android/java_sdk_path' "\"$JAVA_HOME\""
set_cfg 'export/android/debug_keystore' "\"$KS\""
set_cfg 'export/android/debug_keystore_user' '"androiddebugkey"'
set_cfg 'export/android/debug_keystore_pass' '"android"'
cd "$ROOT/$PROJECT"
# 2K dokuların ETC2/ASTC sıkıştırması ilk içe aktarmada birkaç dakika sürer
timeout 1800 "$GODOT" --headless --import >/dev/null 2>&1 || true
if [ "$MODE" = release ]; then
  # Sürüm APK'sı da hata ayıklama anahtarıyla imzalanır (Play Store için kendi anahtarınızı kullanın)
  export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="${RELEASE_KEYSTORE:-$KS}" \
    GODOT_ANDROID_KEYSTORE_RELEASE_USER="${RELEASE_KEY_ALIAS:-androiddebugkey}" \
    GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="${RELEASE_KEY_PASS:-android}"
  "$GODOT" --headless --export-release "Android" "$OUT" 2>&1 | grep -vE 'mesh_storage|Parameter "m" is null' || true
else
  "$GODOT" --headless --export-debug "Android" "$OUT" 2>&1 | grep -vE 'mesh_storage|Parameter "m" is null' || true
fi
[ -f "$OUT" ] || { echo "HATA: APK üretilmedi"; exit 1; }
ls -la "$OUT"
