import 'package:flutter/material.dart';
import 'dart:ui';
import '../providers/onboarding_provider.dart';

/// Tooltip overlay that highlights a target widget and shows a tooltip
class TooltipOverlay extends StatefulWidget {
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
  State<TooltipOverlay> createState() => _TooltipOverlayState();
}

class _TooltipOverlayState extends State<TooltipOverlay> {
  Offset? _targetPosition;
  Size? _targetSize;

  @override
  void initState() {
    super.initState();
    _updateTargetPosition();
  }

  @override
  void didUpdateWidget(TooltipOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.step?.id != widget.step?.id) {
      _updateTargetPosition();
    }
  }

  void _updateTargetPosition() {
    if (widget.step == null) return;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.step == null) return;
      
      // Try to get position from key
      if (widget.step!.targetKey?.currentContext != null) {
        final RenderBox? targetBox = widget.step!.targetKey!.currentContext!
            .findRenderObject() as RenderBox?;
        if (targetBox != null && targetBox.attached) {
          setState(() {
            _targetPosition = targetBox.localToGlobal(Offset.zero);
            _targetSize = targetBox.size;
          });
          return;
        }
      }

      // Fallback to manual position
      if (widget.step!.targetOffset != null) {
        setState(() {
          _targetPosition = widget.step!.targetOffset;
          _targetSize = widget.step!.targetSize ?? const Size(80, 80);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.step == null) {
      return widget.child;
    }

    return Stack(
      children: [
        widget.child,
        // Dark overlay
        if (_targetPosition != null && _targetSize != null)
          _DarkOverlay(
            targetPosition: _targetPosition!,
            targetSize: _targetSize!,
          ),
        // Tooltip - always show at bottom center above navigation
        _TooltipWidget(
          step: widget.step!,
          onNext: widget.onNext,
          onPrevious: widget.onPrevious,
          onSkip: widget.onSkip,
          hasMoreSteps: widget.hasMoreSteps,
          hasPreviousSteps: widget.hasPreviousSteps,
          targetPosition: _targetPosition,
          targetSize: _targetSize,
        ),
      ],
    );
  }
}

/// Dark overlay that dims everything except the target
class _DarkOverlay extends StatelessWidget {
  final Offset targetPosition;
  final Size targetSize;

  const _DarkOverlay({
    required this.targetPosition,
    required this.targetSize,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          painter: _DarkOverlayPainter(
            targetPosition: targetPosition,
            targetSize: targetSize,
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

    // Responsive padding based on target size
    final padding = (targetSize.width * 0.15).clamp(10.0, 14.0);
    final borderRadius = (targetSize.width * 0.2).clamp(12.0, 18.0);
    
    // Create hole for target (with padding)
    final hole = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            targetPosition.dx - padding,
            targetPosition.dy - padding,
            targetSize.width + (padding * 2),
            targetSize.height + (padding * 2),
          ),
          Radius.circular(borderRadius),
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
  final Offset? targetPosition;
  final Size? targetSize;

  const _TooltipWidget({
    required this.step,
    this.onNext,
    this.onPrevious,
    this.onSkip,
    this.hasMoreSteps = false,
    this.hasPreviousSteps = false,
    this.targetPosition,
    this.targetSize,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final textScaleFactor = MediaQuery.of(context).textScaleFactor.clamp(0.8, 1.2);
    
    // Responsive tooltip dimensions
    final tooltipWidth = (screenWidth * 0.9).clamp(280.0, 360.0);
    final tooltipHeight = (screenHeight * 0.25).clamp(160.0, 220.0);
    const bottomNavHeight = 60.0;
    final padding = (screenWidth * 0.04).clamp(12.0, 20.0);
    
    // Position tooltip above bottom navigation bar
    // If target is at bottom (navigation items), show tooltip above it
    // Otherwise show at bottom center of screen
    double tooltipY;
    if (targetPosition != null && 
        targetPosition!.dy > screenHeight - 150) {
      // Target is near bottom (navigation bar)
      tooltipY = targetPosition!.dy - tooltipHeight - padding - 16;
    } else {
      // Show at bottom center, above navigation
      tooltipY = screenHeight - bottomNavHeight - tooltipHeight - padding - 16;
    }
    
    // Center horizontally
    final tooltipX = (screenWidth - tooltipWidth) / 2;

    return Positioned(
      left: tooltipX.clamp(padding, screenWidth - tooltipWidth - padding),
      top: tooltipY.clamp(padding, screenHeight - tooltipHeight - padding),
      child: _buildTooltipContent(context, tooltipWidth, tooltipHeight, textScaleFactor),
    );
  }

  Widget _buildTooltipContent(BuildContext context, double width, double maxHeight, double textScaleFactor) {
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = (screenWidth * 0.05).clamp(12.0, 20.0);
    final verticalPadding = (screenWidth * 0.03).clamp(10.0, 16.0);
    final borderRadius = (screenWidth * 0.05).clamp(16.0, 20.0);
    
    return Container(
      width: width,
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with gradient
          Container(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              verticalPadding + 4,
              horizontalPadding,
              verticalPadding - 2,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF7C3AED),
                  const Color(0xFF7C3AED).withValues(alpha: 0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(borderRadius),
                topRight: Radius.circular(borderRadius),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    step.title,
                    style: TextStyle(
                      fontSize: (14 * textScaleFactor).clamp(13.0, 16.0),
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                // Step indicator
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: (screenWidth * 0.025).clamp(8.0, 12.0),
                    vertical: (screenWidth * 0.01).clamp(3.0, 6.0),
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    step.id[0].toUpperCase(),
                    style: TextStyle(
                      fontSize: (11 * textScaleFactor).clamp(10.0, 12.0),
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Content
          Flexible(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  verticalPadding - 2,
                  horizontalPadding,
                  verticalPadding - 4,
                ),
                child: Text(
                  step.description,
                  style: TextStyle(
                    fontSize: (13 * textScaleFactor).clamp(12.0, 14.0),
                    color: Colors.black87,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ),
          // Buttons
          Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              0,
              horizontalPadding,
              verticalPadding,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Skip button
                TextButton(
                  onPressed: onSkip,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: (screenWidth * 0.04).clamp(12.0, 16.0),
                      vertical: (screenWidth * 0.02).clamp(6.0, 10.0),
                    ),
                  ),
                  child: Text(
                    'Skip',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: (13 * textScaleFactor).clamp(12.0, 14.0),
                    ),
                  ),
                ),
                // Navigation buttons
                Row(
                  children: [
                    if (hasPreviousSteps)
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back,
                          size: (18 * textScaleFactor).clamp(16.0, 20.0),
                        ),
                        onPressed: onPrevious,
                        color: Colors.grey[600],
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    if (hasPreviousSteps) SizedBox(
                      width: (screenWidth * 0.03).clamp(8.0, 12.0),
                    ),
                    ElevatedButton(
                      onPressed: onNext,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: (screenWidth * 0.06).clamp(20.0, 24.0),
                          vertical: (screenWidth * 0.03).clamp(10.0, 12.0),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        hasMoreSteps ? 'Next' : 'Got it',
                        style: TextStyle(
                          fontSize: (13 * textScaleFactor).clamp(12.0, 14.0),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

