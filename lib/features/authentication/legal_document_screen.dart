import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/ui/hdc_colors.dart';
import '../../models/legal_document.dart';

class LegalDocumentScreen extends StatelessWidget {
  final HDCLegalDocument document;

  const LegalDocumentScreen({required this.document, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HDCColors.background,
      appBar: AppBar(title: Text(document.shortTitle)),
      body: FutureBuilder<String>(
        future: rootBundle.loadString(document.assetPath),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'HDC could not load this legal document. Do not accept it '
                  'until the complete text is available.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final text = snapshot.data;
          if (text == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return SelectionArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 860),
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Text(
                        text,
                        style: const TextStyle(
                          color: HDCColors.textPrimary,
                          fontSize: 15,
                          height: 1.55,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
