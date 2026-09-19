/// Predefined GST rate slabs for product selection (bonus feature).
/// Invoice math always uses the product's stored [gstPercent] dynamically —
/// these values are UI choices only, not calculation hardcodes.
class GstSlabs {
  GstSlabs._();

  static const List<double> rates = [0, 5, 12, 18, 28];

  static bool isKnownSlab(double rate) => rates.contains(rate);

  static String label(double rate) => '${rate.toStringAsFixed(0)}%';
}
