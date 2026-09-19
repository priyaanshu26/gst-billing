import 'package:intl/intl.dart';

class AppDateUtils {
  static final DateFormat _display = DateFormat('dd MMM yyyy');
  static final DateFormat _invoice = DateFormat('dd/MM/yyyy');

  static String formatDisplay(DateTime date) => _display.format(date);

  static String formatInvoice(DateTime date) => _invoice.format(date);

  static DateTime startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static DateTime endOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
  }

  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static bool isSameMonth(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month;
  }
}
