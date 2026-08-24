import 'dart:math';

class TicketGenerator {
  TicketGenerator._();

  static const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static final Random _secureRandom = Random.secure();

  static String generateTicketId() {
    final timestamp = DateTime.now().toUtc().microsecondsSinceEpoch;
    final entropy = List<String>.generate(
      8,
      (_) => _alphabet[_secureRandom.nextInt(_alphabet.length)],
      growable: false,
    ).join();
    return 'HDC-$timestamp-$entropy';
  }
}
