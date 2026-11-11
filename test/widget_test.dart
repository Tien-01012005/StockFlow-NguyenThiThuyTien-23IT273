import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockflow_admin/models/product.dart';
import 'package:stockflow_admin/services/product_service.dart';

void main() {
  group('Product model & strict 4-field schema', () {
    test('toFirestore contains strictly name, price, soluong, image', () {
      const product = Product(
        id: 'doc_1',
        name: '  Chuột Logitech MX Master 3S  ',
        price: 2490000,
        soluong: 12,
        image: 'https://example.com/mouse.jpg',
      );

      final map = product.toFirestore();
      expect(map.keys.toSet(), equals(<String>{'name', 'price', 'soluong', 'image'}));
      expect(map['name'], 'Chuột Logitech MX Master 3S');
      expect(map['price'], 2490000);
      expect(map['soluong'], 12);
      expect(map['image'], 'https://example.com/mouse.jpg');
    });

    test('fromMap parses numeric and string fields safely', () {
      final p = Product.fromMap('doc_2', <String, dynamic>{
        'name': 'Bàn phím cơ',
        'price': 1850000,
        'soluong': 4,
        'image': 'https://example.com/kb.jpg',
      });

      expect(p.id, 'doc_2');
      expect(p.price, 1850000);
      expect(p.soluong, 4);
      expect(p.stockStatus, StockStatus.lowStock);
      expect(p.totalValue, 7400000);
    });

    test('buildExportJson outputs valid JSON with strictly 4 fields per item', () {
      const items = <Product>[
        Product(
          id: 'p1',
          name: 'Tai nghe Sony',
          price: 5900000,
          soluong: 0,
          image: 'https://example.com/sony.jpg',
        ),
      ];

      final raw = ProductService.buildExportJson(items);
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final products = decoded['products'] as Map<String, dynamic>;
      final item = products['p1'] as Map<String, dynamic>;

      expect(item.keys.toSet(), equals(<String>{'name', 'price', 'soluong', 'image'}));
      expect(items.first.stockStatus, StockStatus.outOfStock);
    });
  });
}
