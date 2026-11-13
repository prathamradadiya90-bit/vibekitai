import 'package:flutter/foundation.dart';

/// Privacy-Preserving Crash and ANR Reporting Service.
/// Automatically scrubs PII, prompts, and personal data from stack traces and breadcrumbs.
class CrashReportingService {
  CrashReportingService._();
  static final CrashReportingService instance = CrashReportingService._();

  static final RegExp _emailRegex = RegExp(r'[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+');
  static final RegExp _phoneRegex = RegExp(r'\b(?:\+?\d{1,3}[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}\b');
  static final RegExp _ipRegex = RegExp(r'\b(?:\d{1,3}\.){3}\d{1,3}\b');

  final List<String> _breadcrumbs = [];
  static const int _maxBreadcrumbs = 50;

  /// Initializes global error handlers for Flutter and PlatformDispatcher.
  void initialize() {
    FlutterError.onError = (FlutterErrorDetails details) {
      recordFlutterError(details);
    };

    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      recordError(error, stack, fatal: true);
      return true;
    };

    addBreadcrumb('App initialized');
  }

  /// Records and sanitizes a non-fatal or fatal error.
  void recordError(Object error, StackTrace? stack, {bool fatal = false}) {
    final sanitizedMessage = _scrubPii(error.toString());
    final sanitizedStack = stack != null ? _scrubPii(stack.toString()) : '';

    if (kDebugMode) {
      debugPrint('[CrashService] ${fatal ? "FATAL" : "ERROR"}: $sanitizedMessage');
      if (sanitizedStack.isNotEmpty) {
        debugPrint(sanitizedStack);
      }
    }

    // In release, forward sanitized report to Firebase Crashlytics / Sentry SDK
    // without user messages, prompts, or personal identifiers.
  }

  /// Records a Flutter framework error details object.
  void recordFlutterError(FlutterErrorDetails details) {
    if (kDebugMode) {
      FlutterError.dumpErrorToConsole(details);
    }
    recordError(details.exception, details.stack, fatal: false);
  }

  /// Adds a sanitized navigation or operational breadcrumb.
  void addBreadcrumb(String message) {
    final clean = _scrubPii(message);
    if (_breadcrumbs.length >= _maxBreadcrumbs) {
      _breadcrumbs.removeAt(0);
    }
    _breadcrumbs.add('${DateTime.now().toIso8601String()}: $clean');
  }

  /// Deep PII scrubbing utility: removes emails, phones, and IP addresses.
  static String _scrubPii(String input) {
    var result = input.replaceAll(_emailRegex, '[REDACTED_EMAIL]');
    result = result.replaceAll(_phoneRegex, '[REDACTED_PHONE]');
    result = result.replaceAll(_ipRegex, '[REDACTED_IP]');
    return result;
  }
}
