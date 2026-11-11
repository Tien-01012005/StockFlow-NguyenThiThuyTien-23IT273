import 'package:flutter/material.dart';
import '../models/product.dart';
import '../utils/formatters.dart';
import '../utils/image_helper.dart';

class ProductDetailDialog extends StatelessWidget {
  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ProductDetailDialog({
    super.key,
    required this.product,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final (String statusLabel, Color statusBg, Color statusFg) =
        switch (product.stockStatus) {
      StockStatus.outOfStock => (
          'Hết hàng',
          colors.errorContainer,
          colors.onErrorContainer,
        ),
      StockStatus.lowStock => (
          'Sắp hết hàng',
          const Color(0xFFFEF3C7),
          const Color(0xFF92400E),
        ),
      StockStatus.inStock => (
          'Còn hàng',
          const Color(0xFFDCFCE7),
          const Color(0xFF166534),
        ),
    };

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Chi tiết sản phẩm',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ProductImageWidget(
                imageUrl: product.image,
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
                borderRadius: BorderRadius.circular(14),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      product.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusFg,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.outlineVariant),
                ),
                child: Column(
                  children: <Widget>[
                    _infoRow(
                      context,
                      'Mã Document (Firestore)',
                      product.id,
                    ),
                    const Divider(height: 16),
                    _infoRow(
                      context,
                      'Đơn giá (price)',
                      AppFormatters.formatPrice(product.price),
                      highlight: true,
                    ),
                    const Divider(height: 16),
                    _infoRow(
                      context,
                      'Số lượng tồn (soluong)',
                      '${AppFormatters.formatNumber(product.soluong)} sản phẩm',
                    ),
                    const Divider(height: 16),
                    _infoRow(
                      context,
                      'Tổng giá trị tồn',
                      AppFormatters.formatPrice(product.totalValue),
                    ),
                    const Divider(height: 16),
                    _infoRow(
                      context,
                      'Nguồn ảnh (image)',
                      ImageHelper.describeImageSource(product.image),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        onDelete();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.error,
                        side: BorderSide(color: colors.error),
                      ),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Xóa'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        onEdit();
                      },
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Chỉnh sửa'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(
    BuildContext context,
    String label,
    String value, {
    bool highlight = false,
  }) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: highlight ? colors.primary : colors.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
