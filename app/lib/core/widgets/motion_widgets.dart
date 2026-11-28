import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/app_durations.dart';

/// Adds immediate spring-like scale compression when the user presses down.
/// Uses a passive [Listener] so inner [InkWell], buttons, and scrolling never conflict.
class TactileScale extends StatefulWidget {
  final Widget child;
  final double pressedScale;
  final bool enabled;

  const TactileScale({
    super.key,
    required this.child,
    this.pressedScale = 0.965,
    this.enabled = true,
  });

  @override
  State<TactileScale> createState() => _TactileScaleState();
}

class _TactileScaleState extends State<TactileScale> {
  bool _isPressed = false;

  void _setPressed(bool pressed) {
    if (!widget.enabled || _isPressed == pressed) return;
    setState(() => _isPressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: (_isPressed && !reduceMotion) ? widget.pressedScale : 1.0,
        duration: reduceMotion
            ? Duration.zero
            : (_isPressed ? AppDurations.press : AppDurations.fast),
        curve: _isPressed ? AppCurves.tactilePress : AppCurves.espressoPour,
        child: widget.child,
      ),
    );
  }
}

/// Gliding segmented mode switcher with a single smooth sliding pill thumb.
class SlidingSegmentedPill<T> extends StatelessWidget {
  final List<T> items;
  final T selectedItem;
  final String Function(T item) labelBuilder;
  final IconData Function(T item)? iconBuilder;
  final ValueChanged<T> onSelected;
  final double height;

  const SlidingSegmentedPill({
    super.key,
    required this.items,
    required this.selectedItem,
    required this.labelBuilder,
    required this.onSelected,
    this.iconBuilder,
    this.height = 42,
  });

  @override
  Widget build(BuildContext context) {
    assert(items.length >= 2, 'SlidingSegmentedPill requires at least 2 items.');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final selectedIndex = items.indexOf(selectedItem).clamp(0, items.length - 1);
    final alignX = items.length <= 1
        ? 0.0
        : -1.0 + (2.0 * selectedIndex / (items.length - 1));

    return Container(
      height: height,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceCardDark : AppColors.surfaceCardLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              // Single gliding surface thumb
              AnimatedAlign(
                alignment: Alignment(alignX, 0),
                duration: reduceMotion ? Duration.zero : AppDurations.normal,
                curve: AppCurves.espressoPour,
                child: FractionallySizedBox(
                  widthFactor: 1 / items.length,
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceElevatedDark : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? AppColors.accent.withValues(alpha: 0.25)
                            : Colors.black.withValues(alpha: 0.04),
                        width: 0.8,
                      ),
                      boxShadow: isDark
                          ? null
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 6,
                                offset: const Offset(0, 1),
                              ),
                            ],
                    ),
                  ),
                ),
              ),
              // Foreground interactive labels
              Row(
                children: items.map((item) {
                  final isSelected = item == selectedItem;
                  final icon = iconBuilder?.call(item);
                  final activeColor =
                      isDark ? AppColors.accentWarm : AppColors.primary;
                  final inactiveColor = isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight;

                  return Expanded(
                    child: Semantics(
                      selected: isSelected,
                      button: true,
                      child: InkWell(
                        onTap: () {
                          if (!isSelected) {
                            HapticFeedback.selectionClick();
                          }
                          onSelected(item);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (icon != null) ...[
                                  Icon(
                                    icon,
                                    size: 15,
                                    color:
                                        isSelected ? activeColor : inactiveColor,
                                  ),
                                  const SizedBox(width: 5),
                                ],
                                Flexible(
                                  child: AnimatedDefaultTextStyle(
                                    duration: reduceMotion
                                        ? Duration.zero
                                        : AppDurations.fast,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? activeColor
                                          : inactiveColor,
                                    ),
                                    child: Text(
                                      labelBuilder(item),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Finite, timer-free staggered entrance animation using [Interval] easing.
/// Safely settles in tests and automatically collapses under Reduced Motion.
class StaggeredEntrance extends StatelessWidget {
  final int index;
  final Widget child;
  final double offsetY;
  final int stepMs;

  const StaggeredEntrance({
    super.key,
    required this.index,
    required this.child,
    this.offsetY = 14.0,
    this.stepMs = 55,
  });

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) return child;

    final clampedIndex = index.clamp(0, 6);
    final delayMs = clampedIndex * stepMs;
    const bodyMs = 260;
    final totalMs = delayMs + bodyMs;
    final startFrac = delayMs / totalMs;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: totalMs),
      curve: Interval(startFrac, 1.0, curve: AppCurves.espressoPour),
      builder: (context, progress, innerChild) {
        return Opacity(
          opacity: progress,
          child: Transform.translate(
            offset: Offset(0, offsetY * (1.0 - progress)),
            child: innerChild,
          ),
        );
      },
      child: child,
    );
  }
}

/// Smoothly sweeps a rounded progress bar from 0 to [value] using [AppCurves.espressoPour].
class AnimatedProgressBar extends StatelessWidget {
  final double value;
  final double minHeight;
  final Color color;
  final Color backgroundColor;
  final BorderRadius? borderRadius;

  const AnimatedProgressBar({
    super.key,
    required this.value,
    required this.color,
    required this.backgroundColor,
    this.minHeight = 6,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final target = value.clamp(0.0, 1.0);
    final radius = borderRadius ?? BorderRadius.circular(minHeight);

    return ClipRRect(
      borderRadius: radius,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.0, end: target),
        duration: reduceMotion ? Duration.zero : AppDurations.chart,
        curve: AppCurves.espressoPour,
        builder: (context, animatedValue, _) {
          return LinearProgressIndicator(
            value: animatedValue,
            minHeight: minHeight,
            backgroundColor: backgroundColor,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          );
        },
      ),
    );
  }
}
