import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:gocalgo/services/api_client.dart';

void main() {
  group('ApiClient', () {
    test('get() decodes JSON response on success', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), 'http://test.local/events');
        expect(request.headers['Accept'], 'application/json');
        return http.Response(
          jsonEncode({'events': [], 'lastUpdated': '2026-01-01T00:00:00Z', 'cacheHit': false}),
          200,
        );
      });

      final apiClient = ApiClient(httpClient: mockClient, baseUrl: 'http://test.local');
      final result = await apiClient.get('/events') as Map<String, dynamic>;

      expect(result['events'], isEmpty);
      expect(result['cacheHit'], false);
    });

    test('get() throws ApiException on non-2xx response', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Not Found', 404);
      });

      final apiClient = ApiClient(httpClient: mockClient, baseUrl: 'http://test.local');

      expect(
        () => apiClient.get('/missing'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 404)),
      );
    });
  });
}
