import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/ui/hdc_colors.dart';
import '../../providers/hdc_marketplace_provider.dart';

class SellerPublicProfileScreen extends StatefulWidget {
  final String profileId;

  const SellerPublicProfileScreen({required this.profileId, super.key});

  @override
  State<SellerPublicProfileScreen> createState() =>
      _SellerPublicProfileScreenState();
}

class _SellerPublicProfileScreenState extends State<SellerPublicProfileScreen> {
  late Future<Map<String, dynamic>> _profile;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    final client = context.read<HdcMarketplaceProvider>().client;
    _profile = client == null
        ? Future<Map<String, dynamic>>.error(
            StateError('The public seller profile is unavailable.'))
        : client.getPublic('/api/commerce/sellers/${widget.profileId}');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: HDCColors.background,
        appBar: AppBar(title: const Text('Seller profile')),
        body: FutureBuilder<Map<String, dynamic>>(
          future: _profile,
          builder: (context, snapshot) {
            if (!snapshot.hasData && !snapshot.hasError) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || snapshot.data?['profile'] is! Map) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('This seller profile is no longer public.'),
                    TextButton(
                      onPressed: () => setState(_refresh),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }
            final profile = Map<String, dynamic>.from(snapshot.data!['profile'] as Map);
            final name = '${profile['publicName'] ?? ''}';
            final headline = '${profile['headline'] ?? ''}'.trim();
            final description = '${profile['description'] ?? ''}'.trim();
            final location = '${profile['location'] ?? ''}'.trim();
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: Theme.of(context).textTheme.headlineSmall),
                          if (headline.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(headline),
                          ],
                          if (location.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(location, style: const TextStyle(
                              color: HDCColors.textSecondary,
                            )),
                          ],
                          if (description.isNotEmpty) ...[
                            const Divider(height: 36),
                            SelectableText(description),
                          ],
                          const SizedBox(height: 18),
                          const Text(
                            'This profile shows only the fields the seller made public. A listing and profile do not verify payment or warranty claims.',
                            style: TextStyle(color: HDCColors.textSecondary),
                          ),
                        ],
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
