import 'package:flutter/material.dart';

class HDCPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  HDCPageRoute({
    required this.page,
  }) : super(
          transitionDuration: const Duration(milliseconds: 250),
          reverseTransitionDuration: const Duration(milliseconds: 250),
          pageBuilder: (
            context,
            animation,
            secondaryAnimation,
          ) {
            return page;
          },
          transitionsBuilder: (
            context,
            animation,
            secondaryAnimation,
            child,
          ) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;

            const curve = Curves.easeOutCubic;

            final tween = Tween(
              begin: begin,
              end: end,
            ).chain(
              CurveTween(curve: curve),
            );

            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
        );
}