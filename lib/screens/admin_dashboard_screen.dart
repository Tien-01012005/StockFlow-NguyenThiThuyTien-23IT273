import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/auth_service.dart';
import '../services/product_service.dart';
import '../utils/formatters.dart';
import '../utils/image_helper.dart';
import '../widgets/json_export_dialog.dart';
import '../widgets/product_detail_dialog.dart';
import '../widgets/product_form_dialog.dart';

enum StockFilter { all, inStock, lowStock, outOfStock }

enum SortOption {
  nameAsc,
  nameDesc,
  priceAsc,
  priceDesc,
  qtyAsc,
  qtyDesc,
}

class AdminDashboardScreen extends StatefulWidget {
  final User user;
  final AuthService authService;
  final ProductService productService;
  final VoidCallback onToggleTheme;
  final bool isDarkMode;

  const AdminDashboardScreen({
    super.key,
    required this.user,
    required this.authService,
    required this.productService,
    required this.onToggleTheme,
    required this.isDarkMode,
  });

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  StockFilter _stockFilter = StockFilter.all;
  SortOption _sortOption = SortOption.nameAsc;
  bool _gridViewOnDesktop = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Product> _applyFilterAndSort(List<Product> products) {
    final String query = _searchQuery.trim().toLowerCase();
    final List<Product> filtered = products.where((p) {
      if (query.isNotEmpty && !p.name.toLowerCase().contains(query)) {
        return false;
      }
      return switch (_stockFilter) {
        StockFilter.all => true,
        StockFilter.inStock => p.stockStatus == StockStatus.inStock,
        StockFilter.lowStock => p.stockStatus == StockStatus.lowStock,
        StockFilter.outOfStock => p.stockStatus == StockStatus.outOfStock,
      };
    }).toList();

    filtered.sort((a, b) {
      return switch (_sortOption) {
        SortOption.nameAsc =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        SortOption.nameDesc =>
          b.name.toLowerCase().compareTo(a.name.toLowerCase()),
        SortOption.priceAsc => a.price.compareTo(b.price),
        SortOption.priceDesc => b.price.compareTo(a.price),
        SortOption.qtyAsc => a.soluong.compareTo(b.soluong),
        SortOption.qtyDesc => b.soluong.compareTo(a.soluong),
      };
    });

    return filtered;
  }

  Future<void> _openAddDialog() async {
    final bool? saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ProductFormDialog(
        productService: widget.productService,
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã thêm sản phẩm mới thành công.')),
      );
    }
  }

  Future<void> _openEditDialog(Product product) async {
    final bool? saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ProductFormDialog(
        productService: widget.productService,
        existingProduct: product,
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã cập nhật "${product.name}".')),
      );
    }
  }

  Future<void> _confirmDelete(Product product) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa sản phẩm'),
        content: Text(
          'Bạn có chắc muốn xóa "${product.name}" khỏi kho không? Thao tác này không thể hoàn tác.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await widget.productService.deleteProduct(product.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã xóa "${product.name}".')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi xóa sản phẩm: $e')),
        );
      }
    }
  }

  void _openDetailDialog(Product product) {
    showDialog<void>(
      context: context,
      builder: (_) => ProductDetailDialog(
        product: product,
        onEdit: () => _openEditDialog(product),
        onDelete: () => _confirmDelete(product),
      ),
    );
  }

  Future<void> _adjustQuantity(Product product, int delta) async {
    final int nextQty = product.soluong + delta;
    if (nextQty < 0) return;
    try {
      await widget.productService.updateQuantity(product.id, nextQty);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể cập nhật số lượng: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final bool isDesktop = screenWidth >= 860;
    final ColorScheme colors = Theme.of(context).colorScheme;

    return StreamBuilder<List<Product>>(
      stream: widget.productService.streamProducts(),
      builder: (context, snapshot) {
        final List<Product> allProducts = snapshot.data ?? <Product>[];
        final List<Product> filteredProducts = _applyFilterAndSort(allProducts);

        final int totalItems = allProducts.length;
        final int totalStock = allProducts.fold<int>(
          0,
          (sum, p) => sum + p.soluong,
        );
        final double totalValue = allProducts.fold<double>(
          0,
          (sum, p) => sum + p.totalValue,
        );
        final int lowOrOutCount = allProducts
            .where((p) => p.stockStatus != StockStatus.inStock)
            .length;

        return Scaffold(
          appBar: AppBar(
            titleSpacing: isDesktop ? 24 : 16,
            title: Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.inventory_2_rounded,
                    color: colors.onPrimaryContainer,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'StockFlow Admin',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                      Text(
                        widget.user.email ?? 'Admin',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: <Widget>[
              if (isDesktop) ...<Widget>[
                OutlinedButton.icon(
                  onPressed: () {
                    showDialog<void>(
                      context: context,
                      builder: (_) => JsonExportDialog(products: allProducts),
                    );
                  },
                  icon: const Icon(Icons.data_object, size: 18),
                  label: const Text('Xuất JSON'),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: _openAddDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Thêm sản phẩm'),
                ),
                const SizedBox(width: 8),
              ] else
                IconButton(
                  tooltip: 'Xuất JSON CSDL',
                  onPressed: () {
                    showDialog<void>(
                      context: context,
                      builder: (_) => JsonExportDialog(products: allProducts),
                    );
                  },
                  icon: const Icon(Icons.data_object),
                ),
              IconButton(
                tooltip: widget.isDarkMode ? 'Chế độ sáng' : 'Chế độ tối',
                onPressed: widget.onToggleTheme,
                icon: Icon(
                  widget.isDarkMode
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                ),
              ),
              IconButton(
                tooltip: 'Đăng xuất',
                onPressed: () async => widget.authService.signOut(),
                icon: const Icon(Icons.logout_rounded),
              ),
              SizedBox(width: isDesktop ? 16 : 6),
            ],
          ),
          floatingActionButton: isDesktop
              ? null
              : FloatingActionButton.extended(
                  onPressed: _openAddDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Thêm sản phẩm'),
                ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1320),
              child: CustomScrollView(
                slivers: <Widget>[
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      isDesktop ? 24 : 14,
                      16,
                      isDesktop ? 24 : 14,
                      12,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _buildKpiSection(
                            isDesktop: isDesktop,
                            totalItems: totalItems,
                            totalStock: totalStock,
                            totalValue: totalValue,
                            lowOrOutCount: lowOrOutCount,
                          ),
                          const SizedBox(height: 16),
                          _buildToolbar(isDesktop),
                        ],
                      ),
                    ),
                  ),
                  if (snapshot.hasError)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                Icons.cloud_off_rounded,
                                size: 48,
                                color: colors.error,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Lỗi tải dữ liệu từ Firestore:\n${snapshot.error}',
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else if (snapshot.connectionState ==
                          ConnectionState.waiting &&
                      allProducts.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (filteredProducts.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 56,
                                color: colors.onSurfaceVariant,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                allProducts.isEmpty
                                    ? 'Kho hàng chưa có sản phẩm nào'
                                    : 'Không tìm thấy sản phẩm phù hợp',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                allProducts.isEmpty
                                    ? 'Nhấn "Thêm sản phẩm" để nhập sản phẩm đầu tiên vào Firebase.'
                                    : 'Thử xóa từ khóa tìm kiếm hoặc đổi bộ lọc trạng thái.',
                                style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              if (allProducts.isEmpty) ...<Widget>[
                                const SizedBox(height: 16),
                                FilledButton.icon(
                                  onPressed: _openAddDialog,
                                  icon: const Icon(Icons.add),
                                  label: const Text('Thêm sản phẩm ngay'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    )
                  else if (isDesktop && !_gridViewOnDesktop)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                      sliver: SliverToBoxAdapter(
                        child: _buildDesktopTable(filteredProducts),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        isDesktop ? 24 : 14,
                        0,
                        isDesktop ? 24 : 14,
                        92,
                      ),
                      sliver: isDesktop
                          ? SliverGrid(
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 340,
                                    mainAxisSpacing: 14,
                                    crossAxisSpacing: 14,
                                    mainAxisExtent: 330,
                                  ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => _buildDesktopGridCard(
                                  filteredProducts[index],
                                ),
                                childCount: filteredProducts.length,
                              ),
                            )
                          : SliverList.separated(
                              itemCount: filteredProducts.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) => _buildMobileCard(
                                filteredProducts[index],
                              ),
                            ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildKpiSection({
    required bool isDesktop,
    required int totalItems,
    required int totalStock,
    required double totalValue,
    required int lowOrOutCount,
  }) {
    final List<Widget> cards = <Widget>[
      _KpiCard(
        title: 'Tổng mặt hàng',
        value: AppFormatters.formatNumber(totalItems),
        icon: Icons.category_outlined,
        accent: const Color(0xFF2563EB),
      ),
      _KpiCard(
        title: 'Tổng số lượng tồn',
        value: AppFormatters.formatNumber(totalStock),
        icon: Icons.layers_outlined,
        accent: const Color(0xFF059669),
      ),
      _KpiCard(
        title: 'Tổng giá trị kho',
        value: AppFormatters.formatPrice(totalValue),
        icon: Icons.account_balance_wallet_outlined,
        accent: const Color(0xFF7C3AED),
      ),
      _KpiCard(
        title: 'Sắp hết / Hết hàng',
        value: AppFormatters.formatNumber(lowOrOutCount),
        icon: Icons.warning_amber_rounded,
        accent: const Color(0xFFD97706),
      ),
    ];

    if (isDesktop) {
      return Row(
        children: cards
            .map(
              (c) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: c,
                ),
              ),
            )
            .toList()
          ..last = Expanded(child: cards.last),
      );
    }

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.85,
      children: cards,
    );
  }

  Widget _buildToolbar(bool isDesktop) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Wrap(
              spacing: 12,
              runSpacing: 10,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: isDesktop ? 320 : 220,
                    maxWidth: isDesktop ? 420 : double.infinity,
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      hintText: 'Tìm kiếm theo tên sản phẩm...',
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                              icon: const Icon(Icons.clear, size: 18),
                            )
                          : null,
                    ),
                  ),
                ),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    DropdownButtonHideUnderline(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: colors.outlineVariant),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButton<SortOption>(
                          value: _sortOption,
                          isDense: true,
                          icon: const Icon(Icons.sort_rounded, size: 18),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _sortOption = val);
                            }
                          },
                          items: const <DropdownMenuItem<SortOption>>[
                            DropdownMenuItem(
                              value: SortOption.nameAsc,
                              child: Text('Tên: A → Z'),
                            ),
                            DropdownMenuItem(
                              value: SortOption.nameDesc,
                              child: Text('Tên: Z → A'),
                            ),
                            DropdownMenuItem(
                              value: SortOption.priceAsc,
                              child: Text('Giá: Thấp → Cao'),
                            ),
                            DropdownMenuItem(
                              value: SortOption.priceDesc,
                              child: Text('Giá: Cao → Thấp'),
                            ),
                            DropdownMenuItem(
                              value: SortOption.qtyAsc,
                              child: Text('Số lượng: Ít → Nhiều'),
                            ),
                            DropdownMenuItem(
                              value: SortOption.qtyDesc,
                              child: Text('Số lượng: Nhiều → Ít'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (isDesktop)
                      SegmentedButton<bool>(
                        showSelectedIcon: false,
                        segments: const <ButtonSegment<bool>>[
                          ButtonSegment<bool>(
                            value: false,
                            icon: Icon(Icons.table_rows_outlined, size: 18),
                            tooltip: 'Dạng bảng',
                          ),
                          ButtonSegment<bool>(
                            value: true,
                            icon: Icon(Icons.grid_view_outlined, size: 18),
                            tooltip: 'Dạng lưới',
                          ),
                        ],
                        selected: <bool>{_gridViewOnDesktop},
                        onSelectionChanged: (sel) {
                          setState(() => _gridViewOnDesktop = sel.first);
                        },
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  _filterChip(StockFilter.all, 'Tất cả'),
                  const SizedBox(width: 8),
                  _filterChip(StockFilter.inStock, 'Còn hàng (>5)'),
                  const SizedBox(width: 8),
                  _filterChip(StockFilter.lowStock, 'Sắp hết (1–5)'),
                  const SizedBox(width: 8),
                  _filterChip(StockFilter.outOfStock, 'Hết hàng (0)'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(StockFilter filter, String label) {
    final bool selected = _stockFilter == filter;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _stockFilter = filter),
    );
  }

  Widget _buildStatusBadge(Product product) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final (String label, Color bg, Color fg) = switch (product.stockStatus) {
      StockStatus.outOfStock => (
          'Hết hàng',
          colors.errorContainer,
          colors.onErrorContainer,
        ),
      StockStatus.lowStock => (
          'Sắp hết',
          const Color(0xFFFEF3C7),
          const Color(0xFF92400E),
        ),
      StockStatus.inStock => (
          'Còn hàng',
          const Color(0xFFDCFCE7),
          const Color(0xFF166534),
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildDesktopTable(List<Product> products) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: constraints.maxWidth > 980 ? constraints.maxWidth : 980,
            ),
            child: DataTable(
            headingRowColor: WidgetStatePropertyAll(
              colors.surfaceContainerHighest.withValues(alpha: 0.45),
            ),
            dataRowMinHeight: 72,
            dataRowMaxHeight: 80,
            columns: const <DataColumn>[
              DataColumn(label: Text('Hình ảnh')),
              DataColumn(label: Text('Tên sản phẩm')),
              DataColumn(label: Text('Đơn giá'), numeric: true),
              DataColumn(label: Text('Số lượng')),
              DataColumn(label: Text('Trạng thái')),
              DataColumn(label: Text('Thành tiền'), numeric: true),
              DataColumn(label: Text('Thao tác')),
            ],
            rows: products.map((product) {
              return DataRow(
                cells: <DataCell>[
                  DataCell(
                    InkWell(
                      onTap: () => _openDetailDialog(product),
                      borderRadius: BorderRadius.circular(10),
                      child: ProductImageWidget(
                        imageUrl: product.image,
                        width: 52,
                        height: 52,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  DataCell(
                    InkWell(
                      onTap: () => _openDetailDialog(product),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 260),
                        child: Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      AppFormatters.formatPrice(product.price),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: colors.primary,
                      ),
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        IconButton(
                          tooltip: 'Giảm 1',
                          visualDensity: VisualDensity.compact,
                          onPressed: product.soluong > 0
                              ? () => _adjustQuantity(product, -1)
                              : null,
                          icon: const Icon(
                            Icons.remove_circle_outline,
                            size: 20,
                          ),
                        ),
                        SizedBox(
                          width: 34,
                          child: Text(
                            '${product.soluong}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Tăng 1',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _adjustQuantity(product, 1),
                          icon: const Icon(Icons.add_circle_outline, size: 20),
                        ),
                      ],
                    ),
                  ),
                  DataCell(_buildStatusBadge(product)),
                  DataCell(
                    Text(
                      AppFormatters.formatPrice(product.totalValue),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        IconButton(
                          tooltip: 'Xem chi tiết',
                          onPressed: () => _openDetailDialog(product),
                          icon: const Icon(Icons.visibility_outlined),
                        ),
                        IconButton(
                          tooltip: 'Sửa sản phẩm',
                          onPressed: () => _openEditDialog(product),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: 'Xóa sản phẩm',
                          color: colors.error,
                          onPressed: () => _confirmDelete(product),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopGridCard(Product product) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openDetailDialog(product),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  ProductImageWidget(
                    imageUrl: product.image,
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: _buildStatusBadge(product),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        AppFormatters.formatPrice(product.price),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: colors.primary,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        'SL: ${product.soluong}',
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      IconButton.outlined(
                        tooltip: 'Giảm SL',
                        visualDensity: VisualDensity.compact,
                        onPressed: product.soluong > 0
                            ? () => _adjustQuantity(product, -1)
                            : null,
                        icon: const Icon(Icons.remove, size: 16),
                      ),
                      const SizedBox(width: 6),
                      IconButton.outlined(
                        tooltip: 'Tăng SL',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _adjustQuantity(product, 1),
                        icon: const Icon(Icons.add, size: 16),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Sửa',
                        onPressed: () => _openEditDialog(product),
                        icon: const Icon(Icons.edit_outlined, size: 20),
                      ),
                      IconButton(
                        tooltip: 'Xóa',
                        color: colors.error,
                        onPressed: () => _confirmDelete(product),
                        icon: const Icon(Icons.delete_outline, size: 20),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileCard(Product product) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: InkWell(
        onTap: () => _openDetailDialog(product),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ProductImageWidget(
                imageUrl: product.image,
                width: 82,
                height: 82,
                borderRadius: BorderRadius.circular(12),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            product.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _buildStatusBadge(product),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      AppFormatters.formatPrice(product.price),
                      style: TextStyle(
                        color: colors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        Container(
                          decoration: BoxDecoration(
                            color: colors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: colors.outlineVariant),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              InkWell(
                                onTap: product.soluong > 0
                                    ? () => _adjustQuantity(product, -1)
                                    : null,
                                borderRadius: BorderRadius.circular(10),
                                child: const Padding(
                                  padding: EdgeInsets.all(6),
                                  child: Icon(Icons.remove, size: 16),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                child: Text(
                                  'SL: ${product.soluong}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: () => _adjustQuantity(product, 1),
                                borderRadius: BorderRadius.circular(10),
                                child: const Padding(
                                  padding: EdgeInsets.all(6),
                                  child: Icon(Icons.add, size: 16),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Sửa',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _openEditDialog(product),
                          icon: const Icon(Icons.edit_outlined, size: 20),
                        ),
                        IconButton(
                          tooltip: 'Xóa',
                          visualDensity: VisualDensity.compact,
                          color: colors.error,
                          onPressed: () => _confirmDelete(product),
                          icon: const Icon(Icons.delete_outline, size: 20),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color accent;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accent, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
