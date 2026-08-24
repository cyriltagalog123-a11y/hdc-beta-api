import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {

  final String text;

  final Color color;

  const StatusBadge({

    super.key,

    required this.text,

    required this.color,
  });

  @override
  Widget build(BuildContext context) {

    return Chip(

      label: Text(

        text,

        style: const TextStyle(
          color: Colors.white,
        ),
      ),

      backgroundColor: color,
    );
  }
}