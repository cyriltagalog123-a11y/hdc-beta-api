class UserGreetingService {
  const UserGreetingService();

  String greeting({
    required String displayName,
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();
    final name = displayName.trim().isEmpty ? 'there' : displayName.trim();

    if (currentTime.hour < 12) {
      return 'Good morning, $name';
    }

    if (currentTime.hour < 18) {
      return 'Good afternoon, $name';
    }

    return 'Good evening, $name';
  }

  String returningMessage({
    int activeTransactions = 0,
    int newOffers = 0,
  }) {
    if (activeTransactions > 0 && newOffers > 0) {
      return 'You have $activeTransactions active '
          '${activeTransactions == 1 ? 'transaction' : 'transactions'} and '
          '$newOffers new ${newOffers == 1 ? 'offer' : 'offers'}.';
    }

    if (activeTransactions > 0) {
      return 'You have $activeTransactions active '
          '${activeTransactions == 1 ? 'transaction' : 'transactions'} '
          'to review.';
    }

    if (newOffers > 0) {
      return 'You have $newOffers new '
          '${newOffers == 1 ? 'offer' : 'offers'} waiting.';
    }

    return 'Welcome back. Manage your requests, bookings, and HDC activity '
        'from one place.';
  }
}
