# Alur Autentikasi Aplikasi Wali

Dokumen ini menjadi acuan developer untuk memelihara autentikasi aplikasi
wali. Implementasi utamanya berada di:

- `lib/services/auth_service.dart`: state sesi dan login cepat.
- `lib/screens/auth_gate.dart`: penentu layar awal.
- `lib/screens/login_screen.dart`: login password.
- `lib/screens/pin_login_screen.dart`: verifikasi PIN dan sidik jari.
- `lib/screens/login_pin_setup_screen.dart`: pengaturan PIN.
- `lib/widgets/session_activity_guard.dart`: pengunci saat aplikasi ditinggalkan.

> PIN login hanya membuka token server yang masih tersimpan. PIN login bukan
> PIN transaksi dan tidak membuat sesi server baru.

## Menu flow

1. [Keputusan layar awal](#1-keputusan-layar-awal)
2. [Login password](#2-login-password)
3. [Aktivasi PIN](#3-aktivasi-pin)
4. [Aktivasi sidik jari](#4-aktivasi-sidik-jari)
5. [Buka ulang dengan PIN](#5-buka-ulang-dengan-pin)
6. [Buka ulang dengan sidik jari](#6-buka-ulang-dengan-sidik-jari)
7. [PIN dan sidik jari bersamaan](#7-pin-dan-sidik-jari-bersamaan)
8. [Salah PIN lima kali](#8-salah-pin-lima-kali)
9. [Gunakan Password](#9-gunakan-password)
10. [Menonaktifkan login cepat](#10-menonaktifkan-login-cepat)
11. [Aplikasi masuk latar belakang](#11-aplikasi-masuk-latar-belakang)
12. [Logout dan ganti akun](#12-logout-dan-ganti-akun)
13. [Token kedaluwarsa](#13-token-kedaluwarsa)
14. [Gangguan jaringan](#14-gangguan-jaringan)
15. [Penyimpanan dan keamanan](#15-penyimpanan-dan-keamanan)
16. [Kontrak API](#16-kontrak-api)
17. [Checklist pengujian](#17-checklist-pengujian)
18. [Aturan perubahan kode](#18-aturan-perubahan-kode)

## 1. Keputusan layar awal

`AuthGate` adalah satu-satunya pengambil keputusan layar autentikasi.
Urutannya:

```text
Mulai
  |
  +-- pemulihan belum selesai? ----------> Splash
  +-- belum onboarding dan belum login? -> Onboarding
  +-- token + PIN tersimpan? ------------> Layar PIN
  +-- token + biometrik tersimpan? ------> Layar sidik jari
  +-- tidak ada sesi? -------------------> Login password
  +-- sesi perlu PIN? -------------------> Layar PIN
  +-- sesi perlu biometrik? -------------> Layar sidik jari
  +-- wajib ganti password? -------------> Ganti password
  +--------------------------------------> Beranda
```

| State | Arti |
|---|---|
| `restoring` | Secure storage sedang dibaca. |
| `isLoggedIn` | Token dan profil tersedia dalam memori. |
| `needsPinUnlock` | Sesi harus dibuka dengan PIN. |
| `needsBiometricUnlock` | Sesi harus dibuka dengan biometrik. |
| `canUsePinLogin` | Token dan PIN lokal tersedia. |
| `canUseBiometricLogin` | Token dan persetujuan biometrik tersedia. |

## 2. Login password

```text
Email/No. KK + password
  -> POST /wali/login
  -> simpan token dan cache profil di secure storage
  -> pasang token pada ApiClient
  -> daftarkan token push notification
  -> must_change_password? ganti password : beranda
```

Password adalah akar kepercayaan. PIN atau biometrik hanya dapat diaktifkan
setelah login password berhasil. Jika akun berbeda masuk pada perangkat yang
sama, konfigurasi login cepat akun sebelumnya harus dibersihkan.

## 3. Aktivasi PIN

```text
Profil -> Keamanan -> Aktifkan/Ubah PIN
  -> buat PIN enam digit
  -> konfirmasi PIN
  -> simpan dalam secure storage
  -> simpan ID pemilik login cepat
  -> reset penghitung salah PIN
```

PIN tidak dikirim ke server dan tidak boleh disimpan di penyimpanan biasa.

## 4. Aktivasi sidik jari

```text
Profil -> Keamanan -> Aktifkan sidik jari
  -> periksa dukungan perangkat
  -> prompt biometrik sistem
  -> jika berhasil, simpan status aktif dan ID wali
```

Aplikasi tidak menyimpan data sidik jari. Sistem operasi hanya mengembalikan
hasil berhasil, gagal, dibatalkan, atau terkunci.

## 5. Buka ulang dengan PIN

Berlaku setelah aplikasi dibuang dari Recent Apps, proses aplikasi dimatikan
sistem, atau perangkat dimulai ulang.

```text
Startup
  -> baca token, PIN, penghitung gagal, dan cache profil
  -> pulihkan profil tanpa menunggu jaringan
  -> needsPinUnlock = true
  -> tampilkan keypad PIN
  -> PIN benar: reset penghitung dan buka beranda
  -> request API berikutnya tetap memvalidasi token
```

Cache profil mencegah koneksi lambat dianggap sebagai logout. Seluruh data
keuangan tetap berasal dari API yang dilindungi token.

## 6. Buka ulang dengan sidik jari

Jika biometrik aktif dan PIN tidak aktif:

```text
Startup -> pulihkan sesi -> needsBiometricUnlock = true
  -> layar biometrik
  -> prompt sistem terbuka otomatis
  |-- berhasil -> beranda
  |-- gagal/batal -> tetap di layar dan dapat mencoba lagi
  +-- Gunakan Password -> hard logout -> login password
```

Prompt otomatis dijalankan setelah frame pertama selesai agar dialog stabil.

## 7. PIN dan sidik jari bersamaan

PIN menjadi tampilan utama dan ikon sidik jari menjadi alternatif:

```text
Layar PIN
  |-- PIN benar -------------------> Beranda
  |-- sidik jari valid ------------> Beranda
  +-- Gunakan Password ------------> Login password
```

Kegagalan sidik jari tidak menambah jumlah salah PIN.

## 8. Salah PIN lima kali

Jumlah kesalahan disimpan secara persisten agar restart tidak mengatur ulang
percobaan.

```text
PIN salah -> tambah penghitung
  |-- kesalahan 1-4 -> tampilkan sisa percobaan
  +-- kesalahan ke-5
       -> cabut token jika memungkinkan
       -> hapus sesi, cache profil, PIN, biometrik, dan pemilik login cepat
       -> wajib login password
```

Aturan ini harus berada di `AuthService`, bukan hanya pada widget.

## 9. Gunakan Password

```text
Tekan Gunakan Password
  -> hard logout
  -> cabut token server
  -> hapus sesi dan login cepat
  -> tampilkan login password
```

Token tidak boleh dipertahankan karena tindakan ini adalah pilihan eksplisit
pengguna untuk kembali memakai password.

## 10. Menonaktifkan login cepat

- PIN dimatikan, biometrik masih aktif: gunakan biometrik.
- Biometrik dimatikan, PIN masih aktif: gunakan PIN.
- Metode terakhir dimatikan: hard logout dan wajib password.

## 11. Aplikasi masuk latar belakang

`SessionActivityGuard` menerapkan:

```text
Aplikasi tidak aktif
  |-- ada PIN ---------------------> kunci dengan PIN
  |-- hanya ada biometrik --------> kunci dengan biometrik
  +-- tidak ada login cepat ------> logout
```

Data sensitif tidak boleh terlihat sebelum kunci berhasil dibuka.

## 12. Logout dan ganti akun

- **Kunci cepat**: jika login cepat aktif, token dipertahankan dan profil
  dalam memori dilepas; pengguna kembali melalui PIN/biometrik.
- **Hard logout**: token server dicabut dan seluruh sesi lokal dibersihkan.
- **Ganti akun**: selalu hard logout agar akun baru tidak mewarisi PIN atau
  persetujuan biometrik akun lama.

## 13. Token kedaluwarsa

```text
Request API -> 401
  -> jika PIN/biometrik dan quick token tersedia:
       rotasi quick token -> terbitkan access token baru -> ulangi request
  -> jika quick token tidak sah:
       hapus token dan cache profil -> login password
```

Quick token hanya dipakai setelah perangkat dipercaya melalui login password
dan login cepat diaktifkan. Pengguna versi lama perlu login password satu kali
setelah pembaruan agar quick token pertama diterbitkan.

## 14. Gangguan jaringan

- Cache profil digunakan saat startup tanpa menunggu `/wali/me`.
- Instalasi versi lama tanpa cache mencoba `/wali/me` sekali lalu membuat cache.
- Hanya respons `401` dianggap token tidak sah.
- Timeout, server maintenance, atau koneksi putus tidak boleh menghapus PIN.

## 15. Penyimpanan dan keamanan

| Kunci secure storage | Isi | Dihapus saat |
|---|---|---|
| `token` | Bearer token API | Hard logout atau 401 |
| `quick_login_cached_user` | Profil minimum wali | Hard logout atau 401 |
| `login_pin` | PIN lokal | Dinonaktifkan, lima kali salah, hard logout |
| `biometric_enabled` | Persetujuan biometrik | Dinonaktifkan atau hard logout |
| `quick_login_user_id` | ID pemilik login cepat | Ganti akun/hard logout |
| `login_pin_failed_attempts` | Jumlah salah PIN | PIN benar/hard logout |

Semua nilai wajib berada di `flutter_secure_storage`. Jangan memasukkan saldo,
tagihan, daftar anak, atau transaksi ke cache autentikasi.

Menghapus Recent Apps tidak menghapus secure storage. Menghapus data aplikasi
melalui Settings atau uninstall memang menghapusnya sehingga password wajib.

## 16. Kontrak API

| Method | Endpoint | Fungsi |
|---|---|---|
| `POST` | `/wali/login` | Membuat token dan mengembalikan profil |
| `GET` | `/wali/me` | Memvalidasi token dan menyegarkan profil |
| `POST` | `/wali/logout` | Mencabut token |
| `PUT` | `/wali/profile` | Memperbarui profil dan cache |
| `POST` | `/wali/password` | Mengganti password |

Respons login minimal:

```json
{
  "token": "token-server",
  "user": {
    "id": 7,
    "name": "Nama Wali",
    "email": "wali@example.id",
    "phone": "08123456789",
    "must_change_password": false
  }
}
```

## 17. Checklist pengujian

```bash
cd mobile
flutter test test/auth_service_quick_login_test.dart
flutter analyze
```

- [ ] Login password dan wajib ganti password bekerja.
- [ ] PIN dapat dibuat, diubah, dan dinonaktifkan.
- [ ] Sidik jari hanya aktif setelah verifikasi sistem berhasil.
- [ ] Setelah Recent Apps dibersihkan, aplikasi langsung meminta PIN.
- [ ] Mode biometrik saja membuka prompt otomatis.
- [ ] PIN dan biometrik dapat membuka sesi yang sama.
- [ ] Empat salah PIN tetap tersimpan setelah restart.
- [ ] Salah PIN kelima mewajibkan password.
- [ ] Gunakan Password mencabut login cepat.
- [ ] Menonaktifkan metode terakhir mewajibkan password.
- [ ] Respons 401 kembali ke password dengan pesan yang jelas.
- [ ] Koneksi mati tidak menghapus PIN.
- [ ] Ganti akun tidak mewarisi login cepat akun lama.
- [ ] Hapus data aplikasi melalui Settings mewajibkan password.

## 18. Aturan perubahan kode

1. Simpan state autentikasi hanya di `AuthService`.
2. Perbarui urutan keputusan di `AuthGate`.
3. Bedakan kunci cepat dan hard logout.
4. Tentukan kapan setiap kunci secure storage dihapus.
5. Bedakan gangguan jaringan dari respons `401`.
6. Tambahkan tes restart proses, bukan hanya tes widget.
7. Uji pergantian akun pada perangkat yang sama.
8. Perbarui dokumen ini dan `README.md`.
