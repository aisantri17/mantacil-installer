# MantaCil Installer

Skrip instalasi MantaCil Ultimate Auto-Installer. Skrip bash interaktif ini dirancang untuk menginstal MantaCil Panel dan MantaCil Wings ke peladen/server VPS Anda secara kilat dan rapi.

## Cara Menggunakan

Masuk (login) ke server Ubuntu 22.04 / 24.04 (Fresh Install direkomendasikan) dengan hak akses **root**, lalu jalankan perintah berikut:

```bash
bash <(curl -s https://raw.githubusercontent.com/aisantri17/mantacil-installer/main/install.sh)
```

Skrip ini akan menampilkan menu instalasi MantaCil. Silakan pilih bagian apa yang ingin diinstal (Panel, Wings, atau Keduanya), isikan konfigurasi domain dan *password*, dan biarkan skrip menyelesaikan seluruh kerja keras untuk Anda.

## Dukungan Khusus MantaCil
Skrip ini juga dirancang untuk secara otomatis menanamkan file `egg-botwhatsapp.json` ke dalam Panel sesaat setelah instalasi Panel selesai. 
