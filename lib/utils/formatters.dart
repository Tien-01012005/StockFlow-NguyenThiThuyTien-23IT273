import 'package:intl/intl.dart';

class AppFormatters {
  static final NumberFormat _currencyFmt = NumberFormat('#,##0', 'vi_VN');
  static final NumberFormat _intFmt = NumberFormat('#,##0', 'vi_VN');

  static String formatPrice(double value) {
    return '${_currencyFmt.format(value.round())} đ';
  }

  static String formatNumber(num value) {
    return _intFmt.format(value);
  }
}
