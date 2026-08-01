import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

const _requestTimeout = Duration(seconds: 15);

/// Result of a lightweight reachability check against the API, used by the
/// login screen to warn the user before they even try to submit.
enum ServerStatus { ok, maintenance, unreachable }

class MaintenanceInfo {
  final bool active;
  final String message;
  final DateTime? expectedEndAt;

  const MaintenanceInfo({
    required this.active,
    required this.message,
    this.expectedEndAt,
  });

  factory MaintenanceInfo.fromJson(Map<String, dynamic> json) {
    return MaintenanceInfo(
      active: json['maintenance'] == true,
      message: json['message']?.toString() ??
          'Sistem sedang dalam pemeliharaan. Silakan coba lagi nanti.',
      expectedEndAt: DateTime.tryParse(
        json['expected_end_at']?.toString() ?? '',
      )?.toLocal(),
    );
  }
}

/// Thrown for every non-2xx response, carrying Laravel's standard error
/// shape ({"message": "...", "errors": {"field": ["..."]}}) so screens can
/// show field-level validation messages the same way the web app does.
/// [code] is an optional machine-readable discriminator some endpoints add
/// alongside [message] (e.g. "saldo_di_bawah_minimum" from the tagihan-pay
/// endpoint) for when two different failure reasons need different UI
/// treatment, not just different wording.
class ApiException implements Exception {
  final String message;
  final Map<String, List<String>>? errors;
  final int? statusCode;
  final String? code;

  ApiException(this.message, {this.errors, this.statusCode, this.code});

  String? errorFor(String field) => errors?[field]?.first;

  @override
  String toString() => message;
}

class ApiClient {
  String? _token;
  FutureOr<bool> Function()? _onUnauthorized;
  void Function(MaintenanceInfo info)? _onMaintenance;
  bool _handlingUnauthorized = false;

  void setToken(String? token) => _token = token;
  void setUnauthorizedHandler(FutureOr<bool> Function() handler) {
    _onUnauthorized = handler;
  }
  void setMaintenanceHandler(void Function(MaintenanceInfo info) handler) {
    _onMaintenance = handler;
  }

  Future<MaintenanceInfo?> fetchMaintenanceStatus() async {
    try {
      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/system/status'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 6));
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['data'] is! Map) return null;
      return MaintenanceInfo.fromJson(
        Map<String, dynamic>.from(decoded['data'] as Map),
      );
    } catch (_) {
      return null;
    }
  }

  /// Pings the API host so the login screen can warn the user up front if
  /// the server is down or in maintenance, instead of only finding out
  /// after they've typed their credentials and pressed submit.
  Future<ServerStatus> checkServerStatus() async {
    try {
      final response = await http
          .get(
            Uri.parse(ApiConfig.baseUrl),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 6));
      return response.statusCode == 503
          ? ServerStatus.maintenance
          : ServerStatus.ok;
    } on SocketException {
      return ServerStatus.unreachable;
    } on TimeoutException {
      return ServerStatus.unreachable;
    } catch (_) {
      // Reached the host but got something unexpected back (e.g. a
      // malformed response) - not our concern here, only reachability is.
      return ServerStatus.ok;
    }
  }

  Future<dynamic> get(String path) => _request('GET', path);

  Future<dynamic> post(String path, [Map<String, dynamic>? body]) =>
      _request('POST', path, body);

  /// Request publik yang tidak membawa access token dan tidak memicu
  /// pemulihan 401. Dipakai khusus untuk login dan rotasi token login cepat.
  Future<dynamic> postPublic(String path, [Map<String, dynamic>? body]) =>
      _request('POST', path, body, false, false);

  Future<dynamic> put(String path, [Map<String, dynamic>? body]) =>
      _request('PUT', path, body);

  Future<dynamic> delete(String path, [Map<String, dynamic>? body]) =>
      _request('DELETE', path, body);

  Future<dynamic> postFile(
    String path, {
    required String field,
    required String filePath,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}$path'),
    )..headers['Accept'] = 'application/json';
    if (_token != null) request.headers['Authorization'] = 'Bearer $_token';
    request.files.add(await http.MultipartFile.fromPath(field, filePath));

    try {
      final streamed = await request.send().timeout(_requestTimeout);
      final response = await http.Response.fromStream(streamed);
      final decoded = response.body.isNotEmpty
          ? jsonDecode(response.body)
          : null;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return decoded;
      }
      if (response.statusCode == 503) {
        final payload = decoded is Map<String, dynamic>
            ? decoded
            : <String, dynamic>{};
        final rawInfo = payload['maintenance'] is Map
            ? Map<String, dynamic>.from(payload['maintenance'] as Map)
            : <String, dynamic>{};
        final info = MaintenanceInfo.fromJson({
          ...rawInfo,
          'maintenance': true,
          'message': payload['message'],
        });
        _onMaintenance?.call(info);
        throw ApiException(
          info.message,
          statusCode: 503,
          code: 'maintenance_mode',
        );
      }
      final errors = decoded is Map && decoded['errors'] is Map
          ? (decoded['errors'] as Map).map(
              (key, value) => MapEntry(
                key.toString(),
                value is List
                    ? value.map((item) => item.toString()).toList()
                    : [value.toString()],
              ),
            )
          : null;
      throw ApiException(
        decoded is Map && decoded['message'] != null
            ? decoded['message'].toString()
            : _fallbackErrorMessage(response.statusCode),
        errors: errors,
        statusCode: response.statusCode,
      );
    } on SocketException {
      throw ApiException(
        'Tidak bisa terhubung ke server. Periksa koneksi internet Anda.',
      );
    } on TimeoutException {
      throw ApiException('Unggah foto terlalu lama. Silakan coba lagi.');
    }
  }

  /// Downloads a public/signed binary resource without sending the API token.
  /// Used for short-lived kwitansi PDF URLs returned by the authenticated API.
  Future<Uint8List> downloadBytes(String url) async {
    try {
      final response = await http
          .get(Uri.parse(url), headers: {'Accept': 'application/pdf'})
          .timeout(_requestTimeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response.bodyBytes;
      }

      throw ApiException(
        'Berkas tidak dapat diunduh. Silakan coba lagi.',
        statusCode: response.statusCode,
      );
    } on SocketException {
      throw ApiException(
        'Tidak bisa terhubung ke server. Periksa koneksi internet Anda.',
      );
    } on TimeoutException {
      throw ApiException('Unduhan terlalu lama. Silakan coba lagi.');
    }
  }

  Future<dynamic> _request(
    String method,
    String path, [
    Map<String, dynamic>? body,
    bool kirimToken = true,
    bool bolehPulihkan = true,
  ]) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    final headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (kirimToken && _token != null) 'Authorization': 'Bearer $_token',
    };

    http.Response response;

    try {
      response = await switch (method) {
        'POST' => http.post(
          uri,
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        ),
        'PUT' => http.put(
          uri,
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        ),
        'DELETE' => http.delete(
          uri,
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        ),
        _ => http.get(uri, headers: headers),
      }.timeout(_requestTimeout);
    } on SocketException {
      throw ApiException(
        'Tidak bisa terhubung ke server. Periksa koneksi internet Anda.',
      );
    } on TimeoutException {
      throw ApiException(
        'Server tidak merespons. Server mungkin sedang tidak aktif, silakan coba lagi nanti.',
      );
    }

    if (response.statusCode == 503) {
      MaintenanceInfo info;
      try {
        final payload = jsonDecode(response.body);
        final maintenance = payload is Map && payload['maintenance'] is Map
            ? Map<String, dynamic>.from(payload['maintenance'] as Map)
            : <String, dynamic>{};
        info = MaintenanceInfo.fromJson({
          ...maintenance,
          'maintenance': true,
          'message': payload is Map ? payload['message'] : null,
        });
      } catch (_) {
        info = const MaintenanceInfo(
          active: true,
          message: 'Sistem sedang dalam pemeliharaan. Silakan coba lagi nanti.',
        );
      }
      _onMaintenance?.call(info);
      throw ApiException(
        info.message,
        statusCode: 503,
        code: 'maintenance_mode',
      );
    }

    dynamic decoded;
    try {
      decoded = response.body.isNotEmpty ? jsonDecode(response.body) : null;
    } on FormatException {
      // Server responded but not with JSON (e.g. a proxy's HTML error page
      // for a 502/504) - treat as the server being down rather than
      // crashing on the decode.
      throw ApiException(
        response.statusCode >= 500
            ? 'Server sedang tidak aktif atau bermasalah. Silakan coba lagi nanti.'
            : 'Terjadi kesalahan tak terduga, silakan coba lagi.',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    if (response.statusCode == 401) {
      if (bolehPulihkan && !_handlingUnauthorized && _token != null) {
        _handlingUnauthorized = true;
        var pulih = false;
        try {
          pulih = await _onUnauthorized?.call() ?? false;
        } finally {
          _handlingUnauthorized = false;
        }
        if (pulih) {
          return _request(method, path, body, kirimToken, false);
        }
      }
      throw ApiException(
        'Sesi berakhir, silakan login kembali.',
        statusCode: 401,
      );
    }

    Map<String, List<String>>? errors;
    if (decoded is Map && decoded['errors'] is Map) {
      errors = {};
      for (final entry in (decoded['errors'] as Map).entries) {
        final key = entry.key.toString();
        final value = entry.value;
        final messages = value is List
            ? value
                  .map((item) => item?.toString().trim() ?? '')
                  .where((item) => item.isNotEmpty)
                  .toList()
            : [
                if (value?.toString().trim().isNotEmpty == true)
                  value.toString().trim(),
              ];
        if (messages.isNotEmpty) errors[key] = messages;
      }
      if (errors.isEmpty) errors = null;
    }

    final rawMessage = decoded is Map
        ? decoded['message']?.toString().trim()
        : null;
    String? firstFieldError;
    for (final messages in errors?.values ?? const <List<String>>[]) {
      if (messages.isNotEmpty) {
        firstFieldError = messages.first;
        break;
      }
    }
    final message = response.statusCode >= 500
        ? _fallbackErrorMessage(response.statusCode)
        : rawMessage?.isNotEmpty == true
        ? rawMessage!
        : firstFieldError ?? _fallbackErrorMessage(response.statusCode);

    final code = (decoded is Map && decoded['code'] is String)
        ? decoded['code'] as String
        : null;

    throw ApiException(
      message,
      errors: errors,
      statusCode: response.statusCode,
      code: code,
    );
  }

  String _fallbackErrorMessage(int statusCode) {
    return switch (statusCode) {
      403 => 'Anda tidak memiliki akses untuk melakukan tindakan ini.',
      404 => 'Data yang diminta tidak ditemukan atau sudah berubah.',
      422 =>
        'Pembayaran ditolak. Periksa nominal, saldo, dan PIN lalu coba lagi.',
      423 => 'PIN transaksi sementara dikunci. Silakan coba kembali nanti.',
      _ when statusCode >= 500 =>
        'Server sedang bermasalah. Silakan coba lagi beberapa saat.',
      _ => 'Terjadi kesalahan, silakan coba lagi.',
    };
  }
}
