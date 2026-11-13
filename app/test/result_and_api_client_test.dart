import 'package:flutter_test/flutter_test.dart';
import 'package:vibekit_ai/core/network/api_exception.dart';
import 'package:vibekit_ai/core/network/result.dart';

void main() {
  group('Result<T> Pattern & Functional Handlers', () {
    test('Success variant encapsulates data and transforms via map', () {
      const Result<int> result = Success(42);

      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
      expect(result.dataOrNull, equals(42));
      expect(result.errorOrNull, isNull);

      final mapped = result.map((val) => 'Value: $val');
      expect(mapped.isSuccess, isTrue);
      expect(mapped.dataOrNull, equals('Value: 42'));
    });

    test('Failure variant encapsulates ApiException and preserves error in map', () {
      const error = ApiException(
        code: 'QUOTA_EXCEEDED',
        message: 'Daily credits exhausted',
        statusCode: 429,
      );
      const Result<int> result = Failure(error);

      expect(result.isSuccess, isFalse);
      expect(result.isFailure, isTrue);
      expect(result.dataOrNull, isNull);
      expect(result.errorOrNull?.code, equals('QUOTA_EXCEEDED'));

      final mapped = result.map((val) => 'Value: $val');
      expect(mapped.isFailure, isTrue);
      expect(mapped.errorOrNull?.statusCode, equals(429));
    });

    test('when pattern-matches exhaustively between success and failure', () {
      const Result<String> success = Success('vibes');
      final successOutput = success.when(
        success: (d) => 'Received: $d',
        failure: (e) => 'Failed: ${e.code}',
      );
      expect(successOutput, equals('Received: vibes'));

      const Result<String> failure = Failure(ApiException(
        code: 'TIMEOUT',
        message: 'Request timed out',
        statusCode: 408,
      ));
      final failureOutput = failure.when(
        success: (d) => 'Received: $d',
        failure: (e) => 'Failed: ${e.code}',
      );
      expect(failureOutput, equals('Failed: TIMEOUT'));
    });
  });
}
