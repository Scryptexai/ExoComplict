# Audit visual ulang — bukan sertifikat UI

**19 Oktober 2026 · build WebGL `1cdda53` dari root `index.html`.** Koreksi pemain diterima: hasil `OK` dari skrip bukan penilaian desain. Tidak ada klaim bahwa ikon, world art, animasi atau efeknya sudah bagus. Jangan membaca angka bbox sebagai pembelaan desain.

## Foto yang diperiksa, sebelum perubahan berikutnya

- [Tiga foto canvas game dalam ukuran aslinya, diberi judul](qa-frames/touch-current-three-view-diagnosis.png): portrait **390×844**, landscape **844×390**, desktop **1280×720**. Foto diekspor dari browser yang menjalankan Godot WebAssembly di root, bukan mockup atau ukuran `icon_max_width` dari kode.
- Piksel putih aktual di dalam target (threshold tiap kanal >190, selisih kanal <70, margin 3 px; anti-alias ±2 px):

| Aksi | Portrait: glyph / target | Landscape: glyph / target |
|---|---:|---:|
| FIRE | **129×121 / 148×148 px** | **110×104 / 128×128 px** |
| ADS | 82×82 / 96×96 | 71×71 / 84×84 |
| EMP | 86×82 / 96×96 | 78×74 / 84×84 |
| WEAPON | 82×71 / 96×96 | 70×62 / 84×84 |

**Yang terlihat buruk di foto:** ikon FIRE dan WEAPON adalah *gambar rifle hampir identik*; kilat di ujung FIRE tidak cukup membedakan makna aksinya. Ukuran putihnya sudah besar tetapi bahasa bentuknya monoton/tampak seperti mainan, susunan empat pelat menyesakkan sisi kanan, dan teks/status tambahan masih menyita ruang dunia. Pada **desktop 1280×720 FIRE bahkan tidak muncul**: `DisplayServer.is_touchscreen_available()` mematikan seluruh tombol touch, hanya menyisakan petunjuk LMB kecil. Jadi foto mobile yang kami tunjukkan sebelumnya tidak mewakili preview desktop yang mungkin sedang dilihat pemain. **Ini bukan soal sekadar tambah `icon_max_width`.** Juga, saat hanya starter rifle tersedia, WEAPON membuka Armory (meski pictogram tampak seperti senjata aktif); ikon saat ini tidak menjelaskan hasil tap.

## Pembanding permainan yang sudah rilis, bukan ukuran yang direka

- [Warframe Mobile — panduan kontrol resmi](https://support.warframe.com/hc/en-us/articles/32633646081421-Warframe-Mobile-Touch-Control-Guide): Shoot ikon tersendiri, tekan/tahan; Aim terpisah; Cycle Weapon adalah widget senjata+ammo yang bermakna, tidak duplikat ikon Shoot; kemampuan terpisah dan tombol kontekstual hanya tampil jika relevan. Kami **tidak** mengaktifkan auto-fire Warframe, karena keputusan pemain adalah manual FIRE. Screenshot permainan Warframe Mobile yang sebelumnya disimpan dalam `tools/.cache/reference-warframe-controls-zoom.jpg` hanya 600×600 setelah pembesaran dan kompresi; ia menunjukkan pemisahan simbol terang/aksi, **tidak** sah untuk mengklaim ukuran piksel absolutnya terhadap layar kita.
- [Warframe iOS 38.5 release notes](https://www.warframe.com/en/patch-notes/ios/38-5-0): tata letak ADS kanan dapat diubah. [Ulasan Warframe iOS yang sudah live, TouchArcade](https://toucharcade.com/2024/03/06/warframe-ios-review-mobile-60fps-cross-save-iphone-15-pro-controller-support-ipad-gameplay/) bahkan mengkritik target touch bawaan yang kecil; ambil prinsip diferensiasi dan kontrol yang bisa diatur, bukan menyalin aset mereka.
- Arah pilihan pemain tetap **hirarki HUD Destiny 2** dan **kontrol Warframe**, bukan kloning desain visual berhak cipta. Keyakinan numerik tentang ergonomi ponsel fisik belum ada.

## Bukti FBX di permainan saat ini, apa yang benar-benar dibuktikan

- [Arena: FBX ON/OFF dari build WebGL saat ini](qa-frames/fbx-current-stage42-arena-on-off.png) dan [Extraction: FBX ON/OFF](qa-frames/fbx-current-stage42-extraction-on-off.png). Kamera, HUD, dan dunia prosedural tetap sama; F9 hanya menyembunyikan **310 visual instance** di grup `uploaded_fbx_visual` yang berasal dari FBX unggahan. Pada OFF panel lantai modular, rib/pylon, bagian struktur gerbang dan cladding hilang. 253.628 piksel berbeda pada arena, 77.594 pada extraction; arena ON setelah F9 kedua identik piksel dengan ON pertama. Ini **membuktikan asset FBX benar dipakai di WebGL saat ini**, bukan bahwa seluruh dunia FBX atau kualitasnya sudah bagus: base deck dan reaktor prosedural tetap terlihat di OFF; material serta komposisi world masih terlihat kasar.

## Gerbang berikutnya — perbaiki hal yang tampak, lalu foto lagi

1. Pisahkan identitas FIRE dan WEAPON: FIRE harus terbaca sebagai menembak; WEAPON sebagai mengganti/membuka pilihan senjata, bukan rifle identik tanpa kilat. Pertahankan target nyaman dan simbol tebal, jangan mengecilkan ikon agar muat ornamen baru.
2. Sediakan cara eksplisit di root WebAssembly untuk melihat **Mobile HUD dari desktop**; jangan mengubah mode keyboard/mouse normal secara diam-diam. Validasi tombol dengan aksi nyata, bukan ukuran nominal.
3. Bandingkan ulang foto 390×844, 844×390, dan preview desktop. Baca seluruh gambar, bbox glyph, pemisahan makna, area pandang, thumb overlap, dan respons pada interaksi. Tes parser/CI hanya gerbang teknis. Rekam temuan buruk juga; pemain yang memberi sign-off artistik, bukan unit test.

**Status:** arah produk dipilih sebelumnya; tampilan yang ada belum disetujui. PR #1 tetap tidak di-merge.
