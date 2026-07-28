# Wali Santri (Flutter)

Aplikasi mobile untuk wali santri — melihat saldo & tagihan anak, membayar
tagihan dari saldo. Terhubung ke API `/api/wali/*` di aplikasi Laravel utama
(lihat dokumentasi lengkap di `/dev/api/wali` saat aplikasi web berjalan).

Dibuat sebagai folder `mobile/` di dalam repo Laravel ini untuk kemudahan
development (satu tempat, satu Claude Code session). Karena Flutter project
sepenuhnya berdiri sendiri (tidak ada dependency ke kode Laravel), folder ini
aman dipindah ke repo terpisah kapan saja nanti — tinggal `cut` folder
`mobile/` beserta isinya ke lokasi/repo baru.

## Menjalankan

```
cd mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
```

`API_BASE_URL` menentukan alamat API Laravel yang dituju. Default (tanpa
`--dart-define`) sudah otomatis menyesuaikan skenario development paling
umum (lihat `lib/config/api_config.dart`):

| Menjalankan di | Alamat API yang dipakai |
|---|---|
| Emulator Android | `http://10.0.2.2:8000/api` (otomatis) |
| Simulator iOS / desktop (Windows/macOS/Linux) | `http://127.0.0.1:8000/api` (otomatis) |
| HP fisik (Android/iOS) | **Wajib** `--dart-define=API_BASE_URL=http://<IP-LAN-komputer>:8000/api` |

Pastikan Laravel jalan duluan di komputer yang sama (`php artisan serve` di
folder root repo ini, bukan folder `mobile/`).

### Login untuk uji coba

Pakai akun yang sudah ada dari `php artisan migrate:fresh --seed` di sisi
Laravel — cek halaman `/dev/instalasi` (role Dev) untuk daftar akun contoh,
atau pakai akun wali yang dibuat lewat halaman Data Keluarga/Tambah Santri di
web (login & kata sandi awalnya sama-sama No. KK keluarga tsb).

## Yang sudah ada

- Login (email atau No. KK) & logout, sesi tersimpan aman di perangkat
  (`flutter_secure_storage`), otomatis login lagi saat app dibuka ulang.
- Alur wajib ganti kata sandi untuk akun yang dibuat otomatis dengan No. KK
  sebagai kata sandi awal (mengikuti `must_change_password` dari API), plus
  ganti kata sandi sukarela dari tab Profil.
- Navigasi bottom bar gaya PayPal: 4 tab (Beranda, Tagihan, Riwayat, Profil)
  plus tombol **Top Up** terangkat/docked di tengah (notch), gaya flat minim
  shadow (border tipis, bukan drop shadow) di seluruh kartu.
- Tab **Beranda**: kartu saldo putih dengan badge ikon kecil untuk satu anak
  yang sedang dipilih (pemilih nama di atas kalau wali punya &gt;1 anak —
  semua tab lain otomatis ikut anak yang sama), ringkasan jumlah tagihan
  aktif & total tunggakan, dan kartu pratinjau tagihan/aktivitas terbaru
  dengan tautan "Lihat Semua" di bagian bawah kartu.
- Tab **Tagihan** & **Riwayat**: daftar lengkap untuk anak yang sedang
  dipilih, termasuk bayar tagihan langsung dari saldo.
- Tab **Profil**: header banner gradasi dengan avatar menumpuk di batas
  banner, identitas wali, ganti kata sandi, keluar.
- **Top Up saldo dengan UI custom (Midtrans Core API)** — pilih salah satu
  dari 4 metode (VA BNI, VA BCA, VA BRI, QRIS) lewat `POST
  /anak/{santri}/topup/core`, lalu nomor VA atau gambar QR-nya dirender
  langsung di dalam app (bukan redirect ke halaman Midtrans/browser luar).
  Ada tombol nominal cepat (50rb&ndash;500rb), info otomatis-potong-tagihan
  sebelum konfirmasi (nominalnya ditarik dari `GET /topup/pengaturan`, admin
  bisa ubah lewat panel web, jadi tidak di-hardcode di app), dan tutorial
  "Cara Bayar" langkah-demi-langkah khusus tiap metode setelah top up
  dibuat. Wali kembali ke app dan tekan "Cek Status Sekarang" yang menarik
  status langsung dari Midtrans lewat `POST /topup/{topup}/sync`, karena
  pembayaran selesai di luar app (transfer VA / scan QRIS) sehingga tidak
  ada callback otomatis. (Endpoint Snap lama, `POST /anak/{santri}/topup`,
  masih ada di backend tapi tidak dipakai UI mobile ini lagi.)

## Integrasi produksi

- Push notification Firebase sudah aktif. Token perangkat didaftarkan setelah
  login dan dihapus saat logout; notifikasi mencakup tagihan, top up, dan
  aktivitas saldo.
- App icon, splash, serta branding aplikasi sudah memakai aset eMall dan info
  dinamis dari `GET /api/wali/app-info`.
- Build release default mengarah ke `https://emall.ecometer.my.id/api` dan
  tetap dapat dioverride melalui `--dart-define=API_BASE_URL=...`.

## Design system

- Token warna, tipografi, spacing, radius, dan theme komponen berada di
  `lib/theme/app_theme.dart`.
- Seluruh halaman memakai background abu-hijau muda, surface putih, border
  tipis, radius 10 px, dan shadow dekoratif seminimal mungkin.
- `FlatCard`, dialog konfirmasi, bottom sheet filter, input, tombol, chip,
  AppBar, dan navigasi menggunakan theme yang sama agar perubahan visual
  berikutnya tidak perlu dilakukan satu per satu di setiap screen.
- Text scale perangkat tetap dihormati dalam rentang 90–115% agar layout
  finansial tetap stabil tanpa menonaktifkan aksesibilitas sepenuhnya.

## Struktur

```
lib/
  config/api_config.dart       Alamat dasar API (bisa di-override --dart-define)
  models/                      Anak, Tagihan, Transaksi, Topup, WaliUser
  providers/
    anak_provider.dart         Daftar anak wali + anak yang sedang dipilih (dipakai lintas tab)
    tab_index_provider.dart    Index tab bottom-nav aktif (dipakai lintas tab, mis. tombol "Lihat Semua")
  services/
    api_client.dart            HTTP wrapper + ApiException (format error Laravel)
    auth_service.dart          Sesi: login/logout/ganti-password, token di secure storage
    wali_api.dart               Panggilan ke endpoint anak/saldo/tagihan/transaksi/topup
  utils/
    metode_topup.dart           Metadata 4 metode top up (label/ikon/tutorial "Cara Bayar") - satu sumber dipakai selector & tutorial
  widgets/
    flat_card.dart              Container flat (border tipis, tanpa shadow) dipakai di banyak tempat
    status_badge.dart           Badge status tagihan
    anak_switcher.dart          Baris pilihan anak (kalau wali punya lebih dari satu)
  screens/
    auth_gate.dart               Penentu layar awal (splash/login/ganti-password/main)
    login_screen.dart
    change_password_screen.dart
    main_screen.dart             Shell bottom-nav (4 tab + tombol Top Up docked di tengah)
    home_tab.dart                Tab Beranda
    tagihan_tab.dart             Tab Tagihan
    riwayat_tab.dart             Tab Riwayat
    profil_tab.dart              Tab Profil
    topup_tab.dart                Layar Top Up (dibuka lewat tombol tengah, bukan tab IndexedStack)
```

State management: `provider` (`ChangeNotifierProvider`) — dipilih karena
kecil dan cukup untuk ukuran app saat ini, bukan karena batasan teknis. Boleh
diganti ke Riverpod/Bloc nanti kalau app-nya berkembang lebih kompleks.
