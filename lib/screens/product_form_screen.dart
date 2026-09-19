import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/product.dart';
import '../services/product_service.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';

class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key, this.product});

  final Product? product;

  bool get isEditing => product != null;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  static const _gstOptions = [0.0, 5.0, 12.0, 18.0, 28.0];

  final _formKey = GlobalKey<FormState>();
  final _productService = ProductService();

  late final TextEditingController _nameController;
  late final TextEditingController _hsnController;
  late final TextEditingController _priceController;

  double? _gstPercent;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _nameController = TextEditingController(text: product?.name ?? '');
    _hsnController = TextEditingController(text: product?.hsnCode ?? '');
    _priceController = TextEditingController(
      text: product == null ? '' : product.price.toStringAsFixed(2),
    );
    _gstPercent = product?.gstPercent ?? 18.0;
    if (_gstPercent != null && !_gstOptions.contains(_gstPercent)) {
      // Keep non-standard GST rates editable via dropdown extras.
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hsnController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_gstPercent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select GST %')),
      );
      return;
    }

    final price = double.parse(_priceController.text.trim());

    setState(() => _saving = true);
    try {
      if (widget.isEditing) {
        await _productService.updateProduct(
          widget.product!.copyWith(
            name: _nameController.text,
            hsnCode: _hsnController.text,
            price: price,
            gstPercent: _gstPercent!,
          ),
        );
      } else {
        await _productService.addProduct(
          name: _nameController.text,
          hsnCode: _hsnController.text,
          price: price,
          gstPercent: _gstPercent!,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEditing ? 'Product updated' : 'Product added',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save product: $error'),
          backgroundColor: AppTheme.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gstItems = <double>{
      ..._gstOptions,
      ?_gstPercent,
    }.toList()
      ..sort();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Product' : 'Add Product'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Product name *',
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                ),
                validator: (value) =>
                    Validators.requiredField(value, fieldName: 'Product name'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _hsnController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(8),
                ],
                decoration: const InputDecoration(
                  labelText: 'HSN code',
                  prefixIcon: Icon(Icons.qr_code_2),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Price (₹) *',
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
                validator: (value) =>
                    Validators.positiveNumber(value, fieldName: 'Price'),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<double>(
                // ignore: deprecated_member_use
                value: _gstPercent,
                decoration: const InputDecoration(
                  labelText: 'GST % *',
                  prefixIcon: Icon(Icons.percent),
                ),
                items: gstItems
                    .map(
                      (rate) => DropdownMenuItem(
                        value: rate,
                        child: Text('${rate.toStringAsFixed(0)}%'),
                      ),
                    )
                    .toList(),
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _gstPercent = value),
                validator: (value) {
                  if (value == null) return 'GST % is required';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        widget.isEditing ? 'Update Product' : 'Save Product',
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
