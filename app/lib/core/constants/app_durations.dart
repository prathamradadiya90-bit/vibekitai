import 'package:flutter/material.dart';

/// Centralized animation durations and easing curves for ReplyVibe AI.
class AppDurations {
  AppDurations._();

  static const Duration press = Duration(milliseconds: 90);
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration normal = Duration(milliseconds: 260);
  static const Duration medium = Duration(milliseconds: 340);
  static const Duration slow = Duration(milliseconds: 480);
  static const Duration chart = Duration(milliseconds: 650);
  static const Duration shimmer = Duration(milliseconds: 1400);
}

/// Tactile, espresso-inspired animation curves for consistent motion physics.
class AppCurves {
  AppCurves._();

  /// Instant finger-down compression feedback on cards and pills.
  static const Curve tactilePress = Curves.easeOutQuad;

  /// Smooth, unhurried deceleration for routes, tab pills, and card reveals.
  static const Curve espressoPour = Cubic(0.22, 1.0, 0.36, 1.0);

  /// Joyful subtle overshoot exclusively for celebratory pops (hearts, badges, rewards).
  static const Curve cremaSpring = Cubic(0.34, 1.56, 0.64, 1.0);

  /// Gentle organic oscillation for ambient shimmers and status halos.
  static const Curve ambientBreath = Curves.easeInOutSine;
}
