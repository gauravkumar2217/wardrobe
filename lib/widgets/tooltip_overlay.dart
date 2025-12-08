import 'package:flutter/material.dart';
import 'dart:ui';
import '../providers/onboarding_provider.dart';

/// Tooltip overlay that highlights a target widget and shows a tooltip
class TooltipOverlay extends StatelessWidget {
  final Widget child;
  final OnboardingStep? step;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;
  final VoidCallback? onSkip;
  final bool hasMoreSteps;
  final bool hasPreviousSteps;

  const TooltipOverlay({
    super.key,
    required this.child,
    this.step,
    this.onNext,
    this.onPrevious,
    this.onSkip,
    this.hasMoreSteps = false,
    this.hasPreviousSteps = false,
  });

  @override
  Widget build(BuildContext context) {
    if (step == null) {
      return child;
    }

    return Stack(
      children: [
        child,
        // Dark overlay
        _DarkOverlay(
          targetKey: step!.targetKey,
          targetOffset: step!.targetOffset,
          targetSize: step!.targetSize,
        ),
        // Tooltip
        _TooltipWidget(
          step: step!,
          onNext: onNext,
          onPrevious: onPrevious,
          onSkip: onSkip,
          hasMoreSteps: hasMoreSteps,
          hasPreviousSteps: hasPreviousSteps,
        ),
      ],
    );
  }
}

/// Dark overlay that dims everything except the target
class _DarkOverlay extends StatelessWidget {
  final GlobalKey? targetKey;
  final Offset? targetOffset;
  final Size? targetSize;

  const _DarkOverlay({
    this.targetKey,
    this.targetOffset,
    this.targetSize,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        RenderBox? targetBox;
        Offset? targetPosition;
        Size? targetSizeValue = targetSize;

        // Try to get position from key
        if (targetKey?.currentContext != null) {
          targetBox = targetKey!.currentContext!.findRenderObject() as RenderBox?;
          if (targetBox != null && targetBox.attached) {
            targetPosition = targetBox.localToGlobal(Offset.zero);
            targetSizeValue = targetBox.size;
          }
        }

        // Fallback to manual position
        if (targetPosition == null && targetOffset != null) {
          targetPosition = targetOffset!;
        }

        if (targetPosition == null || targetSizeValue == null) {
          return const SizedBox.shrink();
        }

        return CustomPaint(
          painter: _DarkOverlayPainter(
            targetPosition: targetPosition,
            targetSize: targetSizeValue,
          ),
          size: Size(constraints.maxWidth, constraints.maxHeight),
        );
      },
    );
  }
}

/// Painter for dark overlay with hole
class _DarkOverlayPainter extends CustomPainter {
  final Offset targetPosition;
  final Size targetSize;

  _DarkOverlayPainter({
    required this.targetPosition,
    required this.targetSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw dark overlay
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;

    // Create path for entire screen
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // Create hole for target (with padding)
    final padding = 8.0;
    final hole = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            targetPosition.dx - padding,
            targetPosition.dy - padding,
            targetSize.width + (padding * 2),
            targetSize.height + (padding * 2),
          ),
          const Radius.circular(8),
        ),
      );

    // Combine paths
    final combinedPath = Path.combine(
      PathOperation.difference,
      path,
      hole,
    );

    canvas.drawPath(combinedPath, paint);
  }

  @override
  bool shouldRepaint(_DarkOverlayPainter oldDelegate) {
    return oldDelegate.targetPosition != targetPosition ||
        oldDelegate.targetSize != targetSize;
  }
}

/// Tooltip widget that shows the step information
class _TooltipWidget extends StatelessWidget {
  final OnboardingStep step;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;
  final VoidCallback? onSkip;
  final bool hasMoreSteps;
  final bool hasPreviousSteps;

  const _TooltipWidget({
    required this.step,
    this.onNext,
    this.onPrevious,
    this.onSkip,
    this.hasMoreSteps = false,
    this.hasPreviousSteps = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        RenderBox? targetBox;
        Offset? targetPosition;
        Size? targetSize;

        // Try to get position from key
        if (step.targetKey?.currentContext != null) {
          targetBox = step.targetKey!.currentContext!.findRenderObject() as RenderBox?;
          if (targetBox != null && targetBox.attached) {
            targetPosition = targetBox.localToGlobal(Offset.zero);
            targetSize = targetBox.size;
          }
        }

        // Fallback to manual position
        if (targetPosition == null && step.targetOffset != null) {
          targetPosition = step.targetOffset!;
          targetSize = step.targetSize ?? const Size(100, 100);
        }

        if (targetPosition == null || targetSize == null) {
          // Fallback: show at center
          return _buildTooltipContent(context, null, null);
        }

        // Calculate tooltip position based on alignment
        Offset tooltipPosition = _calculateTooltipPosition(
          targetPosition,
          targetSize,
          constraints,
        );

        return Positioned(
          left: tooltipPosition.dx,
          top: tooltipPosition.dy,
          child: _buildTooltipContent(context, targetPosition, targetSize),
        );
      },
    );
  }

  Offset _calculateTooltipPosition(
    Offset targetPosition,
    Size targetSize,
    BoxConstraints constraints,
  ) {
    const tooltipWidth = 300.0;
    const tooltipHeight = 200.0;
    const padding = 16.0;

    double x = 0;
    double y = 0;

    switch (step.alignment) {
      case Alignment.topCenter:
        x = targetPosition.dx + (targetSize.width / 2) - (tooltipWidth / 2);
        y = targetPosition.dy - tooltipHeight - padding;
        break;
      case Alignment.bottomCenter:
        x = targetPosition.dx + (targetSize.width / 2) - (tooltipWidth / 2);
        y = targetPosition.dy + targetSize.height + padding;
        break;
      case Alignment.centerLeft:
        x = targetPosition.dx - tooltipWidth - padding;
        y = targetPosition.dy + (targetSize.height / 2) - (tooltipHeight / 2);
        break;
      case Alignment.centerRight:
        x = targetPosition.dx + targetSize.width + padding;
        y = targetPosition.dy + (targetSize.height / 2) - (tooltipHeight / 2);
        break;
      default:
        x = targetPosition.dx + (targetSize.width / 2) - (tooltipWidth / 2);
        y = targetPosition.dy + targetSize.height + padding;
    }

    // Clamp to screen bounds
    x = x.clamp(padding, constraints.maxWidth - tooltipWidth - padding);
    y = y.clamp(padding, constraints.maxHeight - tooltipHeight - padding);

    return Offset(x, y);
  }

  Widget _buildTooltipContent(
    BuildContext context,
    Offset? targetPosition,
    Size? targetSize,
  ) {
    return Container(
      width: 300,
      constraints: const BoxConstraints(maxHeight: 200),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            step.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: Text(
              step.description,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Skip button
              TextButton(
                onPressed: onSkip,
                child: const Text(
                  'Skip',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              // Navigation buttons
              Row(
                children: [
                  if (hasPreviousSteps)
                    IconButton(
                      icon: const Icon(Icons.arrow_back, size: 20),
                      onPressed: onPrevious,
                      color: Colors.grey,
                    ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: onNext,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    child: Text(hasMoreSteps ? 'Next' : 'Got it'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

