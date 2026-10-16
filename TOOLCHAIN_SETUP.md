# Project Overdrive — Toolchain & Setup

> Dokumen pendamping [`DEVELOPMENT_ROADMAP.md`](DEVELOPMENT_ROADMAP.md). Engine baseline sementara dipin ke **Godot 4.7.2-stable** (`.godot-version`); pasang versi tersebut beserta export templates yang cocok sebelum membuka project.

## 1. Status workspace saat ini

Pemeriksaan diperbarui pada **16 Oktober 2026**. **VERIFIED:** source Godot 4.7.2 dibangun dengan SCons sebagai Linux `template_debug` headless (`4.7.2.stable.custom_build`) yang mendukung `--path` dan `--script`. Build ini mencakup GDScript, Godot Physics 3D, TextServerAdvanced, dan FreeType; build ini bukan Editor, tidak menyertakan Physics2D, dan tidak memiliki driver grafis Vulkan/OpenGL. Main scene berjalan selama 120 iterasi dengan exit code 0 tanpa warning/error. Sembilan smoke test dijalankan langsung pada project `game/` secara berurutan dan lulus: delapan test dunia/combat yang sudah ada serta `playability_hud_smoke` untuk HUD, touch movement/aim/fire, weapon switching, pause-clears-touch, dan retry. World smoke mengukur 2.545 `MeshInstance3D` dan 138 `StaticBody3D`; pemain menempuh rute central-to-boss hingga z=-49.08, naik ke boss platform hingga z=-64.08 (y=0.29), dan melewati ramp landing pad hingga x=39.10 (y=0.17). Satu warning “No valid spawn point” pada Wave Director adalah skenario negatif yang memang diharapkan test; tidak ada `SCRIPT ERROR`/`ERROR` pada rangkaian test. `gdformat`, lint GDScript, dan `git diff --check` lulus. Cache global class dibuat lokal di `game/.godot/` untuk runtime editorless dan tidak di-commit. **UNKNOWN / belum diverifikasi:** tampilan visual pada renderer nyata, performa mobile, import lewat full Editor, Android export/deployment, dan uji perangkat fisik. GUI bukan syarat workflow; yang belum tersedia di sandbox ialah full headless Editor CLI/export templates, SDK/JDK, native Blender CLI, dan perangkat uji. Wheel `bpy==4.5.14` dari PyPI sudah diuji lagi; import tetap terhenti karena shared libraries Linux (`libXrender`, `libXfixes`, `libXi`, `libxkbcommon`, `libSM`, `libICE`, `libGL`) tidak tersedia. Blender tidak diperlukan untuk geometri prosedural blockout, tetapi tetap dibutuhkan untuk rig/animasi GLB sesuai `ANIMATION_CHARACTER.txt`.

| Tool | Status di sandbox ini | Perlu untuk |
|---|---|---|
| Git | Tersedia | Version control dan perubahan dokumen/kode |
| Python 3 | Tersedia | Helper/otomasi opsional |
| Godot 4.7.2-stable | **VERIFIED:** source-built Linux headless `template_debug` (`4.7.2.stable.custom_build`) with GDScript, 3D physics, TextServerAdvanced, FreeType, and working `--path`/`--script`; main-scene startup and all nine smoke tests pass, including the new touch/HUD slice test. World smoke: 2,545 meshes / 138 static bodies, including central-to-boss and landing-pad traversal. Not an Editor build; Physics2D and Vulkan/OpenGL graphics drivers are disabled. Full Editor CLI, visual rendering, Android export templates, and device tests are not verified/available here. | Runtime/scene test via CLI; full headless Editor CLI for import project and Android export |
| Blender | Native `blender` CLI belum ditemukan. Alternatif resmi `bpy==4.5.14` dari PyPI sudah dipasang dan diuji sebagai modul headless, tetapi import berhenti karena runtime system libraries `libXrender`, `libXfixes`, `libXi`, `libxkbcommon`, `libSM`, `libICE`, dan `libGL` tidak tersedia; wheel bukan executable CLI. Fork WASM browser belum tervalidasi sebagai pipeline asset CLI. | Pembuatan model/animasi dan ekspor GLB lewat `blender --background --python ...` atau modul `bpy` setelah dependency native tersedia |
| Java/JDK | Tidak ditemukan | Android build/export sesuai kebutuhan Godot |
| Android SDK / ADB | Tidak ditemukan | Export, instalasi, dan debug di Android |
| Git LFS | Tidak ditemukan | Disarankan saat file aset biner besar masuk |
| Android device | Tidak tersedia di sandbox | Uji kontrol sentuh, renderer, dan performa nyata |

Workspace ini Linux headless dan tidak menyediakan binary full Editor Godot, executable Blender native, SDK Android, atau perangkat fisik. **GUI bukan prasyarat**: Godot dapat di-import/dijalankan dengan `--headless`, Blender dapat dijalankan dengan `--background`, dan SDK Android dikelola lewat command-line tools. Jangan menaruh binary, SDK, cache import, atau hasil build di repository; perangkat nyata tetap diperlukan untuk menguji sentuh, renderer, dan performa.

## 2. Tool yang dibutuhkan

### Wajib sebelum membuat Android build (Phase 0)

1. **Godot Engine 4.7.2-stable — Standard build (bukan .NET).** Ini pin awal berdasarkan rilis stabil terbaru yang terlihat di GitHub pada 14 Oktober 2026; jangan memperbarui di tengah milestone tanpa alasan teknis. Bahasa proyek: GDScript. Pasang **export templates** yang persis cocok dengan versi editor. Jika mesin development memakai versi lain, pin project dan sesuaikan `PROJECT_DECISIONS.md` bersama export templates.
   - Unduh: [Godot downloads](https://godotengine.org/download/)
   - Panduan ekspor Android: [Godot — Exporting for Android](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html)
   - Renderer: bandingkan Mobile dengan Compatibility di perangkat sasaran; keputusan tidak dibuat dari spesifikasi editor saja.

2. **Android Studio + Android SDK.** Android Studio dipakai untuk memasang/mengelola command-line tools, platform-tools, SDK platform dan build-tools yang diminta dokumentasi Godot versi terpilih. Tidak harus dipakai sebagai IDE game.
   - Unduh: [Android Studio](https://developer.android.com/studio)
   - Pasang Android SDK Command-line Tools, Platform-tools (termasuk `adb`), SDK platform dan build-tools yang kompatibel dengan requirement Godot/Google Play saat setup.
   - Versi Android API berubah dari waktu ke waktu; jangan menyalin angka API lama dari tutorial tanpa memeriksa requirement saat rilis.

3. **JDK/OpenJDK yang cocok dengan versi Godot yang dipin.** Beberapa alur Godot 4 memakai JDK 17, tetapi gunakan nilai dari dokumentasi resmi **versi Godot yang benar-benar dipilih**. Pastikan Godot menunjuk ke JDK dan Android SDK yang sama dengan yang diuji di terminal.

4. **Perangkat Android nyata untuk smoke test.** Sediakan minimal satu perangkat kelas rendah/menengah sebagai baseline; perangkat kedua dengan spesifikasi berbeda sangat disarankan. Aktifkan USB debugging hanya untuk perangkat development dan cabut akses debug yang tidak digunakan. Emulator dapat membantu UI/export smoke test, tetapi tidak menggantikan pengujian performa sentuh/GPU pada perangkat nyata.

5. **Git.** Commit kecil per milestone. File kredensial/signing tidak pernah masuk commit.

### Wajib sebelum produksi aset final

6. **Blender CLI.** Gunakan rilis stabil yang menyediakan executable `blender`; GUI tidak diperlukan untuk otomasi aset. Simpan `.blend` sebagai sumber editable dan ekspor aset runtime sebagai `.glb` (glTF 2.0). Uji skala, orientasi, material, rig, dan animasi melalui satu aset kecil sebelum membuat seluruh roster.
   - Unduh: [Blender downloads](https://www.blender.org/download/)
   - Mode background: `blender --background --python scripts/create_asset.py` (skrip dapat menyimpan `.blend` dan mengekspor GLB).
   - Simpan sumber Blender terpisah dari aset runtime agar tidak bergantung pada konversi otomatis/import Blender di mesin setiap programmer.

7. **Git LFS — direkomendasikan saat aset biner besar mulai masuk.** Gunakan kebijakan repository untuk `.blend`, tekstur, audio master, dan file aset besar; jangan memasukkan cache Godot atau build ke LFS. Tinjau kuota/penyimpanan repository sebelum mengaktifkan untuk semua jenis file.

### Pendukung opsional yang disarankan

| Kebutuhan | Pilihan contoh | Catatan |
|---|---|---|
| Tekstur, ikon, konsep 2D | Krita atau GIMP; Inkscape untuk vektor | Pilih tool yang sudah dikuasai tim. Pastikan aset sumber serta lisensinya tercatat. |
| Rekam/edit efek suara | Audacity; DAW pilihan tim untuk produksi | Godot dapat memakai format audio umum; ekspor aset final dalam format yang diuji di Android. Simpan sumber dan bukti lisensi. |
| UI/prototype | Godot Control nodes; Figma/Penpot opsional | Jangan membuat design system besar sebelum HUD dan alur menu diuji. |
| Log/performance Android | Godot Profiler + `adb logcat` | Dipakai pada build device, bukan hanya editor. |
| GDScript static lint | `gdtoolkit` (pin di `requirements-dev.txt`) | Jalankan `./scripts/lint_gdscript.sh`; ini memeriksa grammar/style, bukan API/runtime Godot. |
| Unit/scene tests | Test scene dan script project; plugin test opsional | Jangan menambah plugin pihak ketiga sebelum kebutuhan, lisensi, dan kompatibilitas versi diperiksa. |
| Tracking tugas | GitHub Issues/Projects atau papan tim yang sudah dipakai | Tidak perlu layanan baru untuk memulai. Catat milestone dan bug yang dapat direproduksi. |

### Ditunda sampai monetisasi disetujui

Jangan pasang SDK iklan, plugin IAP, Google Play Billing wrapper, atau masukkan ID produk ke build MVP. Setelah core game dan audiens/usia ditetapkan, pilih plugin yang kompatibel dengan Godot yang dipin, periksa kebijakan platform/privasi, lalu buat produk uji di Google Play Console. Untuk game yang mungkin ditujukan kepada anak, lakukan review kebijakan keluarga/iklan dan data terlebih dahulu.

## 3. Urutan setup mesin development

1. **Pasang Git dan buat/clone repository.** Pastikan branch kerja adalah `arena/9f883711-cyber-strike`; jangan commit file export, cache, build, atau credential.
2. **Siapkan Godot Standard 4.7.2-stable CLI Editor build dan export templates yang versinya sama.** Impor proyek tanpa GUI dengan `godot --headless --editor --path game --quit`; catat versi lengkap dan ubah pin di catatan proyek hanya bila perlu.
3. **Pasang Android Studio dan paket SDK yang cocok.** Catat jalur SDK, versi JDK, platform-tools, SDK platform, serta build-tools yang dipakai.
4. **Set environment untuk terminal/engine.** Pilih `ANDROID_SDK_ROOT` (atau `ANDROID_HOME` jika tooling lama memerlukannya), `JAVA_HOME`, serta masukkan `platform-tools` ke `PATH`. Jangan simpan jalur komputer lokal di file yang dibagikan atau `local.properties` yang di-commit.
5. **Siapkan Blender CLI.** Catat versi; gunakan `blender --background --python <script.py>` untuk membuat scene, menyimpan `.blend`, dan mengekspor GLB. Lalu impor GLB lewat Godot headless Editor CLI dan bandingkan orientasi serta skala.
6. **Siapkan perangkat Android.** Pasang debug build, jalankan, periksa input sentuh, orientasi layar, log crash, dan kemampuan kembali dari pause/background.
7. **Pasang Git LFS sebelum aset besar ditambahkan**, bila ukuran/kuota proyek memerlukannya. Buat aturan tracking dengan persetujuan tim; file `.blend` dan GLB adalah source/runtime assets penting dan tidak boleh dibuang sebagai cache.
8. Jalankan pemeriksaan lokal:

   ```bash
   ./scripts/check_toolchain.sh
   ```

   Script memberi `FAIL` untuk tool yang dibutuhkan Phase 0 namun belum ditemukan, dan `WARN` untuk tool/aset yang baru diperlukan pada fase berikutnya. Script tidak mengunduh atau mengubah versi tool.

   Static lint GDScript (opsional; tidak menggantikan pemeriksaan di Godot):

   ```bash
   python3 -m venv .venv
   .venv/bin/pip install -r requirements-dev.txt
   ./scripts/lint_gdscript.sh
   ```

   Impor project dan jalankan smoke test tanpa GUI:

   ```bash
   godot --headless --editor --path game --quit
   godot --headless --path game --quit-after 120
   godot --headless --path game --script res://tests/neon_frontier_world_smoke.gd
   godot --headless --path game --script res://tests/weapon_system_smoke.gd
   godot --headless --path game --script res://tests/arc_weapon_smoke.gd
   godot --headless --path game --script res://tests/combat_feedback_smoke.gd
   godot --headless --path game --script res://tests/wave_director_smoke.gd
   godot --headless --path game --script res://tests/arena_blockout_smoke.gd
   godot --headless --path game --script res://tests/reward_loop_smoke.gd
   godot --headless --path game --script res://tests/shooter_enemy_smoke.gd
   ```

   Delapan smoke test memeriksa world 3D modular (mesh/collider count, komponen, floor berkelanjutan, rute central-to-boss dan dua ramp), definisi/switching senjata desktop-touch, cooldown, Pulse hit dan blocker, Nova direct/splash/radius, Arc target selection/chain/line-of-sight/cap/falloff, projectile/target, damage pemain dan feedback, pause/fire sentuh, Results/retry, Shooter ranged hit, cover-blocking dan dodge windup, mixed-wave schedule, spawn cap/validasi posisi, progres/intermission, game over, gerak Runner, reward idempotent untuk kedua archetype, run timer, HUD, dan angka Results.

9. Project Godot sudah berada di `game/`. Uji melalui CLI: headless Editor import tanpa parser error, template Android tersedia, export debug berhasil, APK dipasang/launch via `adb`, dan satu GLB tampil di scene. UI GUI bersifat opsional; perangkat Android nyata tetap diperlukan untuk uji sentuh/performa.

### Environment variable (contoh, bukan path universal)

Atur melalui konfigurasi mesin development—bukan commit repository. Linux/macOS biasanya dapat memakai bentuk berikut setelah menemukan lokasi SDK/JDK yang benar:

```bash
export ANDROID_SDK_ROOT="/path/to/Android/Sdk"
export ANDROID_HOME="$ANDROID_SDK_ROOT" # opsional untuk tool yang masih membaca alias ini
export JAVA_HOME="/path/to/compatible/jdk"
export PATH="$ANDROID_SDK_ROOT/platform-tools:$PATH"
```

Pada Windows, atur `ANDROID_SDK_ROOT`, `JAVA_HOME`, dan `PATH` dari Environment Variables; path serta aturan akses USB berbeda menurut versi Windows dan produsen perangkat. Di Godot, pilih path SDK/JDK/export templates pada Editor Settings sesuai panduan resmi versi yang dipasang. Hindari menyimpan password signing di environment bersama, repository, log, atau screenshot.

## 4. Konvensi asset pipeline

Struktur yang disarankan untuk memisahkan file sumber DCC dari file yang dibaca game:

```text
art_source/
  blender/                 # .blend editable, file kerja dan referensi berlisensi
  audio/                   # sesi/master audio jika diperlukan

game/                      # project Godot; project.godot berada di sini
  scenes/
  scripts/
  data/
    weapons/
    enemies/
    waves/
  assets/                  # aset runtime yang diimpor Godot
    characters/
    weapons/
    enemies/
    environment/
    vfx/
    audio/
  tests/
```

Struktur ini menjaga file `.blend` besar/kerja di luar `res://` dan memberi jalur ekspor yang eksplisit. Jika tim memilih meletakkan `project.godot` di root, jangan biarkan cache hasil export berada di folder yang di-import Godot. Struktur akhir boleh menyesuaikan setelah project dibuat; jangan membuat direktori kosong massal hanya untuk mencocokkan diagram.

Konvensi awal:

- Nama file dan node konsisten, tanpa karakter khusus/spasi yang menghambat script/build; identifier senjata/musuh stabil.
- Unit Blender memakai meter; tetapkan orientasi, origin/pivot, skala, material, dan naming animasi ketika aset pertama divalidasi.
- GLB adalah runtime interchange; simpan `.blend` dan sumber tekstur terpisah.
- Tidak ada polygon/texture budget final sampai device baseline diprofilkan. Gunakan jumlah material, ukuran texture, transparansi dan bayangan secukupnya.
- Catat sumber, lisensi, atribusi, versi, dan hak penggunaan setiap aset pihak ketiga pada asset register proyek sebelum rilis.

## 5. Kebersihan repository dan keamanan

- Jangan commit `.godot/`, file sementara import/build/export, `build/`, hasil APK/AAB, log lokal, atau cache Blender.
- Pertahankan file sumber `.blend`, GLB final, texture/audio yang memang digunakan dan asset register. Gunakan LFS bila disepakati.
- Jangan commit Android keystore, JKS, password, service-account key, token, credential, atau file `.env` lokal.
- Simpan signing key terenkripsi dengan akses terbatas dan backup aman; rencanakan proses rotasi/restore di luar repository.
- Ekspor debug untuk development; pisahkan signing/release config dari debug. Periksa file export preset sebelum commit karena dapat memuat path atau rahasia lokal.
- IAP/ads tidak menjadi dependensi combat. Build offline tetap harus dapat memainkan loop single-player.

## 6. Checklist siap mulai Phase 0

- [ ] Satu versi Godot 4.x stabil dipilih dan dicatat.
- [ ] Export templates cocok dengan versi Godot tersebut.
- [ ] JDK/Android SDK cocok menurut dokumentasi Godot dan terdeteksi editor/terminal.
- [ ] Android build debug dapat diekspor, dipasang, dan dibuka di perangkat baseline.
- [ ] Blender dapat mengekspor GLB yang tampil benar di Godot.
- [ ] Renderer, orientasi, perangkat baseline, dan roster tiga senjata dicatat sebagai keputusan awal.
- [ ] `.gitignore` menutup cache, export, dan credential tanpa membuang source asset.
- [ ] Kebijakan lisensi aset dan lokasi penyimpanan file biner disepakati.
- [ ] Belum ada SDK iklan/IAP atau fitur networking yang masuk ke MVP.

## 7. Referensi resmi

- [Godot Engine — Downloads](https://godotengine.org/download/)
- [Godot Docs — Exporting for Android](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html)
- [Godot Docs — Importing 3D scenes / glTF](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/index.html)
- [Blender — Downloads](https://www.blender.org/download/)
- [Android Studio](https://developer.android.com/studio)
- [Git LFS](https://git-lfs.com/)
