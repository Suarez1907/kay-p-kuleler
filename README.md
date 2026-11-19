# Kayıp Kuleler — 3B Programlama Bulmacası (Android)

[![Android APK](../../actions/workflows/android.yml/badge.svg)](../../actions/workflows/android.yml)
[![Testler](../../actions/workflows/tests.yml/badge.svg)](../../actions/workflows/tests.yml)

Monument Valley ve Mekorama'dan esinlenen, izometrik pastel diorama görünümlü bir **programlama bulmacası**.
Küçük robot **Robo**'yu doğrudan yönetmezsin: ona komut bloklarından bir **program** yazarsın — İleri, Dön, Zıpla, Kullan,
fonksiyonlar, döngüler ve koşullar. Bu sırada Monument Valley'deki gibi **dünyayı sen döndürürsün**: döner köprüleri çevirir,
asansörleri kaldırır, kamerayı çevirip imkânsız geçitleri birleştirirsin. Hedef: her kulenin tepesindeki parlayan kristal.

<p align="center">
  <img src="screenshots/android-fonksiyon.png" width="220" alt="Fonksiyonlar">
  <img src="screenshots/android-kosul.png" width="220" alt="Koşullar">
  <img src="screenshots/android-baslik.png" width="220" alt="Başlık ekranı">
</p>
<p align="center">
  <img src="screenshots/07-son-kule.png" width="680" alt="Son Kule">
</p>

| Sürüm | Klasör | Teknoloji |
|---|---|---|
| **Android uygulaması (ana sürüm)** | `android/` | Kotlin, AndroidX WebView + `WebViewAssetLoader`; oyun `web/` klasöründen derleme sırasında kopyalanır |
| Tarayıcı | `web/` | Three.js r170 + cannon-es (yerel olarak paketlendi, CDN yok) |
| Godot (klasik mod) | `godot/` | Godot 4.3, GDScript — programlama öncesi "dokun-yürü" sürümü ve 15 klasik seviyesi |

Android ve tarayıcı sürümü **25 el yapımı seviyelik, 7 bölümlük programlama kampanyasını** içerir; her seviyenin
referans programı derleme sırasında gerçek yorumlayıcıda çalıştırılarak doğrulanır.

---

## Nasıl oynanır?

1. **Programı yaz.** Alttaki (yatay ekranda sağdaki) paletten bloklara dokun — imleç neredeyse oraya eklenir. Blokları
   **sürükleyip bırakarak** da ekleyebilir, yerini değiştirebilir, panelin dışına sürükleyerek silebilirsin.
   Bir bloğa dokununca çıkan küçük menüden taşı (◀ ▶), **koşul** ver ya da sil.
2. **Dünyayı hazırla.** Saplı döner platformları çevir, kaydırıcıları/asansörleri hareket ettir, kamerayı döndür.
3. **▶ Çalıştır.** Robo programı blok blok çalıştırır; çalışan blok parlar, koşulu tutmayan bloklar soluklaşır.
   **⏭ Tek adım** ile hata ayıklayabilir, **1× / 2× / 4×** ile hızlandırabilir, **■** ile başa sarabilirsin.
4. **Mola** bloğu programı duraklatır: Robo beklerken platformları çevir ya da bakış açısını değiştir, sonra **▶** ile devam et.

Robo kristale ulaştığı anda seviye biter. **Yıldızlar programın kısalığına göre** verilir: blok sayısı ≤ par ise 3 yıldız,
par + 3'e kadar 2 yıldız. Programlar ve ilerleme cihazda saklanır (`localStorage`).

### Komutlar

| Blok | Ne yapar | İlk seviye |
|---|---|---|
| ⬆ İleri | Baktığı yöne bir kare yürür; merdivenleri kendiliğinden çıkar/iner, göz yanılması geçitlerinden geçer | 1 |
| ↰ Sola dön / ↱ Sağa dön | Olduğu yerde 90° döner (Robo'nun kendi soluna/sağına göre; ayağının altındaki ok yönünü gösterir) | 2 |
| F1 / F2 | Fonksiyon çağrısı. Bir fonksiyon kendini çağırırsa **döngü** olur (kuyruk çağrısı, yığın büyümez) | 4 / 18 |
| ⤴ Zıpla | Önündeki bir kat yüksek bloğa çıkar ya da bir kat aşağı atlar | 7 |
| ✺ Kullan | Önündeki kolu çevirir, çarkı döndürür, kutuyu iter, topa vurur | 8 |
| ‖ Mola | Programı duraklatır; bu sırada dünyayı değiştirirsin | 15 |
| Koşullar | <span>✓ yeşil</span>: yalnızca **önü açıksa**, <span>✕ turuncu</span>: yalnızca **önü kapalıysa** çalışır | 12 |

Engele çarpan bir komut (ör. duvara doğru İleri) Robo'yu yerinde sarsar ve program devam eder. 300 komut sınırı sonsuz döngüleri durdurur.

### Bölümler ve seviyeler

| # | Bölüm | Seviye | Öğrettiği | Par (blok) |
|---|---|---|---|---|
| 1 | Uyanış | İlk Komut | sıralı komut | 4 |
| 2 | | Köşe | dönüşler | 7 |
| 3 | | Merdiven | merdivenler | 9 |
| 4 | Fonksiyonlar | Zikzak Kule | F1 ile tekrar eden desen | 8 |
| 5 | | Sonsuz Köprü | özyinelemeli döngü | 3 |
| 6 | | Sarmal Kule | döngüyle kuleye tırmanma | 5 |
| 7 | | Basamaklar | Zıpla | 9 |
| 8 | Mekanizmalar | Kol ve Köprü | Kullan, kol, beliren köprü | 8 |
| 9 | | Boşluğu Doldur | kutu itme, düşen kutu zemin olur | 6 |
| 10 | | Çark | Robo'nun döndürdüğü platform | 7 |
| 11 | | Yuvarlanan Top | top kola çarpar | 9 |
| 12 | Koşullar | Duvara Kadar | "önü açıksa / kapalıysa" ile sarmal | 4 |
| 13 | | Kıvrımlı Yol | genel yol izleyici algoritma | 6 |
| 14 | Dünyayı Döndür | Döner Köprü | oyuncunun çevirdiği platform | 3 |
| 15 | | Mola | Robo'yu taşıyan platformu molada çevirme | 6 |
| 16 | | Asansör | molada asansör kaldırma | 8 |
| 17 | | İmkânsız Geçit | kamera açısıyla birleşen yollar | 11 |
| 18 | Ustalık | Taşıyıcı | kutu + döner platform + kapı, iki mola | 12 |
| 19 | | Çöken Zemin | tek geçişlik taşlar, üç kol | 27 |
| 20 | | Son Kule | her şey bir arada | 24 |
| 21 | Yankılar | Terazi Kulesi | terazi platformları, iki kutuyla denge | 17 |
| 22 | | Ayna Kapı | ışınlayıcı halkalar (portallar) | 12 |
| 23 | | Kutu Işınlama | kutuyu ışınlayıcıyla uzak plakaya düşürme | 11 |
| 24 | | Yankı Labirenti | koşullu yol izleyici + çoklu kule portalları | 6 |
| 25 | | Yıldızlar Arası | döner köprü + ışınlayıcı + asansör + göz yanılması | 12 |

Tüm referans çözümler `SOLUTIONS.md` dosyasındadır.

### Klavye kısayolları (tarayıcı)

| Tuş | Eylem |
|---|---|
| ↑ / ← / → / J / K / P / 1 / 2 | İleri / Sola / Sağa / Zıpla / Kullan / Mola / F1 / F2 bloğu ekle |
| Boşluk | Çalıştır / duraklat / devam |
| N | Tek adım |
| S veya Esc | Durdur, başa sar |
| Backspace / Delete | Seçili bloğu (ya da imleçten önceki bloğu) sil |
| Tab | Etkin satırı değiştir (Ana → F1 → F2) |
| Z | Geri al (program düzenlemesi ya da dünya işlemi) |
| Q / E | Kamerayı 90° çevir |
| R / H / M | Dünyayı başa al / İpucu / Seviyeler |

---

## 1. Android

### APK'yı indirip kurma
* **Her push'tan sonra:** GitHub → **Actions** → *Android APK (Three.js + WebView)* → son çalıştırma → **Artifacts** → `KayipKuleler-apk-<sürüm>` (zip içinde iki APK). Godot sürümü için *Android APK (Godot sürümü)* → `KayipKuleler-godot-apk`.
* **Sürümler:** `v1.0.0` gibi bir etiket gönderildiğinde APK'lar otomatik olarak **Releases** sayfasına eklenir:
  ```bash
  git tag v1.0.0 && git push origin v1.0.0
  ```
* Telefonda APK'yı açın ("bilinmeyen kaynaklardan yükleme" izni istenir). Android 7.0 (API 24) ve üzeri desteklenir.

| Dosya | Açıklama |
|---|---|
| `KayipKuleler-<sürüm>.apk` | Release derlemesi (küçültülmüş, `com.akin.kayipkuleler`) |
| `KayipKuleler-<sürüm>-debug.apk` | Debug derlemesi (`com.akin.kayipkuleler.debug`, release ile yan yana kurulabilir) |
| `KayipKuleler-godot.apk` / `KayipKuleler-godot-debug.apk` | Godot motoruyla derlenen alternatif sürüm (`godot-android.yml`, `com.akin.kayipkuleler.godot`) |

> Release APK, kurulabilir olması için **debug anahtarıyla** imzalanır. Google Play'e yüklemek için kendi
> anahtarınızı oluşturup `android/app/build.gradle.kts` içindeki `signingConfigs` bölümüne (GitHub Secrets ile) bağlayın.

### Uygulamanın özellikleri
* Tam ekran (immersive) — sistem çubukları kenardan kaydırınca geçici olarak görünür; çentik alanı kullanılır.
* Dikey **ve** yatay yönlendirme (yatayda yan menü sağ altta yatay bir sıraya dönüşür).
* Oynarken ekran kapanmaz.
* **Geri tuşu:** açık kart / ipucu / seçim kapanır → çalışan program durur → seviye seçimi → başlık → uygulamadan çıkış.
* İlerleme ve her seviyedeki programın (`localStorage`) uygulama kapatılsa da korunur.
* İnternet izni yok; tüm dosyalar APK içinde, `https://appassets.androidplatform.net/assets/web/` adresinden güvenli şekilde sunulur.
* Dokunmatik: bloklara **dokun** / blokları **sürükle-bırak**; sahnede **sürükle** = platform döndür/kaydır ya da kamera, **iki parmak** = yakınlaştır.
* Dikeyde program paneli altta, yatayda sağda durur; sahne her zaman boş alana ortalanır.

### Yerel derleme
Gereken: JDK 17 ve Android SDK (platform 35). `ANDROID_HOME` ayarlı değilse `android/local.properties` içine `sdk.dir=/yol/android-sdk` yazın.
```bash
cd android
./gradlew assembleDebug      # app/build/outputs/apk/debug/app-debug.apk
./gradlew assembleRelease    # app/build/outputs/apk/release/app-release.apk
./gradlew installDebug       # bağlı cihaza / emülatöre kurar
```
`web/` tek doğruluk kaynağıdır: Gradle'daki `copyWebGame` görevi her derlemede `web/` klasörünü APK varlıklarına kopyalar —
oyunda yapılan her değişiklik bir sonraki derlemede uygulamaya girer, kopya dosya tutmaya gerek yoktur.

Uygulama simgesi (pastel izometrik küp, Robo ve kristal; uyarlanabilir + tek renkli) `python3 tools/make_icons.py` ile yeniden üretilir.

### GitHub Actions iş akışları
| Dosya | Ne zaman | Ne üretir |
|---|---|---|
| `.github/workflows/android.yml` | `main`'e push, PR, `v*` etiketi, elle | Debug + release APK (artifact); etikette GitHub Release |
| `.github/workflows/tests.yml` | `main`'e push, PR, elle | Seviye doğrulayıcı (20 program + 15 klasik), headless Chrome oyun testi, Godot mantık + sahne testleri |
| `.github/workflows/godot-android.yml` | `godot/` değişince, `v*` etiketi, elle | Godot ile dışa aktarılmış Android APK'ları (artifact / Release) |

Sürüm kodu `GITHUB_RUN_NUMBER`, sürüm adı etiketten (`v1.2.0` → `1.2.0`) ya da `1.0.<çalıştırma no>` olarak otomatik verilir.

---

## 2. Diğer sürümleri çalıştırma

### Tarayıcı sürümü (Three.js)
ES modülleri kullandığı için dosyayı çift tıklayarak değil, basit bir yerel sunucu ile açın:

```bash
cd web
python3 -m http.server 8765
# tarayıcıda: http://localhost:8765
```
İnternet bağlantısı gerekmez — three.js, RoundedBoxGeometry ve cannon-es `web/vendor/` içindedir.
Doğrudan bir seviyeyi açmak için: `http://localhost:8765/?level=9`

### Godot sürümü
* **Editörde:** Godot 4.3 (veya daha yeni 4.x) ile `godot/project.godot` dosyasını açıp F5'e basın.
* **Android APK (Godot):** Godot 4.3 + Android dışa aktarım şablonları + Android SDK ile
  ```bash
  GODOT=/yol/godot ANDROID_HOME=/yol/android-sdk JAVA_HOME=/yol/jdk17 \
    tools/godot-android-export.sh godot-build/KayipKuleler-godot.apk debug
  ```
  (Betik gerekirse bir debug anahtarı oluşturur ve Godot editör ayarlarını yazar.) Godot sürümü telefonda yatay açılır.
* **Web / Linux dışa aktarımı:** bkz. bölüm 5.

---

## 3. Mekanikler

| Mekanik | Açıklama | İlk seviye |
|---|---|---|
| Merdiven | İleri bloğu bir kat çıkar / iner | 3 |
| Kol | Robo önünde durup **Kullan** deyince açılır/kapanır, kalıcıdır | 8 |
| Basınç plakası | Üzerinde ağırlık (Robo, kutu, top) olduğu sürece sinyal verir | 18 |
| Beliren köprü / kapı | Sinyal doğruyken köprü katılaşır; kapılar sinyal ile açılır | 8, 18 |
| İtilebilir kutu | **Kullan** ile itilir; yerçekimiyle düşer, boşlukları doldurur, plakaları basılı tutar | 9 |
| Çark | Robo **Kullan** deyince bağlı platformu 90° döndürür (programla dünyayı değiştirme) | 10 |
| Yuvarlanan top | Vurulunca bir engele çarpana dek yuvarlanır, çarptığı kolu çevirir | 11 |
| Saplı döner platform | **Oyuncu** çevirir (çark sapına dokun / sürükle); üzerindeki her şeyi taşır | 14 |
| Kaydırıcı / asansör | Raylı platform; oyuncu oklarla ya da sürükleyerek hareket ettirir, yükünü taşır | 16 |
| Göz yanılması geçidi | Yalnızca belirli kamera açısından birleşen iki yol (halkalar dolunca geçit açıktır) | 17 |
| Çöken zemin | Robo üzerinden ayrılınca parçalanıp düşer | 19 |
| Terazi | Birbirine bağlı iki platform: ağır kefe aşağı iner, hafif olan yukarı çıkar | 21 |
| Işınlayıcı (portal) | Üzerine yürüyen Robo ya da itilen kutu aynı renkteki eşleşen halkadan anında çıkar | 22 |

**Mimari:** Bulmaca kuralları **deterministik bir ızgara fizik motorunda** (`web/js/engine.js`) çalışır; programlama katmanı
(`web/js/program.js`) komutları, koşulları, çağrı yığınını ve yorumlayıcıyı içerir ve render'dan bağımsızdır. Bu sayede
`tools/build.mjs` her seviyenin referans programını tarayıcı olmadan çalıştırıp doğrulayabilir. Gerçek rijit-cisim fiziği
(**cannon-es**) yalnızca görsel efektler içindir: çöken taşların parçaları ve zafer konfetisi.

---

## 4. Yeni seviye ekleme

`tools/program-levels.src.mjs` dosyasına bir nesne ekleyin. Koordinatlar `[x, y, z]`, **y yukarıdır**; Robo bir bloğun
*üstündeki* hücrede durur. Yönler: `0=+x 1=+z 2=-x 3=-z`.

```js
{
  chapter: 'Bölüm adı', name: 'Yeni Seviye', palette: 3, hint: 'İpucu metni',
  intro: { title: 'Yeni kavram', text: 'Seviye açılınca gösterilen kart (HTML olabilir)' },
  boxes:   [[0,0,0, 4,0,2]],                 // dolu kutular [x1,y1,z1, x2,y2,z2]
  stairs:  [{p:[3,1,0], d:0}],               // d: yükselme yönü
  levers:  [{id:'L1', p:[0,1,2]}],  plates: [{id:'P1', p:[4,1,2]}],
  bridges: [{cells:[[5,0,1]], on:'L1'}],     // '!P1' ve door:true ile kapı
  rotators:[{pivot:[x,z], blocks:[[..]], handle:[x,y,z]}],   // fixed:true -> yalnızca çarkla döner
  cranks:  [{p:[1,1,0], rot:0, dir:1}],      // Robo'nun çevirdiği çark
  sliders: [{blocks:[[..]], axis:[0,1,0], min:0, max:2, pos:0}],
  crates:  [[1,1,1]], balls: [[2,1,2]], crumbles: [[2,0,0]],
  links:   [{a:[2,1,0], b:[5,3,2], d:0, view:0}],   // göz yanılması (b = a + yön + k·görüş vektörü)
  view: 0, start: [0,1,0], startDir: 0, goal: [4,1,0],
  cmds: ['F','L','R','J','A','W','1','2'],   // palet
  conds: true,                               // koşullar açık mı
  slots: { main: 8, p1: 4, p2: 0 },          // satır kapasiteleri
  solution: { main: ['1'], p1: ['o:F','x:R','1'],          // 'o:' önü açıksa, 'x:' önü kapalıysa
              ops: [[{t:'rot', i:0, s:1}], [{t:'view', s:1}]] },  // ops[0] başta, ops[k] k. molada
}
```

Sonra derleyin:
```bash
cd tools
npm install        # yalnızca ilk sefer (three, cannon-es, playwright-core)
node build.mjs     # referans programları çalıştırır, kapasite/palet kurallarını ve
                   # mola işlemlerinin gerçekten gerekli olduğunu denetler, par'ı hesaplar;
                   # web/js/levels.js, godot/data/levels.json ve SOLUTIONS.md yazar
```
Klasik (Godot) seviyeler `tools/levels.src.mjs` içindedir ve BFS çözücüyle doğrulanır (`node show.mjs 9` bir çözümü durum durum gösterir).

---

## 5. Otomatik testler (yapılan doğrulamalar)

```bash
cd tools
node build.mjs                 # 20/20 referans program yorumlayıcıda kazanır + 15/15 klasik seviye çözülür
node test.mjs                  # Headless Chrome: sayfa yüklenir, konsol hatası = 0,
                               # 20 seviyenin programı gerçek arayüzden çalıştırılır (molalarda dünya işlemleriyle),
                               # Seviye 1 gerçek tıklamalarla (palet → Çalıştır) bitirilir,
                               # sürükle-bırak ile ekleme/silme denenir, yatay + dikey ekran görüntüleri alınır
G=/path/to/godot
$G --headless --path godot --script res://tests/run_solutions.gd   # GDScript motoru: 15/15
$G --headless --path godot -- --autotest                           # tam Godot sahnesi: 15/15
$G --headless --path godot --export-release "Web"   ../godot-build/web/index.html
$G --headless --path godot --export-release "Linux" ../godot-build/linux/KayipKuleler.x86_64
cd android && ./gradlew assembleDebug assembleRelease                # Android APK'ları
```
Godot testleri klasik seviyeleri kullanır (Godot sürümü programlama modunu içermez).

---

## 6. Klasör yapısı

```
android/        Gradle (Kotlin DSL) projesi: app/src/main/{AndroidManifest.xml, java/.../MainActivity.kt, res/}
web/            index.html, style.css, js/{engine,program,main,audio,fx,levels}.js, vendor/
                  engine.js  = ızgara fizik motoru, program.js = komutlar + yorumlayıcı
godot/          project.godot, scenes/main.tscn, scripts/{logic,main}.gd, data/levels.json,
                tests/run_solutions.gd, export_presets.cfg (Web, Linux, Android)
tools/          program-levels.src.mjs (kampanya), levels.src.mjs (klasik/Godot), build.mjs, show.mjs, test.mjs,
                make_icons.py (uygulama simgesi), godot-android-export.sh
.github/workflows/  android.yml, tests.yml, godot-android.yml
screenshots/    oynanış ekran görüntüleri
SOLUTIONS.md    tüm seviyelerin çözümleri
```

## 7. Bilinen sınırlamalar
* Release APK debug anahtarıyla imzalıdır (yan yükleme için yeterli; Play Store için kendi anahtarınız gerekir).
* Android uygulaması sistem WebView'ini (WebGL 2) kullanır; çok eski / güncellenmemiş WebView'li cihazlarda performans düşük olabilir.
* Godot sürümü programlama modunu içermez: aynı fizik motorunun GDScript karşılığıyla klasik "dokun-yürü" modunu ve 15 klasik seviyeyi oynatır.
* Godot Android APK'sı ~70 MB'tır (motor dahil). Android emülatörünün yazılımsal GPU'sunda (SwiftShader, GLES 3.0)
  Godot'un sahne shader'ı uniform sınırını aştığı için 3B sahne çizilmiyor (arayüz çalışıyor); gerçek cihaz GPU'larında
  bu sınır daha yüksektir, ancak gerçek cihazda denenmedi.
* `godot-android.yml` ilk çalıştırmada Godot dışa aktarım şablonlarını (~1 GB) indirir; sonraki çalıştırmalarda önbellekten gelir.
* Testler yazılımsal GPU'lar (Chrome SwiftShader, Mesa llvmpipe, Android emülatörü) üzerinde yapıldı; fiziksel telefonda denenmedi.
