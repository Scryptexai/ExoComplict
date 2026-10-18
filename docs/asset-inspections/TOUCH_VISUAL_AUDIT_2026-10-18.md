# Touch HUD: audit gambar sebelum revisi (18 Okt 2026)

**Bukan sign-off.** Pengguna benar: tes alur `OK` tidak mengukur keterbacaan ikon atau kualitas visual. Acuan *sebelum* adalah screenshot WebGL sungguhan [`qa-frames/touch-before-stage21.png`](qa-frames/touch-before-stage21.png), 390×844, disalin dari `exports/qa-wave-clear/00-explore.png` pada payload `73033ea`, bukan nilai ukuran yang tertulis di GDScript. Folder `exports/` di-ignore; simpan screenshot hasil revisi ke `qa-frames/`.

## Lihat layar, bukan konstanta

Pada gambar Explore tersebut, disk FIRE sekitar **112×112 piksel** tetapi siluet pistol/flash tampak hanya **43×32 piksel** (bbox warna amber di tengah disk). ADS **28×28 piksel**, dan ikon senjata **32×18 piksel**. Pengukuran memakai ImageMagick: crop bagian tengah masing-masing tombol, seleksi warna ikon dengan fuzz 13%, buang piksel lain, lalu `-trim -format '%wx%h%O'`; batas warna anti-alias/kompresi bisa bergeser ±2 piksel. Jadi FIRE hanya mengisi ~38% lebar dan ~29% tinggi target. Pembesaran 6× `tools/.cache/fire-before-zoom.png`, `aim-before-zoom.png`, `weapon-before-zoom.png` memperlihatkan banyak ruang hitam serta garis-garis tipis yang kalah oleh lingkungan. `icon_max_width=48`/`31`/`36` memang batas maksimum **tekstur**, bukan ukuran bentuk berwarna yang terlihat. Tombol juga transparan sehingga garis dunia menembus wajah kontrol. Ini kegagalan desain nyata, bukan soal tester salah menekan.

Atas layar: chip browser dari root `index.html` bisa menutup ~60 piksel pertama ketika baru boot, disusul health, panel objektif selebar hampir seluruh viewport, START DEFENSE dan ARMORY. Pada 390×844, ini mengambil banyak ruang dunia sebelum mata menemukan reaktor. Jangan menyembunyikan masalah ini di crop hanya tombol.

## Acuan game yang sudah dirilis

- [Warframe Mobile: Touch Control Guide](https://support.warframe.com/hc/en-us/articles/32633646081421-Warframe-Mobile-Touch-Control-Guide): gerak kiri, kamera kanan, Shoot tap/hold, Aim dan ability terpisah, kontrol yang kontekstual. Panduan ini mengutamakan tindakan yang jelas, bukan ikon mikro di dalam piringan besar.
- [Warframe iOS update 38.5](https://www.warframe.com/en/patch-notes/ios/38-5-0): ADS dipindah ke kanan dan posisi virtual button dapat disesuaikan; perubahan layout adalah produk iterasi, bukan sesuatu yang otomatis benar untuk setiap layar.
- [Review gameplay Warframe iOS, TouchArcade 2024](https://toucharcade.com/2024/03/06/warframe-ios-review-mobile-60fps-cross-save-iphone-15-pro-controller-support-ipad-gameplay/) menampilkan screenshot game terbitan, bukan mockup. Pada kelompok action kanan tampak siluet putih tegas di atas kontrol gelap. Artikel itu juga mengkritik beberapa target sentuh default yang terlalu kecil dan menyebut penyesuaian ukuran/transparansi; **jangan** mengklaim Warframe sempurna. Pratinjau gambar 500×231 sudah diperkecil sehingga tidak boleh dijadikan ukuran piksel untuk game ini.

Arah yang sudah dipilih pengguna tetap **Warframe Mobile untuk pemisahan input**, **Destiny 2 untuk hirarki objektif/ammo**, dan **Explore aman→Defense disengaja**. Jangan menyalin ikon/aset Warframe; gunakan SVG asli proyek. Target revisi: FIRE tetap satu aksi primer, glyph terang mengisi ~60–70% lebar kontrol (bukan 38%), ADS/skill/swap juga dominan; diameter target memadai dengan sela antartombol; latar kontrol lebih opak dan stroke yang tetap tampak di lantai terang/gelap; tidak menutup hero atau garis bidik. Root browser toolbar langsung meringkas sesudah boot; bantuan tetap dapat dibuka lewat `UI`.

## Gerbang visual setelah revisi

1. Ekspor **kode yang baru**, bukan screenshot build sebelumnya. Ambil screenshot browser **asli** portrait 390×844 dan landscape 844×390, dengan tampilan Explore, ADS, FIRE ditahan, dan setidaknya satu kondisi Defense. Baca gambar utuh dan crop tombol pada perbesaran 4–6×; ukur glyph berwarna terhadap diameter tombol dengan pixel, lalu revisi bila masih tampak kecil. Test input hanya mengecek aksi, bukan estetika.
2. Sertakan foto permainan yang menunjukkan bentuk khas *unggahan FBX* (lantai modul, rib/pylon, console/wall), bukan pernyataan bahwa path GLB terpasang. Cocokkan silhouette di capture gameplay dengan inspeksi model/katalog dan beri label apa yang terlihat; jika bentuk tidak dapat dikenali atau pencahayaan membuatnya hilang, catat sebagai masalah terbuka, jangan klaim bukti selesai.
3. Jangan menyebut AAA, FPS fisik, performa atau kenyamanan perangkat Android: screenshot WebGL/SwiftShader statis tidak bisa memverifikasi itu. PR #1 tetap OPEN.

## Setelah iterasi pertama: capture WebGL sebenarnya

Source `e2d9708`, payload `8090205`, CI `39143577540` **19/19 Godot smoke + ekspor Web**, tetapi tabel di bawah dihitung dari **piksel gambar**, bukan dari hasil CI. Ambil screenshot setelah boot pada root `index.html` (Chromium WebGL 2) dan pada aksi sentuh nyata:

- [Explore portrait 390×844](qa-frames/touch-after-stage21-portrait.png) · [landscape 844×390](qa-frames/touch-after-stage21-landscape.png) · [desktop 1280×720](qa-frames/touch-after-stage21-desktop.png).
- [ADS sedang ditahan](qa-frames/touch-after-stage21-ads-held.png) · [FIRE sedang ditahan](qa-frames/touch-after-stage21-fire-held.png) pada halaman root baru. Kamera dan hero benar-benar berubah di capture; ammo Pulse 24→22 pada FIRE. Frame ini **tidak** memperlihatkan muzzle flash yang jelas; jangan klaim VFX tembak sudah bagus.

Ukuran di bawah = bounding box piksel ikon berwarna, pada crop pusat target yang mengecualikan ring (ambang warna asli + radius yang memotong bezel). Toleransi anti-alias/sampling sekitar ±2 px; lihat gambar bila angka diragukan.

| Kontrol portrait | Sebelum (`touch-before-stage21.png`) | Sesudah (`touch-after-stage21-portrait.png`) | Target sesudah |
|---|---:|---:|---:|
| FIRE / gun + flash | **43×32 px** | **78×59 px** | 120×120 px |
| ADS / optic | 28×28 px | **50×50 px** | 80×80 px |
| EMP / pulse | 31×24 px | **56×42 px** | 80×80 px |
| Weapon / rifle | 32×18 px | **54×29 px** | 76×72 px |

FIRE kini mengisi **65% lebar**, **49% tinggi** bidang sentuh (sebelumnya 38%/29%). Tampilan setelah diperiksa langsung: ikon memang jauh lebih terbaca, bukan sekadar `icon_max_width` lebih besar. Panel atas diringkas: toolbar browser dilipat sejak boot, objective menjadi 270×56, START dan ARMORY berbagi satu baris, sehingga bagian depan dunia tidak lagi tertutup sampai ~y342 (akhir baris aksi kini ~y226). Bidang tombol kurang transparan dan rim lebih tegas. Bentuk rifle Weapon tetap relatif pendek secara vertikal; UI masih stylized/low-poly dan belum ada persetujuan estetika pengguna.

**World bukan klaim otomatis:** tur F10 pada build yang sama di 1280×720 memperlihatkan lantai, gerbang, pylon dan distrik di dalam game, tetapi satu citra diam tidak bisa memastikan mana model FBX dan mana prosedural. Karena itu tahap berikutnya merekam A/B kamera yang sama dengan visual impor ON/OFF; lihat bagian di bawah.

## Stage 22: pembuktian asset FBX di dunia yang benar-benar dirender

Source `db0e483`, payload `4fab8da`, CI `39144895197` sukses (Godot 19/19, static, ekspor Web). **Bukti di sini adalah gambar permainan, bukan hasil test.** Dalam build WebGL root yang sama, F10 mengaktifkan kamera review dan membekukan simulasi; tombol 1 memilih arena atau 4 memilih extraction; F9 hanya membalik visibility root dari instance GLB konversi *FBX unggahan* (grup `uploaded_fbx_visual`, **310 instance**), sementara kamera, objek prosedural, pencahayaan dan collision tidak diganti. Tombol F9 kedua mengembalikan semuanya; keluar tur juga selalu memulihkan semuanya.

| Sudut kamera dalam build game | FBX impor terlihat (normal) | FBX impor disembunyikan sementara |
|---|---|---|
| Arena, F10→1 | [arena ON](qa-frames/fbx-arena-on-stage22.png) | [arena OFF](qa-frames/fbx-arena-off-stage22.png) |
| Extraction, F10→4 | [extraction ON](qa-frames/fbx-extraction-on-stage22.png) | [extraction OFF](qa-frames/fbx-extraction-off-stage22.png) |

**Baca gambar:** pada arena ON, panel lantai modul abu-abu dengan seam, cladding/pilar berlubang di tepi depan, bukaan gerbang kanan dan beberapa servis hilang pada OFF. Deck dasar biru, reaktor tengah, menara silinder, terrain dan sebagian bangunan **masih ada** pada OFF—itu bagian prosedural, jadi klaim “seluruh dunia 100% FBX” tidak benar. Pada extraction ON, rib/strut berlubang di tepi perimeter dan service wall/pipes kanan terlihat; pada OFF menghilang sementara tiga coil reaktor, lampu dan bentang tanah tetap ada. Screenshot `arena ON` dan setelah F9 kedua **byte-identical**; A/B ON→OFF mengubah 253.628 piksel dari 1280×720 (jangan menafsirkan itu sebagai persentase geometri). Kedua frame diambil dari aplikasi Godot WebAssembly, bukan dari mockup atau model viewer.

[Referensi bentuk source Column_01_Big](qa-frames/fbx-column-source-stage22.png) dan [DoorWay_01_Large](qa-frames/fbx-doorway-source-stage22.png) dirender **terpisah** dari GLB hasil konversi untuk mengenali lubang/cutout dan profil bukaan. Gambar model-only ini **bukan** bukti gameplay; perbandingan ON/OFF di atas adalah buktinya. Material GLB sumber banyak yang polos, sehingga world yang terlihat masih datar dan porsi blok prosedural besar. Relight/art direction, efek muzzle yang tampak jelas, dan kualitas animasi di gerak nyata tetap **belum lulus gate visual**.
