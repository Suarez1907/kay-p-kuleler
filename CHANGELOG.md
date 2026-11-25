# Sürüm Notları

## v3.5.0
- 100 devre seviyesi baştan kurgulandı: faz faz hareket/F1, diyot, kondansatör, röle OR, röle AND+klon, direnç zamanlaması ve birleşik final. Parça sırası ve kayıt anahtarları aynı.
- `par_commands` artık yuva sınırına sığan en kısa çözüm. Doğrulayıcı başlangıç/hedef, röle→köprü bağı, ipucu çözümü ve parı denetler; tutmazsa CI durur.

## v3.4.0
- Kamera artık 90° kilitlenmez: parmak veya fare ile 360°'nin herhangi bir açısına serbest yörünge, bırakınca sönen atalet, tekerlek / izleme dörtgeni / iki parmak yakınlaştırma. Sıfırlama düğmesi varsayılan kadraja döner.
- Hayalet blok ve göz yanılması geçitleri en yakın yasal 90° bakışta değerlendirilir. Çakışan hayalet açısında kamera yavaşça son yasal açıya döner; diğer seviyelerde açı serbest kalır. Yükseliş sabit izometriktir.
- Röle AND/OR giriş ışığı ve sayacı, kondansatör fırlatma oku, direnç bekleme yazısı. Engel yuvası vurgusu, kademeli ipucu sapması, par verimliliği, Bilgisayarım faz kadrajı.
- Parlama eşiği odak noktalarına çekildi, vinyet hafifletildi, röle/kondansatör titreşimi ve ses tekrarları kısaldı. Atalet durunca boşta 30 FPS korunur.

## v3.3.1
- Isınma/donma düzeltmesi: varsayılan 60 FPS sınırı, boşta 30 FPS, termal kısma koruması (45 FPS), Ayarlar'dan isteğe bağlı 120 FPS.
- VRAM sıkıştırma telefona ulaştı: `.import` dosyaları depoya eklendi (2K dokular ETC2/ASTC + mipmap, ışık haritaları ASTC HDR).
- CI: Godot içe aktarma önbelleği (`.godot/imported`) eklendi; temiz içe aktarma ~1 saat sürüyordu, sonraki derlemeler yalnızca değişeni işler.
- Masaüstü S3TC/BPTC içe aktarması kapatıldı; yalnızca telefonun kullandığı ETC2/ASTC üretilir.

## v3.3.0
- 100 seviyenin fırınlanmış ışık haritaları + kalite korunarak FPS optimizasyonu.

## v3.2.0
- 2K PBR + 2K HDRI + LightmapGI fırınlanmış seviyeler.

## v3.1.0
- Okunabilir arayüz ölçeği, Google Play API 36, uyumluluk denetimi, Godot skill'leri.

## v3.0.2
- Google Play uyumluluk ve performans düzeltmeleri.
