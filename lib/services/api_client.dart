import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

const _requestTimeout = Duration(seconds: 15);

/// Result of a lightweight reachability check against the API, used by the
/// login screen to warn the user before they even try to submit.
enum ServerStatus { ok, maintenance, unreachable }

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

  void setToken(String? token) => _token = token;

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

  Future<dynamic> put(String path, [Map<String, dynamic>? body]) =>
      _request('PUT', path, body);

  Future<dynamic> delete(String path, [Map<String, dynamic>? body]) =>
      _request('DELETE', path, body);

  Future<dynamic> _request(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    final headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
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
      throw ApiException(
        'Server sedang dalam pemeliharaan (maintenance). Silakan coba lagi nanti.',
        statusCode: 503,
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
      throw ApiException(
        'Sesi berakhir, silakan login kembali.',
        statusCode: 401,
      );
    }

    final message = (decoded is Map && decoded['message'] is String)
        ? decoded['message'] as String
        : 'Terjadi kesalahan, silakan coba lagi.';

    Map<String, List<String>>? errors;
    if (decoded is Map && decoded['errors'] is Map) {
      errors = (decoded['errors'] as Map).map(
        (key, value) => MapEntry(key as String, (value as List).cast<String>()),
      );
    }

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
}
