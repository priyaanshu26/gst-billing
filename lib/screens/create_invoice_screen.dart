import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/bill_item.dart';
import '../models/party.dart';
import '../models/product.dart';
import '../models/shop_config.dart';
import '../services/bill_service.dart';
import '../services/gst_service.dart';
import '../services/party_service.dart';
import '../services/product_service.dart';
import '../services/shop_config_service.dart';
import '../theme/app_theme.dart';
import '../utils/currency_utils.dart';
import '../widgets/invoice_summary_widgets.dart';
import 'invoice_details_screen.dart';

class _CartLine {
  _CartLine({required this.product, required this.quantity});

  final Product product;
  double quantity;
}

class CreateInvoiceScreen extends StatefulWidget {
  const CreateInvoiceScreen({super.key});

  @override
  State<CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends State<CreateInvoiceScreen> {
  final _partyService = PartyService();
  final _productService = ProductService();
  final _shopConfigService = ShopConfigService();
  final _billService = BillService();

  ShopConfig? _shopConfig;
  Party? _selectedParty;
  final List<_CartLine> _cart = [];
  bool _loadingConfig = true;
  bool _saving = false;
  String? _configError;

  @override
  void initState() {
    super.initState();
    _loadShopConfig();
  }

  Future<void> _loadShopConfig() async {
    try {
      final config = await _shopConfigService.getOrCreateDefault();
      if (!mounted) return;
      setState(() {
        _shopConfig = config;
        _loadingConfig = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _configError = error.toString();
        _loadingConfig = false;
      });
    }
  }

  bool get _isIntraState {
    if (_shopConfig == null || _selectedParty == null) return true;
    return GstService.isSameState(_shopConfig!.state, _selectedParty!.state);
  }

  GstBillCalculation? get _calculation {
    if (_shopConfig == null || _selectedParty == null || _cart.isEmpty) {
      return null;
    }
    return GstService.calculateBill(
      shopState: _shopConfig!.state,
      partyState: _selectedParty!.state,
      drafts: _cart
          .map(
            (line) => BillItemDraft.fromProduct(
              line.product,
              quantity: line.quantity,
            ),
          )
          .toList(),
    );
  }

  Future<void> _pickParty() async {
    final parties = await _partyService.getParties();
    if (!mounted) return;

    if (parties.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a party first')),
      );
      return;
    }

    final selected = await showModalBottomSheet<Party>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return _SearchPickerSheet<Party>(
          title: 'Select party',
          items: parties,
          labelBuilder: (party) => party.name,
          subtitleBuilder: (party) =>
              [party.mobile, party.state].where((e) => e.isNotEmpty).join(' · '),
          filter: (party, query) {
            final q = query.toLowerCase();
            return party.name.toLowerCase().contains(q) ||
                party.mobile.toLowerCase().contains(q) ||
                party.gstin.toLowerCase().contains(q);
          },
        );
      },
    );

    if (selected == null || !mounted) return;
    setState(() => _selectedParty = selected);
  }

  Future<void> _addProduct() async {
    final products = await _productService.getProducts();
    if (!mounted) return;

    if (products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a product first')),
      );
      return;
    }

    final selected = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return _SearchPickerSheet<Product>(
          title: 'Add product',
          items: products,
          labelBuilder: (product) => product.name,
          subtitleBuilder: (product) =>
              '${CurrencyUtils.format(product.price)} · GST ${product.gstPercent.toStringAsFixed(0)}%',
          filter: (product, query) {
            final q = query.toLowerCase();
            return product.name.toLowerCase().contains(q) ||
                product.hsnCode.toLowerCase().contains(q);
          },
        );
      },
    );

    if (selected == null || !mounted) return;

    final qty = await _askQuantity(selected);
    if (qty == null || !mounted) return;

    setState(() {
      final existingIndex =
          _cart.indexWhere((line) => line.product.productId == selected.productId);
      if (existingIndex >= 0) {
        _cart[existingIndex].quantity =
            CurrencyUtils.roundMoney(_cart[existingIndex].quantity + qty);
      } else {
        _cart.add(_CartLine(product: selected, quantity: qty));
      }
    });
  }

  Future<double?> _askQuantity(Product product, {double initial = 1}) async {
    final controller = TextEditingController(
      text: initial == initial.roundToDouble()
          ? initial.toStringAsFixed(0)
          : initial.toStringAsFixed(2),
    );

    final result = await showDialog<double>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(product.name),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: const InputDecoration(
              labelText: 'Quantity',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final value = double.tryParse(controller.text.trim());
                if (value == null || value <= 0) return;
                Navigator.pop(context, value);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    controller.dispose();
    return result;
  }

  Future<void> _editQuantity(_CartLine line) async {
    final qty = await _askQuantity(line.product, initial: line.quantity);
    if (qty == null || !mounted) return;
    setState(() => line.quantity = qty);
  }

  Future<void> _generateInvoice() async {
    final party = _selectedParty;
    final shop = _shopConfig;
    final calc = _calculation;

    if (party == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a party')),
      );
      return;
    }
    if (shop == null || calc == null || calc.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one product')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final bill = await _billService.createBill(
        party: party,
        items: List<BillItem>.from(calc.items),
        subtotal: calc.subtotal,
        totalTax: calc.totalTax,
        grandTotal: calc.grandTotal,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invoice ${bill.invoiceNo} generated')),
      );

      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => InvoiceDetailsScreen(billId: bill.billId, bill: bill),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate invoice: $error'),
          backgroundColor: AppTheme.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingConfig) {
      return Scaffold(
        appBar: AppBar(title: const Text('Create Invoice')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_configError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Create Invoice')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Could not load shop config.\n$_configError',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.danger),
            ),
          ),
        ),
      );
    }

    final calc = _calculation;

    return Scaffold(
      appBar: AppBar(title: const Text('Create Invoice')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.storefront_outlined),
              title: Text(_shopConfig?.shopName ?? 'Shop'),
              subtitle: Text('Shop state: ${_shopConfig?.state ?? '-'}'),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.people_outline),
              title: Text(
                _selectedParty?.name ?? 'Select party *',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _selectedParty == null ? Colors.grey.shade700 : null,
                ),
              ),
              subtitle: _selectedParty == null
                  ? const Text('Required for GST type')
                  : Text(
                      [
                        _selectedParty!.state,
                        if (_selectedParty!.gstin.isNotEmpty)
                          _selectedParty!.gstin,
                      ].join(' · '),
                    ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _saving ? null : _pickParty,
            ),
          ),
          if (_selectedParty != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Chip(
                label: Text(
                  _isIntraState
                      ? 'Intra-state · CGST + SGST'
                      : 'Inter-state · IGST',
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                'Items',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _saving ? null : _addProduct,
                icon: const Icon(Icons.add),
                label: const Text('Add product'),
              ),
            ],
          ),
          if (_cart.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'No products added yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ),
            )
          else
            Card(
              child: Column(
                children: [
                  for (var i = 0; i < _cart.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    ListTile(
                      title: Text(
                        _cart[i].product.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${CurrencyUtils.format(_cart[i].product.price)}'
                        ' · GST ${_cart[i].product.gstPercent.toStringAsFixed(0)}%',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed:
                                _saving ? null : () => _editQuantity(_cart[i]),
                            child: Text('Qty ${_cart[i].quantity}'),
                          ),
                          IconButton(
                            onPressed: _saving
                                ? null
                                : () => setState(() => _cart.removeAt(i)),
                            icon: const Icon(Icons.delete_outline),
                            color: AppTheme.danger,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          if (calc != null) ...[
            const SizedBox(height: 16),
            Text(
              'Invoice summary',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            InvoiceItemsTable(items: calc.items),
            const SizedBox(height: 8),
            InvoiceTotalsCard(
              subtotal: calc.subtotal,
              totalTax: calc.totalTax,
              grandTotal: calc.grandTotal,
              totalCgst: calc.totalCgst,
              totalSgst: calc.totalSgst,
              totalIgst: calc.totalIgst,
              isIntraState: _isIntraState,
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: ElevatedButton(
            onPressed: _saving || calc == null ? null : _generateInvoice,
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
                    calc == null
                        ? 'Generate Invoice'
                        : 'Generate Invoice · ${CurrencyUtils.format(calc.grandTotal)}',
                  ),
          ),
        ),
      ),
    );
  }
}

class _SearchPickerSheet<T> extends StatefulWidget {
  const _SearchPickerSheet({
    required this.title,
    required this.items,
    required this.labelBuilder,
    required this.subtitleBuilder,
    required this.filter,
  });

  final String title;
  final List<T> items;
  final String Function(T item) labelBuilder;
  final String Function(T item) subtitleBuilder;
  final bool Function(T item, String query) filter;

  @override
  State<_SearchPickerSheet<T>> createState() => _SearchPickerSheetState<T>();
}

class _SearchPickerSheetState<T> extends State<_SearchPickerSheet<T>> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.items
        .where((item) => widget.filter(item, _query.trim()))
        .toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (context, controller) {
        return Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                widget.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Search...',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('No matches'))
                  : ListView.builder(
                      controller: controller,
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        return ListTile(
                          title: Text(widget.labelBuilder(item)),
                          subtitle: Text(widget.subtitleBuilder(item)),
                          onTap: () => Navigator.pop(context, item),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
