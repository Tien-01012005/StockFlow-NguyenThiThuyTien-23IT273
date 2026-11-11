import 'package:cloud_firestore/cloud_firestore.dart';

enum StockStatus {
  inStock,
  lowStock,
  outOfStock,
}

class Product {
  final String id;
  final String name;
  final double price;
  final int soluong;
  final String image;

  const Product({
    required this.id,
    required this.name,
    required this.price,
    required this.soluong,
    required this.image,
  });

  factory Product.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return Product.fromMap(doc.id, data);
  }

  factory Product.fromMap(String id, Map<String, dynamic> data) {
    final rawPrice = data['price'];
    final double parsedPrice;
    if (rawPrice is num) {
      parsedPrice = rawPrice.toDouble();
    } else if (rawPrice is String) {
      parsedPrice = double.tryParse(rawPrice) ?? 0;
    } else {
      parsedPrice = 0;
    }

    final rawQty = data['soluong'];
    final int parsedQty;
    if (rawQty is num) {
      parsedQty = rawQty.toInt();
    } else if (rawQty is String) {
      parsedQty = int.tryParse(rawQty) ?? 0;
    } else {
      parsedQty = 0;
    }

    return Product(
      id: id,
      name: (data['name'] ?? '').toString(),
      price: parsedPrice < 0 ? 0 : parsedPrice,
      soluong: parsedQty < 0 ? 0 : parsedQty,
      image: (data['image'] ?? '').toString(),
    );
  }

  /// Strict 4-field map for Firestore: name, price, soluong, image only.
  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'name': name.trim(),
      'price': price,
      'soluong': soluong,
      'image': image.trim(),
    };
  }

  /// Strict 4-field map for JSON database export.
  Map<String, dynamic> toExportMap() => toFirestore();

  double get totalValue => price * soluong;

  StockStatus get stockStatus {
    if (soluong <= 0) return StockStatus.outOfStock;
    if (soluong <= 5) return StockStatus.lowStock;
    return StockStatus.inStock;
  }

  Product copyWith({
    String? id,
    String? name,
    double? price,
    int? soluong,
    String? image,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      soluong: soluong ?? this.soluong,
      image: image ?? this.image,
    );
  }
}
