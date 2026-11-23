#!/usr/bin/env bash
# Google Play için Android App Bundle (.aab) dışa aktarımı (Gradle derlemesi).
#   tools/godot-android-aab.sh <çıktı.aab>
# Gerekenler: GODOT, Android SDK (ANDROID_HOME/ANDROID_SDK_ROOT), JDK 17, export şablonlarında android_source.zip,
# imza için RELEASE_KEYSTORE / RELEASE_KEY_ALIAS / RELEASE_KEY_PASS. APK dışa aktarımına dokunmaz: geçici bir
# "Android AAB" ön ayarı (Gradle, export_format=1, hedef SDK 36 — Play 31 Ağu 2026 sonrası zorunlu) ekleyip onunla dışa aktarır, sonra eski hâline döner.
set -euo pipefail
OUT="$1"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
P="$ROOT/godot-program"
CFG="$P/export_presets.cfg"
cp "$CFG" "$CFG.bak"
trap 'mv "$CFG.bak" "$CFG"' EXIT
python3 - "$CFG" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p).read()
m = re.search(r"\[preset\.0\](.*?)\[preset\.0\.options\](.*?)(?=\n\[preset\.1|\Z)", s, re.S)
head, opts = m.group(1), m.group(2)
head = head.replace('name="Android"', 'name="Android AAB"').replace('KayipKuleler.apk', 'KayipKuleler.aab')
def setopt(o, k, v):
    return re.sub(r"(?m)^%s=.*$" % re.escape(k), "%s=%s" % (k, v), o)
opts = setopt(opts, "gradle_build/use_gradle_build", "true")
opts = setopt(opts, "gradle_build/export_format", "1")
opts = setopt(opts, "gradle_build/min_sdk", '"24"')
opts = setopt(opts, "gradle_build/target_sdk", '"36"')
opts = setopt(opts, "architectures/armeabi-v7a", "true")
s = s.rstrip("\n") + "\n\n[preset.1]" + head + "[preset.1.options]" + opts
open(p, "w").write(s)
PY
cd "$P"
if [ ! -d android/build ]; then
  "$GODOT" --headless --install-android-build-template --quit >/dev/null 2>&1 || true
fi
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="${RELEASE_KEYSTORE}" \
       GODOT_ANDROID_KEYSTORE_RELEASE_USER="${RELEASE_KEY_ALIAS}" \
       GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="${RELEASE_KEY_PASS}"
mkdir -p "$(dirname "$OUT")"
"$GODOT" --headless --export-release "Android AAB" "$OUT" 2>&1 | tail -20 || true
test -s "$OUT"
echo "AAB: $OUT ($(du -h "$OUT" | cut -f1))"
