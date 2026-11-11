import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product.dart';

class ProductService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _productsRef =>
      _db.collection('products');

  Stream<List<Product>> streamProducts() {
    return _productsRef.snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => Product.fromFirestore(doc))
          .toList();
      list.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      return list;
    });
  }

  Future<String> addProduct({
    required String name,
    required double price,
    required int soluong,
    required String image,
  }) async {
    final docRef = await _productsRef.add(<String, dynamic>{
      'name': name.trim(),
      'price': price,
      'soluong': soluong,
      'image': image.trim(),
    });
    return docRef.id;
  }

  Future<void> updateProduct(Product product) async {
    await _productsRef.doc(product.id).set(product.toFirestore());
  }

  Future<void> updateQuantity(String id, int newQuantity) async {
    final int safeQty = newQuantity < 0 ? 0 : newQuantity;
    await _productsRef.doc(id).update(<String, dynamic>{
      'soluong': safeQty,
    });
  }

  Future<void> deleteProduct(String id) async {
    await _productsRef.doc(id).delete();
  }

  /// Exports products in Firebase JSON structure while strictly keeping
  /// only the 4 required fields: name, price, soluong, image.
  static String buildExportJson(List<Product> products) {
    final Map<String, dynamic> records = <String, dynamic>{};
    for (final p in products) {
      records[p.id] = p.toExportMap();
    }
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(<String, dynamic>{'products': records});
  }
}
