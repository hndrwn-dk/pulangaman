import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';

class ApiException implements Exception {
  ApiException(this.statusCode, this.body);
  final int statusCode;
  final String body;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => 'ApiException($statusCode): $body';
}

typedef TokenRefresher = Future<String?> Function();

class ApiClient {
  ApiClient({http.Client? client, String? baseUrl, this.refreshToken})
      : _client = client ?? http.Client(),
        baseUrl = baseUrl ?? AppConfig.apiBaseUrl;

  final http.Client _client;
  final String baseUrl;
  String? _token;

  /// Called once after a 401 to obtain a fresh bearer token and retry.
  TokenRefresher? refreshToken;

  void setToken(String? token) {
    _token = token;
  }

  String? get token => _token;

  Map<String, String> get _headers => {
        'content-type': 'application/json',
        if (_token != null && _token!.isNotEmpty)
          'authorization': 'Bearer $_token',
      };

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) {
    return _send(
      () => _client.post(
        Uri.parse('$baseUrl$path'),
        headers: _headers,
        body: body == null ? null : jsonEncode(body),
      ),
    );
  }

  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
  }) {
    return _send(
      () => _client.put(
        Uri.parse('$baseUrl$path'),
        headers: _headers,
        body: body == null ? null : jsonEncode(body),
      ),
    );
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
  }) {
    return _send(
      () => _client.patch(
        Uri.parse('$baseUrl$path'),
        headers: _headers,
        body: body == null ? null : jsonEncode(body),
      ),
    );
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
    Duration timeout = const Duration(seconds: 25),
  }) {
    final uri = query == null
        ? Uri.parse('$baseUrl$path')
        : Uri.parse('$baseUrl$path').replace(queryParameters: query);
    return _send(() => _client.get(uri, headers: _headers).timeout(timeout));
  }

  Future<Map<String, dynamic>> delete(String path) {
    return _send(
      () => _client.delete(
        Uri.parse('$baseUrl$path'),
        headers: _headers,
      ),
    );
  }

  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function() request, {
    bool didRefresh = false,
  }) async {
    final response = await request();
    if (response.statusCode == 401 && !didRefresh && refreshToken != null) {
      final fresh = await refreshToken!();
      if (fresh != null && fresh.isNotEmpty) {
        _token = fresh;
        return _send(request, didRefresh: true);
      }
    }
    return _decode(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.statusCode >= 400) {
      throw ApiException(response.statusCode, response.body);
    }
    if (response.body.isEmpty) {
      return {'ok': true};
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return {'data': decoded};
  }
}
