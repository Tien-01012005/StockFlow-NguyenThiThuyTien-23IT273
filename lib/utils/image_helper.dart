import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

class ImageHelper {
  static final ImagePicker _picker = ImagePicker();
  static final Map<int, Uint8List> _base64Cache = <int, Uint8List>{};

  static Future<String?> pickAndEncodeImage(ImageSource source) async {
    final XFile? picked = await _picker.pickImage(
      source: source,
      maxWidth: 900,
      maxHeight: 900,
      imageQuality: 85,
    );
    if (picked == null) return null;

    final Uint8List rawBytes = await picked.readAsBytes();
    final Uint8List compressed = _compressBytes(rawBytes);

    if (compressed.length > 500 * 1024) {
      throw Exception('Ảnh quá lớn sau khi nén. Vui lòng chọn ảnh nhỏ hơn.');
    }

    return 'data:image/jpeg;base64,${base64Encode(compressed)}';
  }

  static Uint8List _compressBytes(Uint8List rawBytes) {
    final img.Image? decoded = img.decodeImage(rawBytes);
    if (decoded == null) {
      return rawBytes;
    }

    img.Image resized = decoded;
    const int maxDim = 480;
    if (decoded.width > maxDim || decoded.height > maxDim) {
      if (decoded.width >= decoded.height) {
        resized = img.copyResize(decoded, width: maxDim);
      } else {
        resized = img.copyResize(decoded, height: maxDim);
      }
    }

    Uint8List encoded = Uint8List.fromList(img.encodeJpg(resized, quality: 72));
    if (encoded.length > 180 * 1024) {
      encoded = Uint8List.fromList(img.encodeJpg(resized, quality: 52));
    }
    return encoded;
  }

  static bool isDataUri(String value) {
    return value.startsWith('data:image/') && value.contains('base64,');
  }

  static Uint8List? decodeDataUri(String uri) {
    if (!isDataUri(uri)) return null;
    final int key = uri.hashCode;
    final Uint8List? cached = _base64Cache[key];
    if (cached != null) return cached;

    try {
      final int commaIndex = uri.indexOf('base64,');
      final String b64 = uri.substring(commaIndex + 7).trim();
      final Uint8List bytes = base64Decode(b64);
      if (_base64Cache.length > 80) {
        _base64Cache.clear();
      }
      _base64Cache[key] = bytes;
      return bytes;
    } catch (_) {
      return null;
    }
  }

  static String describeImageSource(String value) {
    if (value.trim().isEmpty) return 'Chưa có ảnh';
    if (isDataUri(value)) {
      final double kb = value.length * 0.75 / 1024;
      return 'Ảnh tải lên (${kb.toStringAsFixed(0)} KB)';
    }
    return 'Liên kết URL';
  }
}

class ProductImageWidget extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const ProductImageWidget({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final String trimmed = imageUrl.trim();

    Widget child;
    if (trimmed.isEmpty) {
      child = _placeholder(colors, Icons.inventory_2_outlined);
    } else if (ImageHelper.isDataUri(trimmed)) {
      final Uint8List? bytes = ImageHelper.decodeDataUri(trimmed);
      if (bytes == null) {
        child = _placeholder(colors, Icons.broken_image_outlined);
      } else {
        child = Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) =>
              _placeholder(colors, Icons.broken_image_outlined),
        );
      }
    } else {
      child = Image.network(
        trimmed,
        width: width,
        height: height,
        fit: fit,
        loadingBuilder: (context, widget, progress) {
          if (progress == null) return widget;
          return Container(
            width: width,
            height: height,
            color: colors.surfaceContainerHighest.withValues(alpha: 0.45),
            alignment: Alignment.center,
            child: const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
        errorBuilder: (_, _, _) =>
            _placeholder(colors, Icons.broken_image_outlined),
      );
    }

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: child,
      );
    }
    return child;
  }

  Widget _placeholder(ColorScheme colors, IconData icon) {
    return Container(
      width: width,
      height: height,
      color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
      alignment: Alignment.center,
      child: Icon(
        icon,
        color: colors.onSurfaceVariant,
        size: (width != null && width! < 56) ? 20 : 32,
      ),
    );
  }
}
