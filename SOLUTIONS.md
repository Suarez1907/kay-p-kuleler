# Seviye Çözümleri

Bu çözümler `tools/build.mjs` içindeki tam (BFS) çözücü tarafından otomatik bulunmuştur ve en kısa eylem dizileridir.

## 1. İlk Adım

Bir kareye dokun, Robo oraya yürüsün. Merdivenler yukarı çıkar.

Par: **7** hamle

1. Adım +X (doğu)
2. Adım +X (doğu)
3. Adım +X (doğu)
4. Adım +X (doğu)
5. Adım +Z (güney)
6. Adım +X (doğu)
7. Adım +X (doğu)

## 2. Kol ve Köprü

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

## 3. Ağır Kutu

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

## 4. Boşluğu Doldur

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

## 5. Döner Köprü

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

## 6. Kayan Yol

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

## 7. Yuvarlanan Top

Topa doğru yürüyünce top yuvarlanır ve bir engele çarpana dek durmaz. Kollara çarpan top onları çevirir.

Par: **7** hamle

1. Adım +X (doğu)
2. Adım +X (doğu)
3. Adım -Z (kuzey)
4. Adım -Z (kuzey)
5. Adım -Z (kuzey)
6. Adım -Z (kuzey)
7. Adım -Z (kuzey)

## 8. Top Asansörü

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

## 9. Terazi

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

## 10. Çöken Zemin

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

## 11. İmkânsız Geçit

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

## 12. Taşıyıcı

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

## 13. Topçu

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

## 14. Kargo

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

## 15. Son Kule

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

