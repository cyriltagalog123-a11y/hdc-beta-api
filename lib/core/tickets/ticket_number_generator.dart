class TicketNumberGenerator {
  static int _counter = 1;

  static String nextTicketNumber() {
    final number = _counter.toString().padLeft(6, '0');

    _counter++;

    return "HDC-$number";
  }

  static void reset() {
    _counter = 1;
  }
}