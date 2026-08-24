import 'package:flutter/material.dart';

class AnimatedFadeSlide extends StatefulWidget {
  final Widget child;
  final int delay;

  const AnimatedFadeSlide({
    super.key,
    required this.child,
    this.delay = 0,
  });

  @override
  State<AnimatedFadeSlide> createState() => _AnimatedFadeSlideState();
}

class _AnimatedFadeSlideState extends State<AnimatedFadeSlide> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();

    Future.delayed(
      Duration(milliseconds: widget.delay),
      () {
        if (mounted) {
          setState(() {
            _visible = true;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 350),
      opacity: _visible ? 1 : 0,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
        offset: _visible
            ? Offset.zero
            : const Offset(0, .08),
        child: widget.child,
      ),
    );
  }
}