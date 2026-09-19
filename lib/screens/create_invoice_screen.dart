import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/bill.dart';
import '../models/bill_item.dart';
import '../models/party.dart';
import '../models/product.dart';
import '../models/shop_config.dart';
import '../services/bill_service.dart';
import '../services/gst_service.dart';
import '../services/party_service.dart';
import '../services/product_service.dart';
import '../services/session_service.dart';
import '../services/shop_config_service.dart';
import '../theme/app_theme.dart';
import '../utils/currency_utils.dart';
import '../widgets/invoice_summary_widgets.dart';
import 'barcode_scanner_screen.dart';
import 'invoice_details_screen.dart';
import 'shop_settings_screen.dart';

class _CartLine {
  _CartLine({
    required this.product,
    required this.quantity,
  });

  final Product product;
  double quantity;
  double discount = 0;

  double get grossAmount =>
      CurrencyUtils.roundMoney(product.price * quantity);
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
  bool _catalogBusy = false;
  String? _configError;

  String _paymentStatus = PaymentStatus.unpaid;
  final _paidAmountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadShopConfig();
  }

  @override
  void dispose() {
    _paidAmountController.dispose();
    super.dispose();
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

  Future<void> _editShopConfig() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ShopSettingsScreen()),
    );
    if (!mounted) return;
    await _loadShopConfig();
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
              discount: line.discount,
            ),
          )
          .toList(),
    );
  }

  String _paymentPreviewText(double grandTotal) {
    final paidText = _paidAmountController.text.trim();
    final paidParsed =
        paidText.isEmpty ? null : double.tryParse(paidText);
    final breakdown = Bill.resolvePayment(
      paymentStatus: _paymentStatus,
      grandTotal: grandTotal,
      paidAmount: _paymentStatus == PaymentStatus.partial ? paidParsed : null,
    );
    return 'Paid ${CurrencyUtils.format(breakdown.paidAmount)}'
        ' · Remaining ${CurrencyUtils.format(breakdown.remainingAmount)}';
  }

  Future<void> _pickParty() async {
    setState(() => _catalogBusy = true);
    List<Party> parties;
    try {
      parties = await _partyService.getParties();
    } catch (error) {
      if (!mounted) return;
      setState(() => _catalogBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not load parties: $error'),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _catalogBusy = false);

    if (parties.isEmpty) {
      final message = SessionService.instance.canManageShop
          ? 'Add a party first'
          : 'Ask the shop owner to add a party first';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
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
    setState(() => _catalogBusy = true);
    List<Product> products;
    try {
      products = await _productService.getProducts();
    } catch (error) {
      if (!mounted) return;
      setState(() => _catalogBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not load products: $error'),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _catalogBusy = false);

    if (products.isEmpty) {
      final message = SessionService.instance.canManageShop
          ? 'Add a product first'
          : 'Ask the shop owner to add a product first';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
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
              '${CurrencyUtils.format(product.price)} · GST ${product.gstPercent.toStringAsFixed(0)}%'
              '${product.barcode.isEmpty ? '' : ' · ${product.barcode}'}',
          filter: (product, query) {
            final q = query.toLowerCase();
            return product.name.toLowerCase().contains(q) ||
                product.hsnCode.toLowerCase().contains(q) ||
                product.barcode.toLowerCase().contains(q);
          },
        );
      },
    );

    if (selected == null || !mounted) return;
    await _promptQuantityAndAdd(selected);
  }

  Future<void> _scanBarcode() async {
    String? code;
    try {
      code = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Scanner failed: $error'),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }

    if (!mounted) return;
    if (code == null) {
      // User cancelled.
      return;
    }
    if (code.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid or empty barcode scan')),
      );
      return;
    }

    try {
      final product = await _productService.findByBarcode(code);
      if (!mounted) return;

      if (product == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Product not found for barcode "$code"'),
            backgroundColor: AppTheme.danger,
          ),
        );
        return;
      }

      await _promptQuantityAndAdd(product);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Barcode lookup failed: $error'),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }

  Future<void> _promptQuantityAndAdd(Product product) async {
    final qty = await _askQuantity(product);
    if (qty == null || !mounted) return;

    setState(() {
      final existingIndex = _cart
          .indexWhere((line) => line.product.productId == product.productId);
      if (existingIndex >= 0) {
        final line = _cart[existingIndex];
        line.quantity = CurrencyUtils.roundMoney(line.quantity + qty);
        if (line.discount > line.grossAmount) {
          line.discount = line.grossAmount;
        }
      } else {
        _cart.add(_CartLine(product: product, quantity: qty));
      }
    });
  }

  Future<double?> _askQuantity(Product product, {double initial = 1}) {
    return showDialog<double>(
      context: context,
      builder: (context) => _QuantityDialog(product: product, initial: initial),
    );
  }

  Future<void> _editLine(_CartLine line) async {
    final result = await showDialog<_LineEditResult>(
      context: context,
      builder: (context) => _LineEditDialog(line: line),
    );
    if (result == null || !mounted) return;
    setState(() {
      line.quantity = result.quantity;
      line.discount = result.discount;
    });
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

    double? paidInput;
    if (_paymentStatus == PaymentStatus.partial) {
      final text = _paidAmountController.text.trim();
      paidInput = text.isEmpty ? null : double.tryParse(text);
      if (text.isNotEmpty && paidInput == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid paid amount')),
        );
        return;
      }
    }

    final paymentError = Bill.validatePayment(
      paymentStatus: _paymentStatus,
      grandTotal: calc.grandTotal,
      paidAmount: paidInput,
    );
    if (paymentError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(paymentError)),
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
        paymentStatus: _paymentStatus,
        paidAmount: paidInput,
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

    final canManageShop = SessionService.instance.canManageShop;

    return Stack(
      children: [
        Scaffold(
      appBar: AppBar(title: const Text('Create Invoice')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.storefront_outlined),
              title: Text(_shopConfig?.shopName ?? 'Shop'),
              subtitle: Text('Shop state: ${_shopConfig?.state ?? '-'}'),
              trailing: Icon(
                canManageShop
                    ? Icons.edit_outlined
                    : Icons.chevron_right,
              ),
              onTap: _saving ? null : _editShopConfig,
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
                onPressed: _saving ? null : _scanBarcode,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan'),
              ),
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
                        ' · GST ${_cart[i].product.gstPercent.toStringAsFixed(0)}%'
                        '${_cart[i].discount > 0 ? ' · Disc ${CurrencyUtils.format(_cart[i].discount)}' : ''}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed:
                                _saving ? null : () => _editLine(_cart[i]),
                            child: Text(
                              'Qty ${_cart[i].quantity}'
                              '${_cart[i].discount > 0 ? ' · Disc' : ''}',
                            ),
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
                      onTap: _saving ? null : () => _editLine(_cart[i]),
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
              totalGross: calc.totalGross,
              totalDiscount: calc.totalDiscount,
              totalCgst: calc.totalCgst,
              totalSgst: calc.totalSgst,
              totalIgst: calc.totalIgst,
              isIntraState: _isIntraState,
            ),
            const SizedBox(height: 16),
            Text(
              'Payment',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String>(
                      // ignore: deprecated_member_use
                      value: _paymentStatus,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Payment status *',
                        prefixIcon: Icon(Icons.payments_outlined),
                      ),
                      items: PaymentStatus.values
                          .map(
                            (status) => DropdownMenuItem(
                              value: status,
                              child: Text(PaymentStatus.label(status)),
                            ),
                          )
                          .toList(),
                      onChanged: _saving
                          ? null
                          : (value) {
                              if (value == null) return;
                              setState(() {
                                _paymentStatus = value;
                                if (value != PaymentStatus.partial) {
                                  _paidAmountController.clear();
                                }
                              });
                            },
                    ),
                    if (_paymentStatus == PaymentStatus.partial) ...[
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _paidAmountController,
                        enabled: !_saving,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: 'Paid amount (₹) *',
                          prefixIcon: const Icon(Icons.currency_rupee),
                          helperText:
                              'Must be more than 0 and less than ${CurrencyUtils.format(calc.grandTotal)}',
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      _paymentPreviewText(calc.grandTotal),
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
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
        ),
        if (_catalogBusy)
          const ModalBarrier(dismissible: false, color: Color(0x33000000)),
        if (_catalogBusy)
          const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}

class _LineEditResult {
  const _LineEditResult({required this.quantity, required this.discount});

  final double quantity;
  final double discount;
}

class _LineEditDialog extends StatefulWidget {
  const _LineEditDialog({required this.line});

  final _CartLine line;

  @override
  State<_LineEditDialog> createState() => _LineEditDialogState();
}

class _LineEditDialogState extends State<_LineEditDialog> {
  late final TextEditingController _qtyController;
  late final TextEditingController _discountController;
  String? _error;

  @override
  void initState() {
    super.initState();
    final qty = widget.line.quantity;
    _qtyController = TextEditingController(
      text: qty == qty.roundToDouble()
          ? qty.toStringAsFixed(0)
          : qty.toStringAsFixed(2),
    );
    final disc = widget.line.discount;
    _discountController = TextEditingController(
      text: disc == 0
          ? ''
          : (disc == disc.roundToDouble()
              ? disc.toStringAsFixed(0)
              : disc.toStringAsFixed(2)),
    );
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  void _submit() {
    final qty = double.tryParse(_qtyController.text.trim());
    if (qty == null || qty <= 0) {
      setState(() => _error = 'Enter a valid quantity');
      return;
    }

    final discountText = _discountController.text.trim();
    final discount = discountText.isEmpty
        ? 0.0
        : double.tryParse(discountText);
    if (discount == null) {
      setState(() => _error = 'Enter a valid discount');
      return;
    }

    final gross = CurrencyUtils.roundMoney(widget.line.product.price * qty);
    final validation = GstService.validateDiscount(discount, gross);
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }

    Navigator.pop(
      context,
      _LineEditResult(
        quantity: CurrencyUtils.roundMoney(qty),
        discount: CurrencyUtils.roundMoney(discount),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.line.product.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _qtyController,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: const InputDecoration(
              labelText: 'Quantity *',
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _discountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: InputDecoration(
              labelText: 'Discount (₹)',
              helperText:
                  'Max ${CurrencyUtils.format(widget.line.product.price)} × qty',
              prefixIcon: const Icon(Icons.discount_outlined),
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: const TextStyle(color: AppTheme.danger, fontSize: 13),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _QuantityDialog extends StatefulWidget {
  const _QuantityDialog({required this.product, required this.initial});

  final Product product;
  final double initial;

  @override
  State<_QuantityDialog> createState() => _QuantityDialogState();
}

class _QuantityDialogState extends State<_QuantityDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial == widget.initial.roundToDouble()
        ? widget.initial.toStringAsFixed(0)
        : widget.initial.toStringAsFixed(2),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = double.tryParse(_controller.text.trim());
    if (value == null || value <= 0) return;
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.product.name),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
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
          onPressed: _submit,
          child: const Text('Add'),
        ),
      ],
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
