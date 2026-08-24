class Product {

  final String id;

  final String profileId;

  final String categoryId;

  final String name;

  final String description;

  final double price;

  final int stock;

  final bool active;

  const Product({

    required this.id,

    required this.profileId,

    required this.categoryId,

    required this.name,

    required this.description,

    required this.price,

    required this.stock,

    required this.active,
  });
}