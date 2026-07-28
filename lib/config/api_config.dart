import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kReleaseMode;

/// Konfigurasi URL API Laravel.
///
/// Kelas ini digunakan untuk menentukan alamat (Base URL) API yang akan
/// diakses oleh aplikasi Flutter.
///
/// URL dapat diubah tanpa mengedit source code menggunakan perintah:
///
/// flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000/api
///
/// Prioritas penggunaan URL:
/// 1. Menggunakan nilai dari --dart-define jika tersedia.
/// 2. Jika aplikasi dalam mode Release, otomatis menggunakan server produksi.
/// 3. Jika mode Debug:
///    - Android Emulator → menggunakan 10.0.2.2.
///    - iOS Simulator/Desktop → menggunakan 127.0.0.1.
///
/// Catatan:
/// - 10.0.2.2 hanya dapat digunakan pada Android Emulator.
/// - Jika menggunakan perangkat fisik (Android/iPhone),
///   gunakan alamat IP komputer yang menjalankan Laravel,
///   misalnya:
///
/// flutter run --dart-define=API_BASE_URL=http://192.168.1.100:8000/api
///
class ApiConfig {
  /// Menyimpan nilai URL API dari parameter --dart-define.
  /// Jika tidak diberikan, nilainya akan berupa string kosong.
  static const String _override = String.fromEnvironment('API_BASE_URL');

  /// URL server produksi (hosting).
  static const String _prodUrl = 'https://emall.apinsdigital.my.id/api';

  /// Mengembalikan Base URL API sesuai kondisi aplikasi.
  static String get baseUrl {
    // Jika terdapat URL dari --dart-define,
    // maka URL tersebut digunakan.
    if (_override.isNotEmpty) return _normalize(_override);

    // Jika aplikasi sudah dalam mode Release,
    // gunakan server produksi.
    if (kReleaseMode) return _normalize(_prodUrl);

    // Jika masih mode Debug dan dijalankan
    // menggunakan Android Emulator,
    // gunakan alamat khusus emulator.
    if (Platform.isAndroid) {
      return 'http://192.168.1.24:8000/api';
    }

    // Untuk iOS Simulator, Windows, Linux, dan macOS
    // gunakan localhost.

    return 'http://127.0.0.1:8000/api';
  }

  /// Service sudah menambahkan `/wali/...` pada setiap endpoint. Normalisasi
  /// ini mencegah konfigurasi `/api/wali` membentuk URL ganda seperti
  /// `/api/wali/wali/login`.
  static String _normalize(String value) {
    var normalized = value.trim().replaceFirst(RegExp(r'/+$'), '');
    if (normalized.endsWith('/api/wali')) {
      normalized = normalized.substring(0, normalized.length - 5);
    }
    return normalized;
  }
}
