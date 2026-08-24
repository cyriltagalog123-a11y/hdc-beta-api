class AppConstants {
  static const int maxLoginAttempts = 5;

  static const int ticketAutoCloseDays = 7;

  static const int budgetWarningPercent = 90;

  @Deprecated('Use HDCInternalRole.owner from account_identity.dart.')
  static const String ownerRole = "Owner";

  // Beta Tester is a release cohort label, not platform/internal authority.
  static const String betaTesterRole = "Beta Tester";
}
