import 'package:flutter/material.dart';

class StaggeredFadeIn extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration duration;
  final Duration baseDelay;
  final Curve curve;
  final double slideY;

  const StaggeredFadeIn({
    super.key,
    required this.child,
    required this.index,
    this.duration = const Duration(milliseconds: 550),
    this.baseDelay = const Duration(milliseconds: 70),
    this.curve = Curves.easeOutCubic,
    this.slideY = 14,
  });

  @override
  State<StaggeredFadeIn> createState() => _StaggeredFadeInState();
}

class _StaggeredFadeInState extends State<StaggeredFadeIn> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.baseDelay * widget.index, () {
      if (!mounted) return;
      setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: widget.duration,
      curve: widget.curve,
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : Offset(0, widget.slideY / 100),
        duration: widget.duration,
        curve: widget.curve,
        child: widget.child,
      ),
    );
  }
}

