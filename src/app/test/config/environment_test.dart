import 'package:flutter_test/flutter_test.dart';
import 'package:gocalgo/config/environment.dart';

void main() {
  group('Environment config', () {
    test('apiBaseUrl is a non-empty string', () {
      expect(Environment.apiBaseUrl, isNotEmpty);
    });

    test('apiBaseUrl has a valid URL format', () {
      final uri = Uri.tryParse(Environment.apiBaseUrl);
      expect(uri, isNotNull, reason: 'apiBaseUrl should be a valid URL');
      expect(uri!.hasScheme, isTrue,
          reason: 'apiBaseUrl should have a scheme (http/https)');
      expect(uri.host, isNotEmpty,
          reason: 'apiBaseUrl should have a host');
    });

    test('apiBaseUrl defaults to localhost:5000', () {
      // When no --dart-define is provided, the default is used
      expect(Environment.apiBaseUrl, equals('http://localhost:5000'));
    });

    test('apiBaseUrl is a compile-time constant', () {
      // String.fromEnvironment is a compile-time constant,
      // meaning it can be used in const contexts
      const url = Environment.apiBaseUrl;
      expect(url, isA<String>());
    });

    test('env name defaults to development', () {
      expect(Environment.name, equals('development'));
    });

    test('isDevelopment returns true by default', () {
      expect(Environment.isDevelopment, isTrue);
    });

    test('isProduction returns false by default', () {
      expect(Environment.isProduction, isFalse);
    });
  });
}
