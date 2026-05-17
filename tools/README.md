# Arazi Pipeline (EXR → oyun verisi)

Kaynak yükseklik haritası `source_assets/heightmaps/yarimada_16bit.exr`
işlenip oyunun okuduğu `data/terrain/height.f32` + `data/terrain/terrain.json`
üretilir. Oyun bu dosyaları `TerrainData` ile okur (Godot kodu değişmez).

## Yeniden üretim

Blender 4.x gerekir (numpy'li Python). Repo kökünde:

```
blender --background --factory-startup --python tools/build_map.py
```

- `HEIGHTMAP`/`OUT` repo köküne göre otomatik çözülür.
- Çıktı: `data/terrain/height.f32` (row-major float32, 0..1) +
  `data/terrain/terrain.json` (`w,h,world_size,relief,sea,zmin,zmax`).
- Ayrıca 10 referans render `data/terrain/render_*.png` üretir
  (commit zorunlu değil).

EXR değişirse bu komutu tekrar çalıştır; oyun otomatik yeni araziyi
kullanır.
