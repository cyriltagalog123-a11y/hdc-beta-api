enum PlatformEventType {
  organizationCreated,
  brandCreated,
  regionCreated,
  storeCreated,

  assetRegistered,
  assetAssigned,

  ticketCreated,
  ticketAccepted,
  ticketCompleted,

  employeeInvited,

  marketplaceOrder,

  system,
}

class PlatformEvent {
  final String id;

  final PlatformEventType type;

  final String title;

  final String description;

  final DateTime timestamp;

  const PlatformEvent({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.timestamp,
  });
}