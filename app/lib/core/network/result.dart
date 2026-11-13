import 'api_exception.dart';

/// Sealed class representing the result of an asynchronous operation or API call.
sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  T? get dataOrNull => switch (this) {
        Success(data: final d) => d,
        Failure() => null,
      };

  ApiException? get errorOrNull => switch (this) {
        Success() => null,
        Failure(error: final e) => e,
      };

  R when<R>({
    required R Function(T data) success,
    required R Function(ApiException error) failure,
  }) {
    return switch (this) {
      Success(data: final d) => success(d),
      Failure(error: final e) => failure(e),
    };
  }

  Result<R> map<R>(R Function(T data) transform) {
    return switch (this) {
      Success(data: final d) => Success(transform(d)),
      Failure(error: final e) => Failure(e),
    };
  }
}

class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);

  @override
  String toString() => 'Result.Success($data)';
}

class Failure<T> extends Result<T> {
  final ApiException error;
  const Failure(this.error);

  @override
  String toString() => 'Result.Failure(${error.code}: ${error.message})';
}
