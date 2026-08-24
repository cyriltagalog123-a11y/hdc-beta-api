import 'package:flutter/material.dart';

class PassportSection extends StatelessWidget {

  final String title;

  final Widget child;

  const PassportSection({

    super.key,

    required this.title,

    required this.child,
  });

  @override
  Widget build(BuildContext context) {

    return Column(

      crossAxisAlignment:
          CrossAxisAlignment.start,

      children: [

        Padding(

          padding: const EdgeInsets.only(

            top: 20,

            bottom: 10,
          ),

          child: Text(

            title,

            style: const TextStyle(

              fontSize: 20,

              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ),

        child,
      ],
    );
  }
}