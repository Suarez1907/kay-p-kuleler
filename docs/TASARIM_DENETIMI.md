# Tasarım denetimi (2026-11-23)

Yöntem: [pbakaus/impeccable](https://github.com/pbakaus/impeccable) `audit.native` ölçütleri (Android: 48 dp dokunma
hedefi, sp metin ölçeği, kontrast, güvenli alan, uyarlanabilirlik). impeccable'ın başlatıcısı web sayfası hedeflediği
ve ikili dosya indirdiği için çalıştırılmadı; ölçütler oyunun içine yazılan ölçüm modu ile uygulandı:

    godot --headless --path godot-program -- --uiaudit=1080x2400@2.625     # CI'da çalışır, sorun varsa kırmızı

`taste-skill` ve `hallmark` pazarlama web sayfası (HTML/CSS) kural setleridir; oyunun Godot arayüzüne uygulanamaz.
Mağaza sayfası / tanıtım sitesi yapılırsa kullanılabilirler.

## Sağlık puanı

| # | Boyut | Önce | Sonra | Ana bulgu |
|---|---|---|---|---|
| 1 | Erişilebilirlik | 1 | 3 | Dokunma hedefleri 23–26 dp, yazılar 6–8 sp idi → 48 dp / ≥ 12 sp. İkincil metin kontrastı 3.7:1 → 5.0:1 |
| 2 | Performans | 3 | 3 | Değişmedi (perfcheck: 39 toplu grup, seviye kurulumu 40–70 ms) |
| 3 | Görünüm ve tema | 3 | 3 | Blueprint belirteçleri (BP) tutarlı; açma/kapama anahtarları belirsizdi → pahlı Blueprint anahtarı |
| 4 | Platform uyumu | 2 | 3 | Geri hareketi ve güvenli alan doğru; anahtar/dokunma boyutları Android'in altındaydı |
| 5 | Uyarlanabilirlik | 2 | 3 | Dar ekranda pencereler taşıyordu → genişlik sığdırma, akış düzeni, yazı kaydırma |
| | **Toplam** | **11/20** | **15/20** | Kabul edilebilir → İyi |

## Bulgular ve düzeltmeler

* **[P1] Arayüz ölçeği yoğunluğa bağlı değildi.** Arayüz 720 px'lik mantıksal kısa kenara göre çiziliyor. 420 dpi
  bir telefonda 1 px ≈ 0.57 dp ediyordu (44 px düğme ≈ 25 dp, 13 px yazı ≈ 7 sp). Düzeltme: `_ui_scale_factor()`
  ekran yoğunluğundan 1 px ≈ 1 dp olacak ölçeği hesaplar. Dikey ekranda kısa kenar en az 400 mantıksal px kalır
  (360 dp'lik küçük telefonlarda ≈ 0.9 dp/px). Yatay ekranda pencereler dikeyde sığmadığından eski düzen korunur.
  "Büyük yazı" erişilebilirlik ayarı ×1.15 ekler.
* **[P1] Dokunma hedefleri < 48 dp.** `BP.MIN_TOUCH` 44 → 48. 34–47 px arası bütün düğmeler 48'e çekilir (kare ikon
  düğmeleri iki yönde). Alt çubuktaki yan düğmeler 48 dp'nin altına inmez; sığmazsa ÇALIŞTIR daralır.
* **[P1] Dar ekranda pencereler taşıyordu.** Ayarlar, atölye ve başarımlar 420–480 px sabit genişlikteydi.
  `_fit_widths()` sabit genişlikleri görünür alana sığdırır, uzun tek satırları sözcükten kaydırır. Başlıktaki
  SEVİYELER / BİLGİSAYARIM satırı akış düzenine geçti; düğme yeni sayıyı (100/100) kapsayacak kadar genişler.
* **[P2] Yıldız sayacı sağ kenarda kesiliyordu** (başlık ekranı ve oyun üst çubuğu). Hap sağa sabitlendi; seviye adı
  dar ekranda blok sayacı rozetine yer bırakarak tam genişlik alır ("36. DD" yerine "36. DDR5 belle…").
* **[P2] Editör üst bilgisi taşıyordu.** Bilgi ve yardım satırları sözcükten kayar.
* **[P2] Açma/kapama anahtarları okunmuyordu** (kapalı hâli tek bir nokta). Cyan / çelik pahlı anahtar.
* **[P2] İkincil metin kontrastı WCAG AA altındaydı.** `TEXT_MUTED` #64748B (3.7:1) → #7A8AA1 (5.0:1).
* **[P3] 11 px etiketler.** `BP.tag` 12 sp'nin altına inmez.

## Ölçüm (1080×2400, 420 dpi)

| Ekran | En küçük düğme | En küçük yazı | Taşma |
|---|---|---|---|
| Başlık, Kuleler, Oyun, Duraklat, Ayarlar, Günlük, Atölye, Başarımlar | 25 → 48 dp | 6–8 → 12 sp | 0 |

## Kalan işler

* 360 dp telefonlarda tam 1 dp/px için ayarlar satırları ve seviye seçimi başlığı 360 px'e göre yeniden düzenlenmeli.
* Yatay ekran: pencereler kaydırılabilir yapılırsa yatayda da ölçek büyütülebilir.
* Cihazda TalkBack etiketleri (Godot erişilebilirlik ağacı) denenmedi.
