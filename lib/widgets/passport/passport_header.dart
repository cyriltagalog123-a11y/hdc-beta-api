import 'package:flutter/material.dart';

class PassportHeader extends StatelessWidget {
  final String title;

  final String subtitle;

  final Widget? avatar;

  final Widget? status;

  const PassportHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.avatar,
    this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            avatar ??
                const CircleAvatar(
                  radius: 30,
                  child: Icon(
                    Icons.business,
                  ),
                ),

            const SizedBox(width: 20),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    subtitle,
                  ),
                ],
              ),
            ),

            ?status,
          ],
        ),
      ),
    );
  }
}