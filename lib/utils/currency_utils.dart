import 'package:intl/intl.dart';

class CurrencyUtils {
  static final NumberFormat _inr = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  static String format(num value) => _inr.format(value);

  static double roundMoney(num value) {
    return double.parse(value.toStringAsFixed(2));
  }
}
