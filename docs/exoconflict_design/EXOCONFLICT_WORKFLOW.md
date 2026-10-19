# EXOCONFLICT: Stellar Horizon — Player Workflow & UI/UX Design

**Versi:** 1.0 — 19 Okt 2026
**Branch:** `arena/c8558858-cyber-strike`
**Bahasa:** Indonesia (sesuai permintaan)

---

## 1. Ringkasan Alur Pemain (End-to-End)

```
[1] SPLASH BOOT (Godot boot) 
    ↓ auto 0.5s
[2] LOADING CINEMATIC 16:9 
    - Background 4K: alien frontier dengan reactor hexagonal (loading_background_16x9_4k.png)
    - Wordmark di tengah-atas: EXOCONFLICT / STELLAR HORIZON dengan emblem diamond (wordmark_exoconflict.png)
    - Robot berjalan di bawah tengah: animasi green-chroma sprite → di-key ke loading bar (robot_walk_green_chroma.png → 4 frame, di-chroma jadi icon)
    - Progress bar + persen 0-100% di bawah
    ↓ asset loaded
[3] CINEMATIC CHAPTER 1 (5-7 detik, skippable)
    - Fullscreen video/image sequence: drop-pod masuk atmosfer, reactor menyala, hero NEXUS-01 mendarat
    - Subtitle cinematic: "HORIZON BREACH — YEAR 2174"
    - Skip = tap / ESC / tombol LEWATI
    ↓ selesai / diskip → DASHBOARD
[4] DASHBOARD HUB (Dashboard proper, bukan pause)
    - Background: dashboard_bg_sci_fi.png (command center dengan dua robot, panel hologram)
    - Dock NAV atas: profile card (hexagonal, tidak generik), resource coin (CRYSTAL + GOLD), notifikasi
    - Menu utama tengah: PLAY, HERO, WEAPON, WORLD, SETTINGS — ikonik robot sci-fi, bukan list teks
    - Tier display: hero tier (NEXUS-01) + weapon tier (PULSE RIFLE) di sisi kiri/kanan
    ↓ user tekan PLAY atau pilih HERO
[5] HERO SELECT MODAL (step 1 dari 3)
    - Grid 3 card hexagonal: NEXUS-01 (unlock) + FORTRESS + VEX (locked)
    - Tap card → Modal detail: stat Damage/Shield/Speed/Agility + lore + tombol PILIH
    - Hero_locked_variants.png dipakai untuk 2 locked card, hero_nexus01_card.png untuk unlock
    ↓ PILIH → tutup modal 1
[6] WEAPON SELECT MODAL (step 2)
    - Grid 3 card: PULSE RIFLE (unlock) + NOVA + ARC (locked)
    - weapon_pulse_rifle_card.png vs weapon_locked_variants.png
    - Detail: DPS, Fire Rate, Mag, Range, Ability
    ↓ PILIH → tutup modal 2
[7] WORLD SELECT MODAL (step 3)
    - 3 dunia isometrik: NEON FRONTIER / CRYSTAL CAVERNS / WRECKED SECTOR (world_select_three.png dipotong jadi 3 card)
    - Detail per dunia: enemy type, reward, difficulty
    ↓ PILIH + tombol PLAY BESAR (amber) → LOADING ASSET
[8] LOADING ASSET (kedua)
    - Sama seperti [2] tapi progress “LOADING WORLD: NEON FRONTIER 43%”
    - Robot walk icon tetap, background sama (bisa ganti variant gelap)
    ↓ 100% → GAMEPLAY (main.tscn)
[9] GAMEPLAY HUD (di dunia 3D)
    - Card profil kiri-atas: avatar hexagonal NEXUS-01 + health bar + shield
    - Card resource kanan-atas: BP/coin + ammo + timer
    - Mini-map kanan-bawah (?): radar hexagonal dengan hostile bearings
    - Kontrol sentuh tetap: joystick + FIRE/AIM/EMP/SWAP dengan gap 16px yang sudah diperbaiki
    ↓ pause / KO / selesai → RESULTS → kembali ke DASHBOARD
```

Semua step memakai asset foto 4K yang sudah di-generate, bukan placeholder generik.

---

## 2. Research Dashboard UI Pro (Sci-Fi Robot Genre)

**Referensi yang diverifikasi (bukan klaim kosong):**
- [Envato Futuristic HUD UI Kit 1920x1080](https://elements.envato.com/futuristic-game-ui-with-hud-DJ6DW6Y) — 200+ elemen HUD, circular gauge, progress wheel, slot/placeholder.
- [GameArt2D Sci-fi Robot GUI](https://www.gameart2d.com/game-gui-15.html) — 42 tombol ikonik, window, level selection, transformable vector.
- [Figma Futuristic UI Kit 200 elements](https://www.figma.com/community/file/1394170759478058748/futuristic-ui-kit-200-design-elements) — 125 ikon abstrak + 36 elemen circular, cocok untuk tier/equipment.
- [Envato Sci-Fi HUD Elements Pack 1920x1080](https://elements.envato.com/sci-fi-hud-game-ui-elements-pack-9NRW52M) — glow effect, circular play buttons, HUD circles.
- [Itch.io Sci-Fi FPS Mobile HUD](https://www.artstation.com/artwork/Ke09AG) — inspirasi minimalis ala Anthem / COD Infinite Warfare, dipakai untuk portrait mobile.

**Prinsip yang diambil untuk EXOCONFLICT:**
1. **Hexagonal, bukan rounded-rect generik** — semua card profile/weapon/world pakai bracket sudut 10px + stroke 1px ala AEGIS, tapi bentuk luar hexagonal (clip via shader atau texture).
2. **Dock NAV economy di atas** — koin CRYSTAL (ungu) + GOLD (amber) di kanan-atas, profile di kiri-atas, berlawanan agar tidak rebutan dengan pause.
3. **Tier visual** — bintang/hexagon kecil di bawah avatar, warna ok/cyan/ability untuk tier 1-3.
4. **Ikonik, tidak tekstual** — setiap menu punya glyph asli (play = play, hero = heart/shield, weapon = rifle, world = target, settings = gear). Teks hanya tooltip.
5. **Depth** — bukan flat: scrim 0.62-0.74 + panel 92-96%, plus glow tipis di emblem.

---

## 3. Spesifikasi Layar Rinci

### 3.1 Loading Cinematic (16:9)

- **Canvas:** 1920x1080 (stretch canvas_items)
- **Background:** `loading_background_16x9_4k.png` — cover penuh, brightness 0.85 agar wordmark terbaca
- **Wordmark:** `wordmark_exoconflict.png` — 860x260 logical px, posisi y = 12% dari atas, center-x, scale 0.85 di mobile portrait (480x720)
- **Loading Bar:** di bawah 18% dari bawah, lebar 560px, tinggi 8px, border 1px `line` #27384A, fill gradient cyan→emerald, bracket di ujung
- **Robot Icon:** `robot_walk_green_chroma.png` — 4 frame horizontal, tiap frame 512x512, di-crop via `AtlasTexture`, chroma green (0,255,0) di-key jadi transparan lewat shader `chroma_key.gdshader` atau di-preprocess jadi PNG transparan. Posisi di atas bar, animasi 8 fps, bergerak seiring persen (x = bar left + percent * width)
- **Persen Text:** JetBrainsMono Bold 22, `ink` #EDF5FB, di kanan bar: “43%”
- **Tips:** di bawah bar: “TIP: Tahan AIM untuk presisi” berganti tiap 3 detik

Implementasi Godot: `game/scenes/ui/exoconflict_loading.tscn` + `exoconflict_loading.gd`

### 3.2 Cinematic Player

- Video bukan file .mp4 lokal (Godot web tidak support VideoStream di Compatibility), jadi: **image sequence 5 frame** dari world_select_three + reactor closeup, di-crossfade 1.2s tiap frame, plus audio synth.
- Ukuran penuh, subtitle di bawah 10% dengan background semi-transparan
- Tombol LEWATI di kanan-bawah 100x36, ghost variant
- Auto selesai 6 detik → emit `cinematic_finished`

### 3.3 Dashboard Hub

**Struktur 1280x720:**
```
┌──────────────────────────────────────────────────────────────┐
│ [PROFILE HEX 220x88]      [TITLE EXOCONFLICT]   [COIN 140x36][GOLD 140x36][SETTINGS 44] │
│                                                         │
│  [MENU RAIL 240w]        [FEATURED WORLD 620x360]    [TIER PANEL 220w] │
│   ► PLAY (amber fill)      NEON FRONTIER isometrik     HERO NEXUS-01   │
│   HERO                      CRYSTAL CAVERNS             WEAPON PULSE    │
│   WEAPON                    WRECKED SECTOR              STATS           │
│   WORLD                     [SELECT WORLD btn]          UPGRADE         │
│   SETTINGS                                                  │
│  ─────────────────────────────────────────────────────────  │
│  DAILY MISSION  |  BATTLE PASS  |  SHOP                                    │
└──────────────────────────────────────────────────────────────┘
```

Mobile portrait: jadi vertical stack — profile di atas, menu rail jadi bottom dock 60 tinggi dengan 5 ikon, featured world di tengah scroll.

Profile Card: **tidak generik** — bentuk hexagonal dengan bracket sudut, avatar di kiri (64px), di kanan nama + level + tier dots. Border kiri 2px accent amber jika selected.

Economy Dock: CRYSTAL (ungu #B79CFF) + GOLD (amber #FFB020), masing-masing pill 140x36 dengan ikon + angka mono. Klik → shop.

### 3.4 Selection Modals (3 langkah)

**Hero Modal:**
- Grid 1x3 di desktop, 1x3 horizontal scroll di mobile
- Card 200x280: gambar hero di atas 200x160 (hexagonal mask), di bawah nama + class + 4 stat bar (Damage, Shield, Speed, Utility)
- Locked card: overlay gelap 60% + ikon gembok hexagonal di tengah, blur 2px
- Tap card → detail sheet 520x400 slide up: gambar besar + stat radar chart + tombol PILIH (amber) / BATAL (ghost)

**Weapon Modal:** sama, tapi stat = DPS, Fire Rate, Mag, Range, Ability (EMP)

**World Modal:** 3 card isometrik world_select_three dipotong, tiap 260x180, detail di bawah: enemy, reward, difficulty (3 hex)

**Flow:** Dashboard → HERO modal (auto open jika PLAY ditekan tanpa hero terpilih) → setelah pilih hero → WEAPON modal → setelah pilih weapon → WORLD modal → tombol PLAY BESAR di world modal → loading asset

### 3.5 Gameplay HUD Cards (di dunia 3D)

Sudah ada HUD touch_controls, tapi tambahkan:
- **Profile Card:** 168x48 di kiri-atas, avatar hexagonal + nama hero + level, health bar 146x4 di bawahnya (sama seperti vitals tapi dengan avatar)
- **Resource Card:** 184x30 di kanan-atas, BP + coin, ammo pill 112x54 di dekat weapon (sudah ada touch_ammo_chip, pindahkan 16px dari edge)
- **Mini-Map:** 140x140 di kanan-bawah di atas FIRE, radar circular dengan hostile bearings (pakai hud_hostile_bearings yang sudah ada, tapi render dalam card)

---

## 4. Asset Manifest (sudah di-generate)

| File | Ukuran | Dipakai |
|------|--------|--------|
| loading_background_16x9_4k.png | 4035 KB | Loading 1 & 2, dashboard fallback |
| wordmark_exoconflict.png | 2031 KB | Loading wordmark, dashboard title |
| robot_walk_green_chroma.png | 2255 KB | Loading icon (4 frame) |
| dashboard_bg_sci_fi.png | 1664 KB | Dashboard background |
| hero_nexus01_card.png | 3687 KB | Hero select unlock |
| hero_locked_variants.png | 2747 KB | Hero locked 03/04 |
| weapon_pulse_rifle_card.png | 2529 KB | Weapon unlock |
| weapon_locked_variants.png | 2234 KB | Weapon locked NOVA/ARC |
| world_select_three.png | 3331 KB | World select 3 dunia |

Semua 4K, format PNG, siap pakai di Godot via `preload`.

---

## 5. Implementasi Godot (File Baru)

```
game/scenes/ui/exoconflict_loading.tscn + exoconflict_loading.gd
game/scenes/ui/exoconflict_dashboard.tscn + exoconflict_dashboard.gd
game/scenes/ui/exoconflict_selection.tscn + exoconflict_selection.gd
game/scenes/ui/exoconflict_cinematic.tscn + exoconflict_cinematic.gd
game/scenes/ui/exoconflict_gameplay_overlay.tscn (profile+resource+map)
game/assets/ui/exoconflict/images/*.png (sudah ada)
game/scripts/ui/exoconflict_flow.gd (state machine)
game/shaders/chroma_key.gdshader (opsional, key green)
```

Flow manager: `ExoconflictFlow` autoload atau node di main.tscn yang mengontrol:
`LOADING -> CINEMATIC -> DASHBOARD -> HERO_SELECT -> WEAPON_SELECT -> WORLD_SELECT -> LOADING_ASSET -> GAMEPLAY`

Sinyal: `hero_selected(hero_id)`, `weapon_selected(weapon_id)`, `world_selected(world_id)`, `play_requested`

Semua modal pakai `AegisPanel` + `AegisButton` yang sudah ada, jadi konsisten dengan token AEGIS.

---

## 6. QA & Acceptance

- 1280x720, 390x844, 844x390: loading wordmark tidak terpotong, bar di 16px dari bawah, robot icon tidak menyentuh bezel
- Dashboard: profile hexagonal terbaca, economy dock tidak overlap pause
- Modal hero/weapon/world: tap card → detail → PILIH → next modal; locked card tidak bisa dipilih (toast “LOCKED - PLAY WAVES TO UNLOCK”)
- Gameplay: profile card + resource card + map terlihat, kontrol sentuh tetap 16px gap (sudah fix)
- Web preview: boot → loading → cinematic (skippable) → dashboard dalam < 8s di Chromium

