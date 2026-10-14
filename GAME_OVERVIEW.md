GAME OVERVIEW 

Gambaran game yang akan kita bangun
Untuk memperjelas visi visualnya, bayangkan sebuah arena futuristik dengan karakter yang selalu terlihat dari belakang. Pemain bergerak menggunakan joystick kiri, mengarahkan kamera dengan ibu jari kanan, dan menembakkan senjata yang memiliki karakteristik berbeda.
Saat menggunakan Pulse Rifle, proyektil energi melesat cepat dengan efek impact kecil. Ketika mengganti Nova Launcher, proyektil bergerak lebih lambat, kemudian meledak dan menghasilkan gelombang energi yang terlihat jelas. Saat menggunakan Arc Shooter, sambaran listrik berpindah di antara beberapa musuh.
Musuh datang dari beberapa arah. Pemain bergerak menghindari serangan, memilih target, dan mencoba bertahan selama mungkin.
Ketika permainan berakhir, layar hasil menampilkan skor, jumlah eliminasi, wave yang berhasil diselesaikan, dan Battle Points yang diperoleh. Pemain dapat membuka senjata baru, mencobanya, lalu kembali ke arena.
Yang harus membuat pemain ingin bermain lagi bukan kerumitan sistemnya, tetapi sensasi menembak, variasi senjata, dan rasa penasaran terhadap senjata berikutnya.
Arah visual yang disarankan
Saya menyarankan stylized-realistic sci-fi sebagai titik awal, dengan tiga prioritas visual:
Karakter dan senjata mudah dikenali.
Efek tembakan terlihat kuat tetapi tidak menutupi gameplay.
Arena cukup detail untuk terasa premium, tetapi tetap ringan bagi perangkat Android.
Referensi ini menggambarkan arah artistik, bukan hasil akhir yang otomatis dapat dicapai oleh engine atau AI pembuat aset.
Keputusan teknis yang paling penting
Ada tiga hal yang perlu dipahami sebelum masuk ke proses coding.
1. Jangan memulai dari model 3D yang kompleks. Mulai dari karakter placeholder, kamera, gerakan, dan satu senjata. Jika kontrol dan aiming tidak terasa benar, model karakter yang mahal tidak akan menyelesaikan masalah tersebut.
2. Sistem senjata harus modular sejak awal. Menambahkan senjata baru nantinya harus sebisa mungkin dilakukan dengan membuat konfigurasi, projectile behavior, dan efek yang diperlukan, bukan menyalin seluruh kode senjata sebelumnya.
3. Multiplayer jangan diimplementasikan sekarang. Kita cukup menjaga batas tanggung jawab antarsistem agar pilihan arsitektur saat ini tidak mempersulit pengembangan selanjutnya. Kesiapan multiplayer yang sesungguhnya baru dapat dinilai setelah kebutuhan jaringan diketahui.
Rekomendasi urutan pembangunan
Prioritas
Komponen
Alasan
P0
Kamera dan pergerakan
Fondasi seluruh pengalaman third-person
P0
Aiming dan tembakan
Menentukan kualitas inti permainan
P0
Hit detection dan damage
Membuat pertempuran benar-benar berfungsi
P1
Musuh dan AI dasar
Menghasilkan gameplay yang dapat dimainkan
P1
Wave dan reward
Membentuk core loop
P1
Tiga senjata berbeda
Membuktikan daya tarik utama produk
P2
Poin dan weapon unlock
Membentuk progression
P2
Save/load
Menjaga progres pemain
P3
Art, audio, dan VFX pass
Meningkatkan kualitas presentasi
P4
Playtest dan balancing
Memvalidasi kualitas produk
P5
Evaluasi multiplayer
Dilakukan setelah single-player solid