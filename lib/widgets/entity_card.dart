import 'package:flutter/material.dart';

class EntityCard extends StatelessWidget {

  final String title;

  final String subtitle;

  final Widget? leading;

  final Widget? trailing;

  final VoidCallback? onTap;

  const EntityCard({

    super.key,

    required this.title,

    required this.subtitle,

    this.leading,

    this.trailing,

    this.onTap,
  });

  @override
  Widget build(BuildContext context) {

    return Card(

      child: ListTile(

        leading: leading,

        title: Text(

          title,

          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),

        subtitle: Text(subtitle),

        trailing: trailing,

        onTap: onTap,
      ),
    );
  }
}