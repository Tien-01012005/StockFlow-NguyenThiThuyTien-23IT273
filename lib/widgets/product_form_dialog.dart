import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../models/product.dart';
import '../services/product_service.dart';
import '../utils/image_helper.dart';

class ProductFormDialog extends StatefulWidget {
  final Product? existingProduct;
  final ProductService productService;

  const ProductFormDialog({
    super.key,
    required this.productService,
    this.existingProduct,
  });

  @override
  State<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<ProductFormDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _qtyController;
  late final TextEditingController _imageUrlController;

  String _currentImage = '';
  bool _useUrlMode = true;
  bool _isSaving = false;
  bool _isPickingImage = false;
  String? _errorText;

  bool get _isEditing => widget.existingProduct != null;

  @override
  void initState() {
    super.initState();
    final Product? existing = widget.existingProduct;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _priceController = TextEditingController(
      text: existing != null ? existing.price.round().toString() : '',
    );
    _qtyController = TextEditingController(
      text: existing != null ? existing.soluong.toString() : '',
    );
    _currentImage = existing?.image ?? '';
    final bool isDataUri = ImageHelper.isDataUri(_currentImage);
    _useUrlMode = _currentImage.isEmpty ? kIsWeb : !isDataUri;
    _imageUrlController = TextEditingController(
      text: isDataUri ? '' : _currentImage,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _qtyController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    setState(() {
      _isPickingImage = true;
      _errorText = null;
    });
    try {
      final String? encoded = await ImageHelper.pickAndEncodeImage(source);
      if (encoded != null && mounted) {
        setState(() {
          _currentImage = encoded;
          _useUrlMode = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorText = 'Không thể xử lý hình ảnh: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isPickingImage = false);
      }
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final String effectiveImage = _useUrlMode
        ? _imageUrlController.text.trim()
        : _currentImage.trim();

    if (effectiveImage.isEmpty) {
      setState(() {
        _errorText = 'Vui lòng nhập URL ảnh hoặc chọn ảnh từ thiết bị.';
      });
      return;
    }

    final double price = double.parse(_priceController.text.trim());
    final int qty = int.parse(_qtyController.text.trim());
    final String name = _nameController.text.trim();

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    try {
      if (_isEditing) {
        await widget.productService.updateProduct(
          widget.existingProduct!.copyWith(
            name: name,
            price: price,
            soluong: qty,
            image: effectiveImage,
          ),
        );
      } else {
        await widget.productService.addProduct(
          name: name,
          price: price,
          soluong: qty,
          image: effectiveImage,
        );
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorText = 'Lỗi lưu dữ liệu: $e';
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final String previewImage = _useUrlMode
        ? _imageUrlController.text.trim()
        : _currentImage;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colors.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _isEditing ? Icons.edit_note : Icons.add_box_outlined,
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            _isEditing
                                ? 'Cập nhật sản phẩm'
                                : 'Thêm sản phẩm mới',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            'Cấu trúc chuẩn 4 trường: name, price, soluong, image',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Tên sản phẩm (name)',
                    hintText: 'Ví dụ: Bàn phím cơ Keychron K2 Pro',
                    prefixIcon: Icon(Icons.inventory_2_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Vui lòng nhập tên sản phẩm.';
                    }
                    if (value.trim().length > 200) {
                      return 'Tên sản phẩm tối đa 200 ký tự.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Giá bán VNĐ (price)',
                          hintText: '1500000',
                          prefixIcon: Icon(Icons.payments_outlined),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Nhập giá bán.';
                          }
                          final double? parsed = double.tryParse(value.trim());
                          if (parsed == null || parsed < 0) {
                            return 'Giá không hợp lệ.';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _qtyController,
                        keyboardType: TextInputType.number,
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Số lượng (soluong)',
                          hintText: '20',
                          prefixIcon: Icon(Icons.numbers),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Nhập số lượng.';
                          }
                          final int? parsed = int.tryParse(value.trim());
                          if (parsed == null || parsed < 0) {
                            return 'Số lượng >= 0.';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'Hình ảnh sản phẩm (image)',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<bool>(
                  segments: const <ButtonSegment<bool>>[
                    ButtonSegment<bool>(
                      value: true,
                      label: Text('Nhập URL ảnh'),
                      icon: Icon(Icons.link),
                    ),
                    ButtonSegment<bool>(
                      value: false,
                      label: Text('Tải / Chụp ảnh'),
                      icon: Icon(Icons.photo_camera_outlined),
                    ),
                  ],
                  selected: <bool>{_useUrlMode},
                  onSelectionChanged: (selection) {
                    setState(() {
                      _useUrlMode = selection.first;
                      _errorText = null;
                    });
                  },
                ),
                const SizedBox(height: 12),
                if (_useUrlMode)
                  TextFormField(
                    controller: _imageUrlController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Đường dẫn ảnh (https://...)',
                      hintText: 'https://images.unsplash.com/...',
                      prefixIcon: const Icon(Icons.image_outlined),
                      suffixIcon: _imageUrlController.text.isNotEmpty
                          ? IconButton(
                              onPressed: () {
                                _imageUrlController.clear();
                                setState(() {});
                              },
                              icon: const Icon(Icons.clear),
                            )
                          : null,
                    ),
                  )
                else
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: <Widget>[
                      FilledButton.tonalIcon(
                        onPressed: _isPickingImage
                            ? null
                            : () => _pickImage(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: Text(
                          kIsWeb ? 'Chọn ảnh từ máy tính' : 'Chọn từ thư viện',
                        ),
                      ),
                      if (!kIsWeb)
                        FilledButton.tonalIcon(
                          onPressed: _isPickingImage
                              ? null
                              : () => _pickImage(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt_outlined),
                          label: const Text('Chụp ảnh mới'),
                        ),
                    ],
                  ),
                const SizedBox(height: 14),
                Container(
                  height: 170,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: colors.outlineVariant,
                    ),
                    color: colors.surfaceContainerLowest,
                  ),
                  child: _isPickingImage
                      ? const Center(child: CircularProgressIndicator())
                      : Row(
                          children: <Widget>[
                            Padding(
                              padding: const EdgeInsets.all(10),
                              child: ProductImageWidget(
                                imageUrl: previewImage,
                                width: 148,
                                height: 148,
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(right: 14),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      'Xem trước hình ảnh',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      ImageHelper.describeImageSource(
                                        previewImage,
                                      ),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: colors.onSurfaceVariant,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Ảnh chọn từ thiết bị tự động nén dưới 480px để lưu trực tiếp vào Firestore.',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: colors.onSurfaceVariant,
                                            fontSize: 11.5,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
                if (_errorText != null) ...<Widget>[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.errorContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          Icons.error_outline,
                          color: colors.onErrorContainer,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorText!,
                            style: TextStyle(color: colors.onErrorContainer),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    OutlinedButton(
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: const Text('Hủy'),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: _isSaving ? null : _submit,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(_isEditing ? Icons.save : Icons.add),
                      label: Text(
                        _isEditing ? 'Lưu thay đổi' : 'Thêm sản phẩm',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
