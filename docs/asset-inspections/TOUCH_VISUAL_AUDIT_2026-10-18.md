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
