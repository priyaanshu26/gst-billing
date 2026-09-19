class Collections {
  static const users = 'users';
  static const shops = 'shops';

  /// Subcollections under shops/{shopId}/...
  static const parties = 'parties';
  static const products = 'products';
  static const bills = 'bills';
  static const settings = 'settings';
  static const counters = 'counters';

  static const settingsDocId = 'config';
  static const invoiceCounterDocId = 'invoice';
  static const productBarcodeCounterDocId = 'product';

  /// Seed value for shops/{shopId}/counters/product.currentNumber.
  /// First assigned barcode is 100001.
  static const productBarcodeSeed = 100000;
}
