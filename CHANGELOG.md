# Sürüm Notları

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
