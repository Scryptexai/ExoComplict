# Visual & gameplay QA — Hero, FBX frontier, dan Defense

**18 Oktober 2026.** Ini catatan bukti untuk perubahan di branch `arena/5257bce8-cyber-strike`, bukan sertifikat bahwa game sudah final. Label **VERIFIED** berarti file, pose, atau runtime benar-benar diperiksa; **LIKELY** berarti didukung bukti terbatas; **UNKNOWN** berarti belum diuji. Persetujuan pengguna untuk arah Warframe-relight/Destiny-hierarchy/Explore aman tidak berarti persetujuan visual hasil.

## 1. Actual assets inspected

| Berkas | Jenis dan temuan | Status |
|---|---|---|
| `game/assets/characters/hero/hero.glb` | Ekspor Blender dari rig 79 bone, satu skin/satu mesh, sepuluh clip: `idle`, `walk`, `run`, `aim`, `aim_walk`, `aim_run`, `fire`, `reload`, `hit`, `death`. | **VERIFIED** via header/chunk glTF, laporan Blender, dan render pose. |
| `source-assets/characters/hero/hero_source.blend` | Sumber editable Blender 4.0.2 yang dibuat di GitHub runner, bukan nama berkas kosong. Berada di luar `game/` agar Godot tidak berupaya mengimpor `.blend` sebagai scene kedua. | **VERIFIED** lewat job `39094558843` dan `39096185764` (Blender + import/smoke Godot); inspeksi viewport interaktif Blender oleh seniman **UNKNOWN**. |
| `game/assets/weapons/futuristic_rifle/rifle.glb` | Satu mesh tanpa armature/komponen magazine lepas, node `GripPoint` dan `MuzzlePoint`. Titik muzzle Blender Z-up `(-0.00021, 0.67008, 0.16121)` dalam meter sumber. | **VERIFIED** dalam `docs/asset-inspections/hero-blender.json` dan GLB. |
| `game/assets/world/scifi_starter_kit/models/*.glb` | Model modul konversi dari FBX unggahan: floor/wall/column/fence/console/pipe/doorway, dipasang di bay, reactor pylon, distrik, dan perimeter. | **VERIFIED** via scene, test `neon_frontier_world_smoke.gd`, dan screenshot WASM; **tidak berarti** seluruh geometri dunia FBX. |

## 2. Rig, grip, muzzle, coordinate conventions

- Skeleton bernama `Armature`; `Hip` adalah parent **bersama** dari `Pelvis` (kaki) dan `Waist` (torso). `R_Hand` menggerakkan `BoneAttachment3D` / `WeaponSocket`; senapan tidak disatukan ke mesh tubuh. `L_Hand` menopang bagian depan. Data socket di `hero_rig.json`: offset `(0, 0.018, 0)` unit model, skala rifle `0.4`, orientasi bidik dan carry terpisah. `CharacterVisual` memfit tinggi source 1 unit ke 1,78 m.
- Koordinat dari Blender ke Godot untuk marker rifle: `(x, y, z) Blender → (x, z, -y) Godot`. `MuzzlePoint` Godot `(-0.00021, 0.16121, -0.67008)` **lokal rifle**, bukan origin atau posisi karakter dunia. Kontrol kamera meraycast target, lalu projectile ditembakkan dari muzzle menuju target; collision ray sepanjang lintasan projectile membatasi tembakan menembus dinding.
- Probe Three.js menempatkan muzzle pose `aim` kira-kira `(-0.033, 1.295, 0.703)` dalam ruang review yang telah diskalakan 1,78 m; support hand `(-0.062, 1.210, 0.413)`. Arah +Z di viewer sesuai karakter hadap depan viewer; `ModelFitter` memutar model untuk forward -Z di Godot. **Jangan** membandingkan koordinat viewer itu langsung dengan world-space dalam Godot tanpa transform pivot/yaw.
- Bug QA yang terkoreksi: penampil pose awal hanya memakai rotasi socket aim pada `aim`/`fire`, sementara gameplay membutuhkan aim pada `aim_walk`, `aim_run`, `reload`, `hit`. Setelah penampil disamakan dengan gameplay, muzzle `aim_walk` pada mid-stride sekitar `(0.005, 1.313, 0.682)`; penyimpangan gun yang ekstrem pada kontak lama berasal dari viewer, bukan pose asli. Ada **defek kedua yang nyata**: `aim_run` pada ekspor `e760167` menundukkan barrel 22° pada mid-stride karena rotasi `Hip` sumber run. Bake ulang Blender `07e0fd3` menahan Hip aim sambil mempertahankan `Pelvis`/kaki dari run; probe pose `0`, `0.3`, `0.6`, `0.95` detik semuanya memberi arah muzzle sekitar `(-0.016, 0, +1.000)` dan t=0.3 menunjukkan leg stride aktif (`exports/hero-probe-07e-run/`). Belum menggantikan QA animasi runtime video.

## 3. Animations created and visual review

| Clip | Intended use and actual integration | Evidence / current visual gate |
|---|---|---|
| `idle`, `walk`, `run` | Carry stance; locomotion di-loop eksplisit pada `AnimationPlayer`. | **VERIFIED** tersedia, terpasang, dan pose sampel dirender; penilaian kesinambungan gerak multi-siklus di perangkat **UNKNOWN**. |
| `aim` | Stance dua tangan; rotasi socket menjaga barrel depan. | **VERIFIED** frame depan/samping/3⁄4; probe muzzle forward pada t=0. |
| `aim_walk`, `aim_run` | Clip komposit Blender dengan kaki bergerak dan torso membidik. | **VERIFIED** tersedia/terpilih oleh Godot, probe GLB `a6a08e9` pada `aim_run` t=0,3 memindahkan L_Foot ke `(-0,06, 0,34, 0,48)` dan t=0,4 `aim_walk` ke `(0,07, 0,26, -0,35)`; muzzle tetap mendekati horizontal. **VERIFIED PASS di Godot 4.7.2** (`39102619493`): tes tambahan mengukur L_Foot bergeser >0,25 m saat `aim_walk` dan >0,28 m saat `aim_run`, setelah crossfade selesai; bukan hanya nama clip/barrel procedural. |
| `fire` | Recoil satu kali saat tembakan riil, tanpa memproduksi projectile tambahan dari animasi. | **VERIFIED** frame puncak dan tes firing/muzzle; rasa tembak dalam burst visual manusia **UNKNOWN**. |
| `reload` | Gesture recharge dari tangan support menuju housing; `WeaponController` tetap otoritas ammo, kecepatannya mengikuti sisa timer bahkan setelah weapon switch. | **VERIFIED** signal dan pose bake `07e0fd3`: support hand t=0.62 pada `(-0.047, 1.138, 0.341)` (grip pada `(-0.031, 1.181, 0.219)`), terlihat di bawah receiver, bukan terangkat menjauh. Rifle tetap satu mesh: tidak ada magazine/bolt yang sungguh bergerak; **belum penerimaan visual final**. |
| `hit` | Reaksi nonfatal satu kali, kembali ke aim setelah clip selesai. | **VERIFIED** mapping Godot dan frame puncak; kualitas dampak di gameplay **LIKELY**, belum direkam video. |
| `death` | Motion satu kali, tahan pose akhir sampai reset. | **VERIFIED pada GLB `a6a08e9`**: re-bake `2aee8eb` memutar `BoneRoot` ke samping, tidak lagi melipat `Spine01` 105° atau menanam sepatu. Review render `exports/hero-death-side-a6/{pose-death.png,profile/pose-death.png,overhead/pose-death.png}` pada t=1,2 s: kepala y≈0,16 m, panggul y≈0,26 m, sepatu y≈0,34–0,35 m. Siluet berbaring menyamping lebih alami daripada bake `25f24da` yang akrobatik; senapan tetap di tangan dan terangkat (~0,68 m), jadi masih ada batas artistik dan motion review dalam gameplay **UNKNOWN**. |

## 4. Files changed in this review slice

- **Blender & export:** `tools/blender/author_hero.py`, `source-assets/characters/hero/hero_source.blend`, `game/assets/characters/hero/hero.glb`, `docs/asset-inspections/hero-blender.json`.
- **Runtime, world, HUD/QA:** `game/scripts/player/character_visual.gd`, `game/scripts/player/player_controller.gd`, `game/scripts/weapons/weapon_controller.gd`, `game/scripts/worlds/neon_frontier_world.gd`, `game/scripts/worlds/neon_frontier_asset.gd`, `game/scripts/worlds/scifi_kit_library.gd`, `game/tests/hero_rig_smoke.gd`, `game/tests/weapon_system_smoke.gd`, `game/tests/neon_frontier_world_smoke.gd`, `tools/render/pose_shot.mjs`, `tools/render/pose_viewer.html`, `tools/web_qa.mjs`, `WEB_PREVIEW.md`, `docs/REBASE_VISUAL_GAMEPLAY_2026-10-18.md`. Hasil komit CI `web/index.pck` adalah output ekspor, bukan perubahan kode tangan.
- Alur Explore/HUD, FX muzzle/impact, dan dress FBX pada komit terdahulu juga diuji di sini; rincian awal serta acuan dari game live ada di `docs/REBASE_VISUAL_GAMEPLAY_2026-10-18.md`.

## 5. Godot integration

`VisualRoot` mempertahankan path `WeaponSocket/Muzzle` untuk semua tiga `WeaponDefinition`. Shot riil memanggil `try_fire` dari marker pada GLB; muzzle flash, tracer, impact diikat ke event shot. Controller menolak shot sebelum menghabiskan ammo jika jalur dada→muzzle menabrak collider world, agar laras yang masuk cover tidak bisa menembak menembus dinding; smoke baru masih menunggu CI. Komposit aim berjalan saat movement melewati ambang walk/run, dengan blend socket yang sama untuk `aim`, `fire`, `reload`, dan `hit`. Sinyal `ammo_changed` memulai/mengakhiri reload; hit dan death dikendalikan health, reset membatalkan action. Loop berjalan eksplisit; hit/reload/death one-shot. `main.gd` memulai di Explore aman, bukan Defense otomatis; tombol B/START DEFENSE memasuki Preparing 5 detik, lalu Wave 01. Dunia memakai FBX unggahan untuk art modular, sementara physics, struktur fondasi, dan sebagian detail masih prosedural.

## 6. Test evidence (expected → observed)

| Gate | Hasil yang diharapkan → teramati | Status dan sumber |
|---|---|---|
| Blender inspect/bake, Godot import | `.blend` terisi, GLB 10 clip/79 bone, import + smoke tanpa parse error. | **VERIFIED PASS**: CI `39097331626` membake source `2aee8eb` dan job Blender memverifikasi impor Godot; bot menghasilkan GLB `a6a08e9`. Rig smoke tambahan terkait pose samping masih menunggu CI berikutnya. |
| Godot headless | Rig, muzzle, reload/hit/death, world FBX, safe Explore, UI dan wave contract lulus. | **VERIFIED PASS 17/17** pada `d2c84f0`, CI `39102421652` (Godot 4.7.2): guard muzzle-cover, impact Pulse/Nova/Arc, countdown, dan side-fall saat mixer maju dalam frame berjalan. **CI `39102619493` pada `6caa252` juga lulus 17/17** termasuk tes tulang kaki aim-walk/run; sebelumnya hasil `d2c84f0` belum mencakup asersi stride ini. |
| WASM Explore/Preparing | Boot tiga viewport tanpa error/4xx; tidak ada enemy sebelum opt-in, tombol B membuka telegraph. | **VERIFIED PASS 3/3** pada payload `15acb46` (mengandung GLB side-fall + combat `8104b78`), `exports/qa-cac-prep/`: 1280×720, 390×844, 844×390. Browser Chromium/WebGL2; safe Explore → Preparing, **tidak** mengklaim Defense dari gate ini. |
| WASM Defense | Setelah B dan countdown, HUD `WAVE 01`, log `Encounter: Defense started`. | **VERIFIED PASS 1/1** pada payload `15acb46`, 844×390: `exports/qa-cac-defense/root-844x390-defense-started.png`, stdout QA strict (`122,8 s`). Enemy `0 ACTIVE` di frame pertama; belum membuktikan Results atau gelombang selesai. |
| A/B luminance viewport 1280×720 | Pencahayaan menjaga midtones sambil mengurangi washout. | **VERIFIED MEASURED, visual gate belum diterima**: crop tengah baseline lama median Y≈159, relight awal ≈24 (terlalu gelap), relight `d8f834b` ≈138, >240Y hanya 1,1% vs baseline 16,9%; gambar `exports/qa-relight-d8f/root-1280x720-explore-idle.png` masih terlihat terlalu rata/biru. Payload `15acb46` sudah direview: crop tengah screenshot desktop dengan ROI x=28–68%, y=30–70% memiliki median Y≈112 dan >240Y≈1,6% (ROI **berbeda** dari baseline, jangan bandingkan angka median secara langsung). Reactor masih memancarkan bidang cyan/putih sangat luas dan ground terasa rata/biru; gate estetika **belum lulus**. |
| Gameplay visual: tembak/reload/hit/death, Results | Gerak dan efek tampak tepat dari beberapa sudut; wave dapat diselesaikan ke Results. | **UNKNOWN di WASM versi final**; Godot smoke memverifikasi state/trigger saja. Tidak boleh ditandai PASS visual. |
| Android perangkat fisik | Gameplay mobile dan renderer `mobile` cocok. | **UNKNOWN, belum diuji**, SDK/perangkat sengaja ditunda sampai UI/UX diterima. |

## 7. Known limitations / jangan disembunyikan

1. Rifle satu mesh/marker, tanpa magazine lepas atau finger/charging mechanism. Tiga senjata secara gameplay berbeda, tetapi **memakai model senapan yang sama**; presentasi unik masing-masing belum tuntas.
2. Frame death `a6a08e9` berbaring menyamping dengan kepala/dek berjarak wajar dan kaki tidak masuk lantai, tetapi senapan tetap di tangan dan agak terangkat. Reload hanya cue handling, tidak ada magazine/bolt teranimasi. Render Three.js serta assert tulang tidak menggantikan motion review video gameplay Godot atau persetujuan visual pengguna.
3. Masih ada terrain, fondasi, bagian reactor, collision dan detail prosedural. Perimeter/bay/district/pylon memakai GLB FBX, KayKit tidak dipakai. Klaim “semua world 100% FBX” salah.
4. Web Compatibility/SwiftShader berbeda dari Android Mobile; screenshot WS tidak membuktikan performa HP. Hasil/Results browser dan QA Android nyata belum ada.
5. Persetujuan direction referensi hanya untuk arah desain; belum ada sign-off visual oleh pengguna pada frame akhir.

## 8. Highest-priority next action

Jalankan smoke Godot terhadap perubahan combat/HUD/rig terbaru; ekspor WASM **setelah** commit GLB `a6a08e9` (web CI dari `2aee8eb` bisa memuat GLB lama); ulangi QA tiga viewport Explore/Preparing/Defense, tinjau pencahayaan dan pose dalam runtime. Results, Android nyata, dan penerimaan artistik oleh manusia tetap gate terpisah. Jangan merge PR #1.
