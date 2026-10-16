# Project Overdrive — WebAssembly Preview

> **Tujuan:** melihat dan menguji game di browser **tanpa memasang Godot, Android SDK, JDK, atau Blender** — cukup satu server statis: `python -m http.server 800 --bind 0.0.0.0` dari root repo.
>
> **Ini bukan perubahan target platform.** Android tetap target rilis; pipeline produksi tetap Godot + Blender di mesin dev. Web hanya dipakai sebagai jendela review UI/UX + gameplay supaya iterasi tidak menunggu instalasi toolchain.
>
> **Status verifikasi:** seluruh wiring statis sudah diperiksa (`tools/web_preset.py check`, `tools/project_doctor.py` → 0 FAIL, 22 unit test). Ekspor Web nyata sudah dijalankan oleh job CI `web-preview` (run `38918903764`: job hijau, artefak `web-preview` ≈ 10 MB, pengiriman `index.wasm`/`index.pck` lewat `python -m http.server` terverifikasi). Artefaknya diunduh lalu diekstrak ke root repo; selama `web/` belum ada, landing page menampilkan instruksi, bukan game.

---

## 1. Alur singkat (pemakaian harian)

```bash
# 1. Ambil artefak "web-preview" dari GitHub Actions
#    Actions -> Godot CI -> run terbaru -> Artifacts -> web-preview
#    Ekstrak isinya ke ROOT repo ini sehingga muncul folder web/

# 2. Sajikan dari root repo
python -m http.server 800 --bind 0.0.0.0

# 3. Buka di browser
#    http://localhost:800/        <- landing page (embed game + status build)
#    http://localhost:800/web/    <- build Godot mentah (fullscreen-friendly)
#    http://<ip-perangkat>:800/   <- dari HP di jaringan yang sama
```

Tidak perlu header COOP/COEP, tidak perlu `--directory`, tidak perlu konfigurasi MIME: build yang dihasilkan memakai **single-thread** (`variant/thread_support=false`), dan Python 3.9+ sudah mengirim `.wasm` sebagai `application/wasm` (diverifikasi di sesi ini pada Python 3.11.2).

### Alternatif tanpa unduh sama sekali (GitHub Pages)

Artefak `web-preview` berukuran ~10 MB. Kalau kuota internet sedang mahal, pakai Pages:

1. Buka **Settings → Pages** di repo, pilih **Source: GitHub Actions** (sekali saja).
2. Jalankan workflow **Godot CI** lewat **Actions → Godot CI → Run workflow** (atau biarkan terpicu setelah perubahan masuk `main`).
3. Job `deploy-pages` akan mempublikasikan landing page + build ke URL Pages; URL-nya muncul di ringkasan run dan di environment `github-pages`.

Job `deploy-pages` sudah ada di workflow dan tidak berjalan pada push biasa ke branch sesi — hanya pada dispatch manual atau push ke `main`.

## 2. Kalau ingin membangun sendiri (butuh Godot 4.7.2 + export templates)

```bash
./scripts/install_godot.sh --with-templates   # pasang engine yang dipin
./scripts/export_web_preview.sh               # preset + import + export + verifikasi
python -m http.server 800 --bind 0.0.0.0
```

`scripts/export_web_preview.sh` melakukan lima langkah dan berhenti kalau ada yang gagal:

1. `tools/web_preset.py ensure` — menulis preset **Web** ke `game/export_presets.cfg` (git-ignored). Preset Android/desktop yang sudah ada di file itu tidak diubah.
2. `tools/web_preset.py check` — memvalidasi preset + custom HTML shell (placeholder lengkap, `<canvas>`, `<canvas>` bootstrap).
3. Import headless (`godot --headless --editor --path game --quit`).
4. `godot --headless --path game --export-release Web web/index.html`.
5. `tools/verify_web_build.py web` — memastikan `index.html`, `index.js`, `index.wasm`, `index.pck` ada, magic bytes benar (`\0asm`, `GDPC`), placeholder sudah diganti, dan custom shell benar-benar terpakai.

Opsi: `--debug` (build debug, error lebih jelas, ukuran lebih besar), `--output <dir>`, `--no-import`. Override `WEB_EXPORT_PRESET` atau `GODOT_BIN` bila perlu.

## 3. Yang dibangun di dalam

| Berkas | Peran |
|---|---|
| `index.html` (root repo) | Landing/preview page: deteksi keberadaan `web/index.html`, tombol **Mulai preview** (iframe), **Fullscreen**, **Muat ulang**, kartu kontrol, kartu troubleshooting, dan tautan ke GitHub Actions bila build belum ada. Tanpa CDN, tanpa build step. |
| `game/web_shell/index.html` | **Custom Godot HTML shell** (dipakai lewat `html/custom_html_shell`). Menambah boot overlay bertema (progress bar + persentase), HUD atas (chip build, Fullscreen, Hide UI), panel kontrol yang bisa dilipat, dan penanganan error yang menampilkan pesan gagal yang dapat dibaca. Placeholder `$GODOT_*` resmi dipertahankan. |
| `tools/web_preset.py` | `ensure` / `check` / `show` untuk preset Web (thread support, custom shell, resize policy, PWA off). |
| `scripts/export_web_preview.sh` | Pipeline ekspor web 5 langkah + verifikasi. |
| `tools/verify_web_build.py` | Verifikasi hasil ekspor tanpa browser (magic bytes, placeholder, ukuran). |
| `tools/tests/test_web_preview.py` | 13 unit test untuk preset + verifier (ikut `dev_check.sh` dan CI). |
| Job CI `web-preview` | Memasang Godot + template, mengekspor, menyajikan dengan `python -m http.server` dan memeriksa pengiriman `index.wasm`/`index.pck` lewat HTTP, lalu mengunggah artefak `web-preview` (berisi `web/` + `README.txt`). |

`web/` adalah **output**, bukan sumber: sudah di-`.gitignore`. Jangan commit isinya.

## 4. Pengaturan renderer

Godot hanya mendukung renderer **Compatibility (WebGL 2)** di platform web. `game/project.godot` sekarang menyatakan hal itu secara eksplisit:

```ini
renderer/rendering_method="mobile"
renderer/rendering_method.mobile="mobile"
renderer/rendering_method.web="gl_compatibility"
```

Artinya build Android tetap memakai renderer `mobile` (sesuai `PROJECT_DECISIONS.md`), sedangkan build web otomatis memakai Compatibility. `tools/project_doctor.py` memeriksa baris ini supaya tidak hilang tanpa sengaja.

## 5. Kontrol

| Aksi | Keyboard (desktop) | Sentuh (HP/tablet) |
|---|---|---|
| Bergerak | WASD | joystick ibu jari di sisi kiri |
| Membidik | tahan klik kanan + gerakkan mouse | geser di sisi kanan |
| Menembak | tahan klik kiri | tahan tombol FIRE |
| Ganti senjata | E atau tombol WEAPON | tombol WEAPON |
| Skill EMP | klik tombol EMP | tombol EMP |
| Pause / Resume | Esc | tombol PAUSE / RESUME |
| Reset run | R | tombol RETRY setelah defeat |

Tombol **HIDE UI** di shell hanya menyembunyikan lapisan HTML (chip/panel kontrol), bukan HUD di dalam game.

## 6. Batas yang harus diingat (jujur)

- **Renderer berbeda.** Web = Compatibility/WebGL 2; Android = Mobile renderer. Efek yang terlihat di web belum tentu identik (post-processing, bayangan, presisi emissive).
- **Performa tidak representatif.** FPS/frame time di browser adalah ukuran mesin Anda, bukan perangkat Android kelas menengah. Tabel profiling di `ANDROID_BASELINE.md` tetap wajib untuk gate E.
- **Single-thread.** Build ini tidak memakai `Thread` Godot; jangan menilai audio latency atau paralelisme dari preview.
- **Ukuran unduhan.** WebAssembly engine + pack biasanya beberapa puluh MB; muat pertama lambat, berikutnya ter-cache.
- **Bukan jalur distribusi.** Ini alat review. Publikasi tetap: Godot → GLB/PCK → Android (APK/AAB).
- **Belum diuji di browser sungguhan dari sandbox ini.** Yang sudah diuji: pembuatan preset, pengecekan shell, verifier build (dengan build tiruan), unit test, dan penyajian statis halaman landing. Job CI `web-preview` yang akan membuktikan ekspor + delivery nyata.

## 7. Troubleshooting

| Gejala | Sebab | Tindakan |
|---|---|---|
| Landing page: "build belum ada" | `web/` belum ada | Unduh artefak `web-preview` dari Actions, ekstrak ke root repo (harus jadi `web/index.html`), muat ulang |
| Layar hitam, progres macet | WebGL 2 tidak tersedia/terblokir | Gunakan Chrome/Firefox/Edge terbaru; cek `chrome://gpu`; hindari mode hemat data |
| Pesan "The following features ... are missing" | Browser tidak mendukung WebGL 2 atau canvas diblokir | Perbarui browser; pastikan bukan di iframe yang membatasi; jangan aktifkan thread support |
| `404` pada `index.wasm` / `index.pck` | Server dijalankan dari folder yang salah | Jalankan `python -m http.server 800` **dari root repo** (atau `--directory <web>`) |
| Export gagal: template tidak ditemukan | Export templates belum dipasang | `./scripts/install_godot.sh --with-templates` |
| `tools/web_preset.py check` gagal: threads | Preset memakai `variant/thread_support=true` | Jalankan `ensure` lagi (default single-thread), atau sajikan dengan header COOP/COEP dan pakai `--allow-threads` saat check |
| Ingin lihat error engine | Build rilis menyembunyikan detail | `./scripts/export_web_preview.sh --debug`, lalu cek konsol browser |

## 8. Jalur lanjutan ke Android

Setelah UI/UX dan kontrol dinilai sudah tepat di web:

1. Ikuti `ANDROID_BASELINE.md` (JDK/SDK, preset, APK, checklist perangkat, profiling).
2. Bandingkan renderer `mobile` vs `compatibility` di perangkat baseline sebelum mengunci pilihan di `PROJECT_DECISIONS.md` — preview web sudah memberi gambaran kasar bagaimana Compatibility terlihat.
3. Catat perbedaan perilaku yang ditemukan di web (mis. layout HUD di rasio layar tertentu) sebagai temuan yang harus diverifikasi ulang di perangkat.
