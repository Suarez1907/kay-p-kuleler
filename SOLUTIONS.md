# Seviye Çözümleri

## Programlama kampanyası (Android / tarayıcı)

Aşağıdaki programlar `tools/build.mjs` tarafından gerçek yorumlayıcıda çalıştırılarak doğrulanmıştır. *Par*, referans çözümün blok sayısıdır; daha kısa bir program da 3 yıldız alır.

Gösterim: `İleri`, `Sola`, `Sağa`, `Zıpla`, `Kullan`, `Mola`, `F1`, `F2`; `[açıksa]` / `[kapalıysa]` koşullu bloktur.

### Bölüm: Uyanış

#### 1. İlk Komut — par 4

* Ana: İleri → İleri → İleri → İleri

#### 2. Köşe — par 7

* Ana: İleri → İleri → İleri → Sağa → İleri → İleri → İleri

#### 3. Merdiven — par 9

* Ana: İleri → İleri → İleri → İleri → İleri → Sola → İleri → İleri → İleri

### Bölüm: Fonksiyonlar

#### 4. Zikzak Kule — par 8

* Ana: F1 → F1 → F1 → F1
* F1: İleri → Sola → İleri → Sağa

#### 5. Sonsuz Köprü — par 3

* Ana: F1
* F1: İleri → F1

#### 6. Sarmal Kule — par 5

* Ana: F1
* F1: İleri → İleri → Sağa → F1

#### 7. Basamaklar — par 9

* Ana: F1 → F1 → F1 → Sola → Zıpla → Zıpla → Zıpla
* F1: Zıpla → İleri

### Bölüm: Mekanizmalar

#### 8. Kol ve Köprü — par 8

* Ana: İleri → İleri → Sağa → Kullan → Sola → F1
* F1: İleri → F1

#### 9. Boşluğu Doldur — par 6

* Ana: İleri → F1
* F1: Kullan → İleri → İleri → F1

#### 10. Çark — par 7

* Ana: İleri → Sola → Kullan → Sağa → F1
* F1: İleri → F1

#### 11. Yuvarlanan Top — par 9

* Ana: İleri → Sağa → İleri → Sola → Kullan → Sağa → F1
* F1: İleri → F1

### Bölüm: Koşullar

#### 12. Duvara Kadar — par 4

* Ana: F1
* F1: İleri[açıksa] → Sağa[kapalıysa] → F1

#### 13. Kıvrımlı Yol — par 6

* Ana: F1
* F1: İleri[açıksa] → Sağa[kapalıysa] → Sola[kapalıysa] → Sola[kapalıysa] → F1

### Bölüm: Dünyayı Döndür

#### 14. Döner Köprü — par 3

* Başlamadan önce: döner platform #1 +90°
* Ana: F1
* F1: İleri → F1

#### 15. Mola — par 6

* Ana: F1 → Mola → F1
* F1: İleri → İleri → İleri
* 1. molada: döner platform #1 +90°

#### 16. Asansör — par 8

* Ana: F1 → İleri → Mola → F1 → Sola → F1
* F1: İleri → İleri
* 1. molada: kaydırıcı #1 ileri/yukarı, kaydırıcı #1 ileri/yukarı

#### 17. İmkânsız Geçit — par 11

* Başlamadan önce: kamera sola
* Ana: İleri → İleri → İleri → Sağa → İleri → İleri → Mola → İleri → İleri → Sola → İleri
* 1. molada: kamera sağa, kamera sağa

### Bölüm: Ustalık

#### 18. Taşıyıcı — par 12

* Ana: F1 → F1 → Kullan → Mola → İleri → Kullan → Mola → F2
* F1: Kullan → İleri
* F2: İleri → F2
* 1. molada: döner platform #1 −90°
* 2. molada: döner platform #1 +90°

#### 19. Çöken Zemin — par 27

* Ana: İleri → İleri → Sağa → İleri → Kullan → Sola → İleri → Sola → İleri → İleri → Kullan → Sağa → İleri → Sağa → İleri → İleri → Sola → İleri → Sağa → Kullan → Sağa → Sağa → İleri → Sağa → İleri → İleri → İleri

#### 20. Son Kule — par 24

* Başlamadan önce: kamera sağa, kamera sağa
* Ana: Kullan → Sola → Kullan → İleri → Sola → Kullan → Sağa → Kullan → F1 → F1 → F1 → F1 → İleri → Sola → F2 → Zıpla → Zıpla → İleri → İleri
* F1: İleri → Kullan
* F2: İleri → İleri → İleri

### Bölüm: Yankılar

#### 21. Terazi Kulesi — par 17

* Ana: F1 → Kullan → Sola → F1 → Sağa → F1 → Sağa → Kullan → Sağa → İleri → Sağa → İleri → Sola → F1 → İleri
* F1: İleri → İleri

#### 22. Ayna Kapı — par 12

* Ana: İleri → Sola → İleri → Sağa → İleri → Kullan → Sağa → İleri → Sola → F1
* F1: İleri → F1

#### 23. Kutu Işınlama — par 11

* Ana: F1 → F1 → Sağa → İleri → İleri → Sola → F2
* F1: İleri → Kullan
* F2: İleri → F2

#### 24. Yankı Labirenti — par 6

* Ana: F1
* F1: İleri[açıksa] → Sağa[kapalıysa] → Sola[kapalıysa] → Sola[kapalıysa] → F1

#### 25. Yıldızlar Arası — par 12

* Ana: F1 → Mola → F1 → F2 → Mola → F1 → F1
* F1: İleri → İleri → İleri
* F2: İleri → İleri
* 1. molada: döner platform #1 +90°
* 2. molada: kaydırıcı #1 ileri/yukarı, kaydırıcı #1 ileri/yukarı, kamera sağa

## Klasik seviyeler (Godot sürümü, dokun-yürü)

Bu çözümler tam (BFS) çözücü tarafından otomatik bulunmuştur ve en kısa eylem dizileridir.

### 1. İlk Adım

Bir kareye dokun, Robo oraya yürüsün. Merdivenler yukarı çıkar.

Par: **7** hamle

1. Adım +X (doğu)
2. Adım +X (doğu)
3. Adım +X (doğu)
4. Adım +X (doğu)
5. Adım +Z (güney)
6. Adım +X (doğu)
7. Adım +X (doğu)

### 2. Kol ve Köprü

Kolun yanına yürü ve ona doğru ilerle: köprü belirir.

Par: **13** hamle

1. Adım +Z (güney)
2. Adım +Z (güney)
3. Adım -X (batı)
4. Adım +X (doğu)
5. Adım -Z (kuzey)
6. Adım +X (doğu)
7. Adım +X (doğu)
8. Adım +X (doğu)
9. Adım +X (doğu)
10. Adım +Z (güney)
11. Adım +X (doğu)
12. Adım -Z (kuzey)
13. Adım -Z (kuzey)

### 3. Ağır Kutu

Basınç plakası yalnızca üzerinde ağırlık varken çalışır. Kutuyu it!

Par: **19** hamle

1. Adım +X (doğu)
2. Adım +X (doğu)
3. Adım +X (doğu)
4. Adım +Z (güney)
5. Adım +Z (güney)
6. Adım -X (batı)
7. Adım -Z (kuzey)
8. Adım -X (batı)
9. Adım +Z (güney)
10. Adım +X (doğu)
11. Adım +X (doğu)
12. Adım -Z (kuzey)
13. Adım +X (doğu)
14. Adım +X (doğu)
15. Adım +X (doğu)
16. Adım +X (doğu)
17. Adım +X (doğu)
18. Adım +Z (güney)
19. Adım +Z (güney)

### 4. Boşluğu Doldur

Kutular boşluklara düşer ve yeni zemin olur. Hangi kutu nereye?

Par: **19** hamle

1. Adım +Z (güney)
2. Adım +X (doğu)
3. Adım +X (doğu)
4. Adım +Z (güney)
5. Adım +Z (güney)
6. Adım -X (batı)
7. Adım -Z (kuzey)
8. Adım -X (batı)
9. Adım -Z (kuzey)
10. Adım +X (doğu)
11. Adım +X (doğu)
12. Adım +X (doğu)
13. Adım +X (doğu)
14. Adım +X (doğu)
15. Adım +X (doğu)
16. Adım +X (doğu)
17. Adım +X (doğu)
18. Adım +Z (güney)
19. Adım +Z (güney)

### 5. Döner Köprü

Saplı platformlar döner. Sapa dokun ya da platformu sürükle; üstündeki her şey onunla döner.

Par: **16** hamle

1. Adım +X (doğu)
2. Adım +X (doğu)
3. Döner platform #1 +90°
4. Adım +X (doğu)
5. Adım +X (doğu)
6. Adım +X (doğu)
7. Adım +X (doğu)
8. Adım +X (doğu)
9. Adım +Z (güney)
10. Adım -X (batı)
11. Adım -X (batı)
12. Döner platform #1 -90°
13. Adım +Z (güney)
14. Adım +Z (güney)
15. Adım +Z (güney)
16. Adım +Z (güney)

### 6. Kayan Yol

Raylı platformları oklarla kaydır. Asansörler de birer kaydırıcıdır.

Par: **12** hamle

1. Adım +X (doğu)
2. Adım +X (doğu)
3. Kaydırıcı #1 ileri
4. Kaydırıcı #1 ileri
5. Kaydırıcı #1 ileri
6. Adım +X (doğu)
7. Adım +X (doğu)
8. Adım +X (doğu)
9. Kaydırıcı #2 ileri
10. Kaydırıcı #2 ileri
11. Adım +X (doğu)
12. Adım +X (doğu)

### 7. Yuvarlanan Top

Topa doğru yürüyünce top yuvarlanır ve bir engele çarpana dek durmaz. Kollara çarpan top onları çevirir.

Par: **7** hamle

1. Adım +X (doğu)
2. Adım +X (doğu)
3. Adım -Z (kuzey)
4. Adım -Z (kuzey)
5. Adım -Z (kuzey)
6. Adım -Z (kuzey)
7. Adım -Z (kuzey)

### 8. Top Asansörü

Asansör, plakada ağırlık varken yükselir. Ama sen de üstünde olmalısın...

Par: **20** hamle

1. Adım +Z (güney)
2. Adım +Z (güney)
3. Adım +X (doğu)
4. Adım +X (doğu)
5. Adım +X (doğu)
6. Adım +Z (güney)
7. Adım +X (doğu)
8. Adım -Z (kuzey)
9. Adım -X (batı)
10. Adım -Z (kuzey)
11. Adım -Z (kuzey)
12. Adım -Z (kuzey)
13. Adım -Z (kuzey)
14. Adım +X (doğu)
15. Adım +X (doğu)
16. Adım +Z (güney)
17. Adım +Z (güney)
18. Adım -X (batı)
19. Adım +X (doğu)
20. Adım +X (doğu)

### 9. Terazi

İki kefe birbirine bağlı: ağır olan iner, hafif olan yükselir. Kutular da sen de birer ağırlıksın.

Par: **16** hamle

1. Adım +Z (güney)
2. Adım +X (doğu)
3. Adım +X (doğu)
4. Adım +X (doğu)
5. Adım +Z (güney)
6. Adım +X (doğu)
7. Adım +X (doğu)
8. Adım -Z (kuzey)
9. Adım -X (batı)
10. Adım -X (batı)
11. Adım +X (doğu)
12. Adım -Z (kuzey)
13. Adım +X (doğu)
14. Adım +X (doğu)
15. Adım +X (doğu)
16. Adım +X (doğu)

### 10. Çöken Zemin

Çatlak taşlar üzerinden geçtikten sonra çöker. Rotanı iyi planla!

Par: **17** hamle

1. Adım +X (doğu)
2. Adım +X (doğu)
3. Adım +Z (güney)
4. Adım +Z (güney)
5. Adım +X (doğu)
6. Adım -Z (kuzey)
7. Adım -Z (kuzey)
8. Adım -Z (kuzey)
9. Adım +X (doğu)
10. Adım +Z (güney)
11. Adım +Z (güney)
12. Adım +X (doğu)
13. Adım +Z (güney)
14. Adım -Z (kuzey)
15. Adım +X (doğu)
16. Adım +X (doğu)
17. Adım +X (doğu)

### 11. İmkânsız Geçit

Bazı yollar yalnızca doğru açıdan bakınca birleşir. Kamerayı çevir (Q / E).

Par: **8** hamle

1. Adım +X (doğu)
2. Adım +X (doğu)
3. Kamerayı sola çevir
4. Adım +X (doğu)
5. Adım +Z (güney)
6. Adım +Z (güney)
7. Kamerayı sağa çevir
8. Kamerayı sağa çevir
9. Adım +Z (güney)
10. Adım +X (doğu)
11. Adım +Z (güney)

### 12. Taşıyıcı

Döner platform kutuyu da taşır. Kutuyu plakaya ulaştır, kapı açılsın.

Par: **9** hamle

1. Adım +X (doğu)
2. Adım +X (doğu)
3. Adım +X (doğu)
4. Döner platform #1 -90°
5. Adım +Z (güney)
6. Döner platform #1 +90°
7. Adım +X (doğu)
8. Adım +X (doğu)
9. Adım +X (doğu)

### 13. Topçu

Topu doğru yerde durdurmak için raylı engeli kullan. Kol da plaka da gerekli.

Par: **18** hamle

1. Adım +X (doğu)
2. Adım -Z (kuzey)
3. Kaydırıcı #1 ileri
4. Adım +X (doğu)
5. Adım +X (doğu)
6. Adım +X (doğu)
7. Adım +X (doğu)
8. Adım +X (doğu)
9. Adım +X (doğu)
10. Adım +X (doğu)
11. Adım +Z (güney)
12. Adım +X (doğu)
13. Adım -Z (kuzey)
14. Adım +Z (güney)
15. Adım +Z (güney)
16. Adım +Z (güney)
17. Adım +X (doğu)
18. Adım +Z (güney)

### 14. Kargo

Kutuyu kayan platformla karşıya taşı. Çatlak taşlara dikkat!

Par: **17** hamle

1. Adım +X (doğu)
2. Adım +X (doğu)
3. Adım +X (doğu)
4. Kaydırıcı #1 ileri
5. Kaydırıcı #1 ileri
6. Adım +X (doğu)
7. Adım +X (doğu)
8. Adım -Z (kuzey)
9. Adım +X (doğu)
10. Adım +Z (güney)
11. Adım +Z (güney)
12. Adım +X (doğu)
13. Adım +Z (güney)
14. Adım +X (doğu)
15. Adım +X (doğu)
16. Adım +X (doğu)
17. Adım +Z (güney)

### 15. Son Kule

Her şeyi birleştir: kol, kutu, döner platform ve imkânsız bir geçit.

Par: **20** hamle

1. Adım -Z (kuzey)
2. Adım -Z (kuzey)
3. Adım +X (doğu)
4. Döner platform #1 +90°
5. Adım +X (doğu)
6. Adım +X (doğu)
7. Adım +X (doğu)
8. Adım +X (doğu)
9. Adım +X (doğu)
10. Adım -Z (kuzey)
11. Adım +X (doğu)
12. Adım +Z (güney)
13. Adım -X (batı)
14. Adım +Z (güney)
15. Kamerayı sola çevir
16. Adım +Z (güney)
17. Kamerayı sağa çevir
18. Adım -Z (kuzey)
19. Adım -Z (kuzey)
20. Adım -Z (kuzey)
21. Adım -Z (kuzey)
22. Adım -Z (kuzey)

