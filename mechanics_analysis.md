# MythicPlusTimer Mekanik Analizi

## 1. Zamanlayıcı ve Sandık Hesaplamaları (Timer Mechanics)

Zamanlayıcı mekanikleri `timer.lua` dosyası içinde yönetilmektedir.

### Başlatma ve Durdurma
- **Başlangıç:** `CHALLENGE_MODE_START` veya `PLAYER_ENTERING_WORLD` eventleri ile tetiklenir (`on_challenge_mode_start`).
- **Bitiş:** `CHALLENGE_MODE_COMPLETED` veya `CHALLENGE_MODE_RESET` eventleri ile durur.
- **Güncelleme:** Her saniye (`on_update_time`) arayüz güncellenir.

### Sandık (+2 / +3) Hesaplamaları
Sandık süreleri `timer.lua` içindeki `calculate_chest_timers` fonksiyonunda hesaplanır.

**Temel Formül:**
- **+2 Sandık:** Toplam Süre * 0.8 (%80)
- **+3 Sandık:** Toplam Süre * 0.6 (%60)

**Özel Durum: Challenger's Peril (Affix ID: 152)**
Eğer bu affix aktifse, hesaplama değişir:
1. `old_timer` = Toplam Süre - 90 saniye
2. **+2 Sandık:** `old_timer * 0.8 + 90`
3. **+3 Sandık:** `old_timer * 0.6 + 90`

## 2. Boss Takibi ve Split Zamanları (Boss Mechanics)

Boss mekanikleri `criteria.lua` dosyasında yönetilir.

### Boss Tespiti
- Oyunun `C_Scenario.GetStepInfo()` ve `C_ScenarioInfo.GetCriteriaInfo(i)` API'leri kullanılarak tüm hedefler taranır.
- `isWeightedProgress` değeri `false` olan hedefler Boss olarak kabul edilir.

### Split Zamanı Kaydı (`set_step_completed`)
- Bir boss öldüğünde o anki `elapsed_time` (geçen süre) kaydedilir.
- Bu süre, daha önceki "En İyi Zamanlar" (Best Times) ile karşılaştırılır.

### En İyi Zaman Karşılaştırması
Addon, boss kesim sürelerini 3 farklı kategoride saklar ve karşılaştırır:
1. **Zone:** Sadece o zindandaki en iyi zaman.
2. **Zone + Level:** O zindan ve o anahtar seviyesindeki en iyi zaman.
3. **Zone + Level + Affixes:** O zindan, o seviye ve o affix kombinasyonundaki en iyi zaman.

Arayüzde gösterilen fark (örneğin `(-1:30)` veya `(+0:45)`), bu kayıtlı en iyi zamanlar ile o anki sürenin farkıdır. `objective_time_delta_only` ayarı açıksa sadece fark gösterilir.

## 3. Enemy Forces (Çöp / Trash) İlerlemesi

Enemy Forces mekanikleri de `criteria.lua` içindedir.

### İlerleme Tespiti ("Pull Pull Pull")
- `isWeightedProgress` değeri `true` olan hedef, Enemy Forces (Çöp) barı olarak kabul edilir.
- İlerleme verisi doğrudan Blizzard API'sinden (`criteriaInfo.quantity`) alınır.
- **NOT:** Kodda bireysel "pull" (tek tek çekilen gruplar) değerlerini hesaplayan aktif bir mantık bulunmamaktadır. Sadece toplam ilerleme okunur.

### Yüzde Hesaplaması (`resolve_step_info`)
- **Yüzde:** `(Mevcut Değer / Toplam Hedef Değer) * 100` formülü kullanılır.
- 2 ondalık basamağa yuvarlanır.
- Eğer görev tamamlandıysa otomatik olarak %100 ve Tam Sayı gösterilir.

### Görsel Renk Değişimi
Barın rengi ilerlemeye göre Kırmızıdan Yeşile döner:
- `red_color_base` (0.8) -> İlerlemeye göre azalır.
- `green_color_base` (0.4) -> İlerlemeye göre artar.

## 4. Ölüm Sayacı (Death Counter)

Ölüm sayacı `infos.lua` dosyasında `infos.update_deathcounter` fonksiyonu ile yönetilir.

- **Veri Kaynağı:** `C_ChallengeMode.GetDeathCount()` API'si kullanılır.
- **Ceza Hesaplaması:** API doğrudan `deathCount` (sayı) ve `timeLost` (kaybedilen süre) değerlerini döndürür.
- **Görüntüleme:** "X Deaths -Y:YY" formatında (Örn: "5 Deaths -0:25") gösterilir.

## 5. Ayarlar ve Yapılandırma (Configuration)

Ayarlar `config.lua` dosyasında `CONFIG_VALUES` tablosunda saklanır.

### Önemli Ayarlar
- `objective_time`: Split zamanlarını göster/gizle.
- `objective_time_perlevel` / `perlevelaffix`: Karşılaştırma kriterini seçer.
- `show_deathcounter`: Ölüm sayacını aç/kapa.
- `show_percent_numbers`: Yüzdelik gösterimi (%42.5).
- `show_absolute_numbers`: Mutlak sayı gösterimi (150/300).
- `scale`: Arayüz ölçeklendirme (0.5x - 3.0x).

### NPC Progress (Gizli/Pasif Özellik)
`config.lua` dosyasında `npc_progress` adında bir tablo ve bunu dışa aktaran (`export_data`) bir fonksiyon bulunmaktadır. Ancak mevcut kod tabanında bu tabloyu dolduran (yani her mob öldüğünde ne kadar yüzde verdiğini hesaplayan) aktif bir kod bloğu (Combat Log takibi vb.) `main.lua` veya diğer dosyalarda **görülmemektedir**. Bu özellik şu an pasif durumda görünmektedir veya dışarıdan veri yüklenmesi beklenmektedir.
