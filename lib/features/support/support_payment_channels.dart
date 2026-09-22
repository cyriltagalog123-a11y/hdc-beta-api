import 'package:flutter/material.dart';

import '../../core/navigation/hdc_page_route.dart';
import '../../core/ui/hdc_card.dart';
import '../../core/ui/hdc_colors.dart';

class _SupportWallet {
  final String name;
  final String recipient;
  final String asset;

  const _SupportWallet(this.name, this.recipient, this.asset);
}

// Original receiving cards supplied by the owner for voluntary HDC support.
// These destinations are not service-provider or marketplace payment accounts.
const _wallets = [
  _SupportWallet(
    'GCash',
    'CY**L T.',
    'assets/payments/hdc-support-gcash.jpg',
  ),
  _SupportWallet(
    'Maya (PayMaya)',
    'Cyril Tagalog · mobile ending 1505',
    'assets/payments/hdc-support-maya.jpg',
  ),
];

class SupportPaymentChannelsCard extends StatelessWidget {
  final VoidCallback onContactOwner;

  const SupportPaymentChannelsCard({required this.onContactOwner, super.key});

  @override
  Widget build(BuildContext context) {
    return HDCCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Support through GCash or Maya',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text(
            'Choose a wallet to view the QR supplied by the HDC owner. '
            'Contributions are voluntary, in PHP, and go to the personal '
            'receiving account shown on the card.',
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth >= 680
                  ? (constraints.maxWidth - 16) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final wallet in _wallets)
                    SizedBox(
                      width: width,
                      child: _WalletCard(wallet: wallet),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          Text('How to contribute',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text(
            '1. Open the QR card and scan it using your wallet app. '
            'You can save a screenshot if you are using the same phone.\n'
            '2. Check the recipient and amount in your wallet before '
            'confirming. Transfer fees may apply.\n'
            '3. Keep your transaction reference. Contact the owner with '
            'the wallet, amount, date, and reference if you need confirmation '
            'or would like to discuss public recognition.',
            style: TextStyle(height: 1.6),
          ),
          const SizedBox(height: 12),
          const Text(
            'HDC does not automatically confirm these transfers or create '
            'a receipt. Public recognition requires your consent. '
            'These QR codes are for supporting HDC; service and marketplace '
            'payments follow the recipient agreed in your transaction.',
            style: TextStyle(color: HDCColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onContactOwner,
            icon: const Icon(Icons.mail_outline_rounded),
            label: const Text('Contact Owner'),
          ),
          const Divider(height: 32),
          const Text(
            'Corporate sponsorship: contact the owner to discuss the '
            'arrangement. Bank transfer is not available at the moment. '
            'Automatic recurring payments are not enabled.',
            style: TextStyle(color: HDCColors.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _WalletCard extends StatelessWidget {
  final _SupportWallet wallet;

  const _WalletCard({required this.wallet});

  @override
  Widget build(BuildContext context) {
    return HDCCard(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(wallet.name, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text('Recipient: ${wallet.recipient}'),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: _QrImage(wallet: wallet),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
              HDCPageRoute<void>(page: _SupportQrScreen(wallet: wallet)),
            ),
            icon: const Icon(Icons.qr_code_rounded),
            label: Text('View ${wallet.name} QR', textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}

class _QrImage extends StatelessWidget {
  final _SupportWallet wallet;

  const _QrImage({required this.wallet});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      wallet.asset,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.none,
      semanticLabel: '${wallet.name} HDC support receiving QR. '
          'Recipient: ${wallet.recipient}.',
      errorBuilder: (context, error, stackTrace) => const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'QR image could not load. Please try again or contact the owner.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _SupportQrScreen extends StatelessWidget {
  final _SupportWallet wallet;

  const _SupportQrScreen({required this.wallet});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: Text('${wallet.name} support QR')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Confirm recipient: ${wallet.recipient}',
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 6,
                child: SizedBox.expand(
                  child: _QrImage(wallet: wallet),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Pinch or scroll to zoom. You can save a screenshot of the QR.',
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
