# Build 27 — owner-supplied GCash and Maya support QR cards

The owner supplied the two receiving cards and explicitly requested their
addition to HDC. This completes the receiving-destination placeholders on the
public **Support HDC** page. It updates the destination status recorded in the
historical [Build 25 support policy](build25-support-release-final.md).

## Behavior

- GCash displays the supplied `CY**L T.` card.
- Maya (PayMaya) displays the supplied Cyril Tagalog card, mobile ending 1505.
- Both original JPEG files are packaged with the Flutter application, without
  cropping, re-encoding, regenerating a QR, or requiring a remote image host.
- Each wallet opens its own full-screen card with pinch/scroll zoom. The page
  explains scanning, taking a screenshot on the same phone, checking the
  recipient/amount/fees in the wallet, and retaining the transaction reference.
- Contributions are voluntary PHP transfers to the personal receiving account
  shown on the card. Confirmation is manual through the existing Contact Owner
  page; HDC does not claim to verify a transfer or issue a receipt automatically.
- Repeat support is manual. No recurring subscription or wallet API is enabled.
- Supporter recognition still requires consent and grants no trust privileges.
- These receiving accounts are for HDC support. Service and marketplace
  payments continue to use the recipient agreed in their own transaction.
- Bank transfer remains unavailable. No schema, secrets, dependencies, account
  permissions, or existing customer transaction data change.

## Asset integrity and checks

Both cards decode as payment QR codes and pass their EMV payload CRC checks.
This verifies the supplied files are readable and intact, not account ownership,
provider approval, a successful transfer, or a payment settlement.

| Asset | SHA-256 |
| --- | --- |
| `assets/payments/hdc-support-gcash.jpg` | `bdfa88b16aea280c9e131765c06c0beddcd46faef7b6dfcbb7a3d3c81d514d9a` |
| `assets/payments/hdc-support-maya.jpg` | `751dec0fde0bd3f8cd16722775e8a1bc6e00121577cb95eb292aa40fe82ce869` |

Flutter checks cover loading and decoding both bundled cards, wallet-to-image
routing and return navigation at 320px and 1024px widths, and the owner-contact
action. Release markers remain Build 27. No real money was sent for testing.

This addition continues PR #36. Candidate CI and preview evidence are recorded
there. It does not bypass the outstanding final browser release check or imply
that the candidate has been deployed to production.
