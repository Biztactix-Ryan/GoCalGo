import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/environment.dart';

/// HTTP client wrapper for backend API communication.
///
/// Provides a centralised place for base URL resolution, headers,
/// and JSON response handling.
class ApiClient {
  final http.Client _httpClient;
  final String _baseUrl;

  ApiClient({http.Client? httpClient, String? baseUrl})
      : _httpClient = httpClient ?? http.Client(),
        _baseUrl = baseUrl ?? Environment.apiBaseUrl;

  /// Sends a GET request to [path] and decodes the JSON response body.
  Future<dynamic> get(String path) async {
    final uri = Uri.parse('$_baseUrl$path');
    final response = await _httpClient.get(uri, headers: _headers);
    return _handleResponse(response);
  }

  /// Sends a POST request to [path] with a JSON [body] and decodes the response.
  Future<dynamic> post(String path, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$_baseUrl$path');
    final response = await _httpClient.post(
      uri,
      headers: _headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response);
  }

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    }
    throw ApiException(response.statusCode, response.body);
  }

  void dispose() {
    _httpClient.close();
  }
}

/// Exception thrown when the API returns a non-2xx status code.
class ApiException implements Exception {
  final int statusCode;
  final String body;

  const ApiException(this.statusCode, this.body);

  @override
  String toString() => 'ApiException($statusCode): $body';
}
