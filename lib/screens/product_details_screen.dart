import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/product_service.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';
import '../utils/currency_utils.dart';
import '../widgets/product_barcode_view.dart';
import 'product_form_screen.dart';

class ProductDetailsScreen extends StatefulWidget {
  const ProductDetailsScreen({super.key, required this.product});

  final Product product;

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  final _productService = ProductService();
  late Product _product;
  bool _assigning = false;

  @override
  void initState() {
    super.initState();
    _product = widget.product;
  }

  Future<void> _edit() async {
    final updated = await Navigator.of(context).push<Product>(
      MaterialPageRoute(
        builder: (_) => ProductFormScreen(product: _product),
      ),
    );
    if (updated != null && mounted) {
      setState(() => _product = updated);
    } else if (mounted) {
      final fresh = await _productService.getProduct(_product.productId);
      if (fresh != null && mounted) setState(() => _product = fresh);
    }
  }

  Future<void> _assignBarcode() async {
    setState(() => _assigning = true);
    try {
      final updated = await _productService.assignBarcodeIfMissing(_product);
      if (!mounted) return;
      setState(() => _product = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Barcode ${updated.barcode} assigned')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not assign barcode: $error'),
          backgroundColor: AppTheme.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _assigning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = _product;
    final hasBarcode = product.barcode.trim().isNotEmpty;
    final canManage = SessionService.instance.canManageShop;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Details'),
        actions: [
          if (canManage)
            IconButton(
              tooltip: 'Edit',
              onPressed: _edit,
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 12),
                  _detailRow(
                    'HSN/SAC',
                    product.hsnCode.isEmpty ? '—' : product.hsnCode,
                  ),
                  _detailRow('Price', CurrencyUtils.format(product.price)),
                  _detailRow(
                    'GST',
                    '${product.gstPercent.toStringAsFixed(0)}%',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Barcode',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ProductBarcodeView(value: product.barcode),
                  if (!hasBarcode && canManage) ...[
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _assigning ? null : _assignBarcode,
                      icon: _assigning
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.qr_code_2),
                      label: const Text('Generate barcode'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'HSN/SAC is for GST classification. Barcode is only used to find '
            'this product when scanning on Create Invoice.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
