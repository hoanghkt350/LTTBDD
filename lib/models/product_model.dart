class Product {
  final String id;
  final String name;
  final String category; // 'FOOD', 'ACCESSORY', 'TOY', 'HEALTH', 'HYGIENE'
  final String petTarget; // 'DOG', 'CAT', 'ALL'
  final double price;
  final double originalPrice;
  final int discountPercent;
  final int stock;
  final double rating;
  final int reviewCount;
  final String imageUrl;
  final String description;
  final String weight;
  final bool isFeatured;

  Product({
    required this.id,
    required this.name,
    required this.category,
    required this.petTarget,
    required this.price,
    required this.originalPrice,
    this.discountPercent = 0,
    required this.stock,
    this.rating = 5.0,
    this.reviewCount = 0,
    required this.imageUrl,
    required this.description,
    this.weight = '1kg',
    this.isFeatured = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'petTarget': petTarget,
      'price': price,
      'originalPrice': originalPrice,
      'discountPercent': discountPercent,
      'stock': stock,
      'rating': rating,
      'reviewCount': reviewCount,
      'imageUrl': imageUrl,
      'description': description,
      'weight': weight,
      'isFeatured': isFeatured,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) => Product.fromJson(map);
  Map<String, dynamic> toMap() => toJson();

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      petTarget: json['petTarget'] as String,
      price: (json['price'] as num).toDouble(),
      originalPrice: (json['originalPrice'] as num).toDouble(),
      discountPercent: (json['discountPercent'] as num?)?.toInt() ?? 0,
      stock: (json['stock'] as num).toInt(),
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
      imageUrl: json['imageUrl'] as String,
      description: json['description'] as String,
      weight: (json['weight'] as String?) ?? '1kg',
      isFeatured: (json['isFeatured'] as bool?) ?? false,
    );
  }
}
