import 'map_helpers.dart';

class InvoiceCounter {
  final int lastNumber;
  final String prefix;

  const InvoiceCounter({
    this.lastNumber = 0,
    this.prefix = 'INV-',
  });

  factory InvoiceCounter.fromMap(Map<String, dynamic> map) {
    return InvoiceCounter(
      lastNumber: parseInt(map['lastNumber']),
      prefix: parseString(map['prefix'], 'INV-'),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'lastNumber': lastNumber,
      'prefix': prefix,
    };
  }

  String formatInvoiceNo(int number) {
    return '$prefix${number.toString().padLeft(4, '0')}';
  }
}
