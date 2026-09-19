import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/product_service.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';
import '../utils/currency_utils.dart';
import '../widgets/live_refresh_builder.dart';
import 'product_details_screen.dart';
import 'product_form_screen.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final _productService = ProductService();
  final _searchController = TextEditingController();
  String _query = '';
  int _reload = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _reloadList() {
    if (mounted) setState(() => _reload++);
  }

  Future<void> _openForm({Product? product}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductFormScreen(product: product),
      ),
    );
    _reloadList();
  }

  Future<void> _openDetails(Product product) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductDetailsScreen(product: product),
      ),
    );
    _reloadList();
  }

  Future<void> _assignBarcode(Product product) async {
    try {
      final updated = await _productService.assignBarcodeIfMissing(product);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Barcode ${updated.barcode} assigned')),
      );
      _openDetails(updated);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not assign barcode: $error'),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }

  Future<void> _confirmDelete(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete product?'),
          content: Text(
            'Delete "${product.name}"? This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    try {
      await _productService.deleteProduct(product.productId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${product.name} deleted')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete: $error'),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final canManage = SessionService.instance.canManageShop;

    return Scaffold(
      primary: false,
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              heroTag: 'fab_products',
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add_box_outlined),
              label: const Text('Add Product'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name, HSN, barcode...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: LiveRefreshBuilder<List<Product>>(
              key: ValueKey(_reload),
              load: _productService.getProducts,
              listen: _productService.watchProducts,
              errorTitle: 'Could not load products.',
              builder: (context, allProducts) {
                final products = _productService.filterProducts(
                  allProducts,
                  _query,
                );

                if (products.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _query.isEmpty
                            ? canManage
                                ? 'No products yet.\nTap Add Product to create one.'
                                : 'No products yet.\nAsk the shop owner to add one.'
                            : 'No products match your search.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                  itemCount: products.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final product = products[index];
                    final missingBarcode = product.barcode.trim().isEmpty;
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              AppTheme.secondary.withValues(alpha: 0.12),
                          foregroundColor: AppTheme.secondary,
                          child: const Icon(Icons.inventory_2_outlined),
                        ),
                        title: Text(
                          product.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          [
                            CurrencyUtils.format(product.price),
                            'GST ${product.gstPercent.toStringAsFixed(0)}%',
                            if (product.hsnCode.isNotEmpty)
                              'HSN ${product.hsnCode}',
                            if (!missingBarcode) 'Barcode ${product.barcode}',
                            if (missingBarcode) 'No barcode',
                          ].join(' · '),
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'details') {
                              _openDetails(product);
                            } else if (value == 'edit') {
                              _openForm(product: product);
                            } else if (value == 'barcode') {
                              _assignBarcode(product);
                            } else if (value == 'delete') {
                              _confirmDelete(product);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'details',
                              child: Text('View details'),
                            ),
                            if (canManage) ...[
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit'),
                              ),
                              if (missingBarcode)
                                const PopupMenuItem(
                                  value: 'barcode',
                                  child: Text('Generate barcode'),
                                ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text(
                                  'Delete',
                                  style: TextStyle(color: AppTheme.danger),
                                ),
                              ),
                            ],
                          ],
                        ),
                        onTap: () => _openDetails(product),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
