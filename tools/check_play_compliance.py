#!/usr/bin/env python3
"""Google Play gönderim öncesi denetim (derlenmiş APK / AAB üzerinde).

    python3 tools/check_play_compliance.py build/KayipKuleler.apk [build/KayipKuleler.aab]

mjmirza/app-store-compliance kural setinin Android tarafından bu proje için geçerli olanları uygular. O betik
Gradle/AndroidManifest kaynak dosyası arar; Godot bunları dışa aktarımda ürettiği için burada doğrudan çıktı
manifesti okunur. Kritik bulguda çıkış kodu 1.

  GOOGLE-TARGET-API          targetSdk >= 36 (yeni uygulama ve güncellemeler, 31 Ağu 2026 / uzatma 1 Kas 2026)
  ANDROID-DEBUGGABLE-RELEASE android:debuggable=true olmamalı
  ANDROID-INSECURE-BACKUP    allowBackup açıksa uyarı (kayıt yalnızca cihazda; kapalı tutulur)
  GOOGLE-PERM-*              SMS/arama kaydı/tüm dosyalar/konum/kişiler/AD_ID gibi beyan gerektiren izinler
  64 bit                     APK'da yalnızca arm64-v8a (Play 64 bit şartı)
"""
import struct
import sys
import zipfile

MIN_TARGET = 36
SENSITIVE = ["READ_SMS", "SEND_SMS", "RECEIVE_SMS", "READ_CALL_LOG", "WRITE_CALL_LOG", "MANAGE_EXTERNAL_STORAGE",
             "ACCESS_BACKGROUND_LOCATION", "ACCESS_FINE_LOCATION", "ACCESS_COARSE_LOCATION", "READ_CONTACTS",
             "WRITE_CONTACTS", "GET_ACCOUNTS", "READ_MEDIA_IMAGES", "READ_MEDIA_VIDEO", "CAMERA", "RECORD_AUDIO",
             "com.google.android.gms.permission.AD_ID", "QUERY_ALL_PACKAGES", "REQUEST_INSTALL_PACKAGES"]


def axml(data: bytes):
    """İkili AndroidManifest.xml: (dizgeler, öznitelik okuyucu, uses-permission listesi)"""
    sp = 8
    cnt, = struct.unpack_from("<I", data, sp + 8)
    flags, = struct.unpack_from("<I", data, sp + 16)
    st, = struct.unpack_from("<I", data, sp + 20)
    offs = struct.unpack_from("<%dI" % cnt, data, sp + 28)
    S = []
    for o in offs:
        p = sp + st + o
        if flags & 0x100:
            n = data[p + 1]
            p += 2 + (1 if data[p + 1] & 0x80 else 0)
            S.append(data[p:p + n].decode("utf8", "replace"))
        else:
            n, = struct.unpack_from("<H", data, p)
            S.append(data[p + 2:p + 2 + n * 2].decode("utf-16le", "replace"))

    def attr(key):
        out = []
        if key not in S:
            return out
        vi = S.index(key)
        i = 0
        while (i := data.find(struct.pack("<I", vi), i)) >= 0:
            t = data[i + 11]
            val, = struct.unpack_from("<I", data, i + 12)
            if t in (0x10, 0x11):
                out.append(val)
            elif t == 0x12:
                out.append(bool(val))
            elif t == 0x03 and val < len(S):
                out.append(S[val])
            i += 4
        return out

    # uses-permission öğelerinin name öznitelikleri: öğe başlangıç parçalarını (0x0102) tara
    perms = []
    if "uses-permission" in S and "name" in S:
        up = S.index("uses-permission")
        nm = S.index("name")
        i = 0
        while (i := data.find(b"\x02\x01", i)) >= 0:
            if i % 4 == 0 and i + 36 <= len(data):
                name_idx, = struct.unpack_from("<I", data, i + 20)
                if name_idx == up:
                    acount, = struct.unpack_from("<H", data, i + 28)
                    a0 = i + 36
                    for k in range(acount):
                        an, = struct.unpack_from("<I", data, a0 + k * 20 + 4)
                        raw, = struct.unpack_from("<I", data, a0 + k * 20 + 8)
                        if an == nm and raw < len(S):
                            perms.append(S[raw])
            i += 2
    return S, attr, perms


def main(paths):
    crit, warn, ok = [], [], []
    for path in paths:
        z = zipfile.ZipFile(path)
        tag = path.rsplit("/", 1)[-1]
        if path.endswith(".aab"):
            raw = z.read("base/manifest/AndroidManifest.xml")
            i = raw.find(b"targetSdkVersion")
            tgt = int(raw[i + 18:i + 18 + raw[i + 17]].decode()) if i >= 0 else 0
            (ok if tgt >= MIN_TARGET else crit).append("%s GOOGLE-TARGET-API targetSdk=%d (en az %d)" % (tag, tgt, MIN_TARGET))
            (crit if b"debuggable" in raw else ok).append("%s ANDROID-DEBUGGABLE-RELEASE" % tag)
            continue
        S, attr, perms = axml(z.read("AndroidManifest.xml"))
        tgt = max(attr("targetSdkVersion") or [0])
        (ok if tgt >= MIN_TARGET else crit).append("%s GOOGLE-TARGET-API targetSdk=%d (en az %d)" % (tag, tgt, MIN_TARGET))
        (crit if True in attr("debuggable") else ok).append("%s ANDROID-DEBUGGABLE-RELEASE" % tag)
        (warn if True in attr("allowBackup") else ok).append("%s ANDROID-INSECURE-BACKUP allowBackup=%s" % (tag, attr("allowBackup")))
        bad = [p for p in perms if any(p.endswith(s) for s in SENSITIVE)]
        (crit if bad else ok).append("%s GOOGLE-PERM izinler=%s" % (tag, perms or "yok"))
        abis = sorted({n.split("/")[1] for n in z.namelist() if n.startswith("lib/")})
        (ok if abis == ["arm64-v8a"] or "arm64-v8a" in abis else crit).append("%s 64 bit ABI=%s" % (tag, abis))
    for k, lst in (("TAMAM", ok), ("UYARI", warn), ("KRİTİK", crit)):
        for x in lst:
            print("  %-7s %s" % (k, x))
    print("play-compliance: %s (%d kritik, %d uyarı)" % ("TAMAM" if not crit else "ENGELLİ", len(crit), len(warn)))
    print("  Elle: Veri Güvenliği formu = veri toplanmıyor/paylaşılmıyor; gizlilik URL'si; IARC anketi; yeni kişisel hesapta "
          "12 testçi × 14 gün kapalı test; 1 Şub 2027'ye kadar tüccar/tüccar-değil beyanı.")
    return 1 if crit else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
