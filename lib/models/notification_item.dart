class NotificationItem {

  final String id;

  final String title;

  final String message;

  final DateTime createdAt;

  final bool read;

  final String category;

  const NotificationItem({

    required this.id,

    required this.title,

    required this.message,

    required this.createdAt,

    required this.read,

    required this.category,
  });

  NotificationItem copyWith({

    bool? read,

  }) {

    return NotificationItem(

      id: id,

      title: title,

      message: message,

      createdAt: createdAt,

      read: read ?? this.read,

      category: category,
    );
  }
}