import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/bill.dart';
import '../models/shop_config.dart';
import '../services/bill_service.dart';
import '../services/gst_service.dart';
import '../services/pdf_service.dart';
import '../services/session_service.dart';
import '../services/shop_config_service.dart';
import '../theme/app_theme.dart';
import '../utils/currency_utils.dart';
import '../utils/date_utils.dart';
import '../widgets/invoice_summary_widgets.dart';
import '../widgets/payment_status_chip.dart';

class InvoiceDetailsScreen extends StatefulWidget {
  const InvoiceDetailsScreen({
    super.key,
    required this.billId,
    this.bill,
  });

  final String billId;
  final Bill? bill;

  @override
  State<InvoiceDetailsScreen> createState() => _InvoiceDetailsScreenState();
}

class _InvoiceDetailsScreenState extends State<InvoiceDetailsScreen> {
  final _billService = BillService();
  final _shopConfigService = ShopConfigService();
  final _pdfService = PdfService();
  final _paidAmountController = TextEditingController();

  Bill? _bill;
  bool _loading = true;
  Object? _error;
  bool _pdfBusy = false;
  bool _saving = false;
  String _paymentStatus = PaymentStatus.unpaid;

  bool get _canEditPayment => SessionService.instance.canManageShop;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _paidAmountController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final live = await _billService.getBill(widget.billId);
      final bill = live ?? widget.bill;
      if (!mounted) return;
      setState(() {
        _applyBill(bill);
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
        if (widget.bill != null) {
          _applyBill(widget.bill);
        }
      });
    }
  }

  void _applyBill(Bill? bill) {
    _bill = bill;
    if (bill == null) return;
    _paymentStatus = bill.paymentStatus;
    if (bill.paymentStatus == PaymentStatus.partial && bill.paidAmount > 0) {
      final paid = bill.paidAmount;
      _paidAmountController.text = paid == paid.roundToDouble()
          ? paid.toStringAsFixed(0)
          : paid.toStringAsFixed(2);
    } else {
      _paidAmountController.text = '';
    }
  }

  Future<ShopConfig> _shopConfig() => _shopConfigService.getOrCreateDefault();

  double? _parsedPaidAmount() {
    final text = _paidAmountController.text.trim();
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  String _paymentPreviewText(double grandTotal) {
    final breakdown = Bill.resolvePayment(
      paymentStatus: _paymentStatus,
      grandTotal: grandTotal,
      paidAmount:
          _paymentStatus == PaymentStatus.partial ? _parsedPaidAmount() : null,
    );
    return 'Paid ${CurrencyUtils.format(breakdown.paidAmount)}'
        ' · Remaining ${CurrencyUtils.format(breakdown.remainingAmount)}';
  }

  Future<void> _savePayment() async {
    final bill = _bill;
    if (bill == null || !_canEditPayment || _saving) return;

    if (_paymentStatus == PaymentStatus.partial) {
      final text = _paidAmountController.text.trim();
      if (text.isNotEmpty && _parsedPaidAmount() == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid paid amount')),
        );
        return;
      }
    }

    final paidInput =
        _paymentStatus == PaymentStatus.partial ? _parsedPaidAmount() : null;
    final paymentError = Bill.validatePayment(
      paymentStatus: _paymentStatus,
      grandTotal: bill.grandTotal,
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
      final updated = await _billService.updatePayment(
        bill: bill,
        paymentStatus: _paymentStatus,
        paidAmount: paidInput,
      );
      if (!mounted) return;
      setState(() => _applyBill(updated));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment updated')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$error'),
          backgroundColor: AppTheme.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _preview(Bill bill) async {
    setState(() => _pdfBusy = true);
    try {
      final shop = await _shopConfig();
      await _pdfService.previewInvoice(bill: bill, shop: shop);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF preview failed: $error'),
          backgroundColor: AppTheme.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _pdfBusy = false);
    }
  }

  Future<void> _share(Bill bill) async {
    setState(() => _pdfBusy = true);
    try {
      final shop = await _shopConfig();
      await _pdfService.shareInvoice(bill: bill, shop: shop);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF share failed: $error'),
          backgroundColor: AppTheme.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _pdfBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bill = _bill;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice'),
      ),
      body: _buildBody(),
      bottomNavigationBar: bill == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pdfBusy || _saving
                            ? null
                            : () => _preview(bill),
                        icon: const Icon(Icons.visibility_outlined),
                        label: const Text('Preview PDF'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed:
                            _pdfBusy || _saving ? null : () => _share(bill),
                        icon: _pdfBusy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.share_outlined),
                        label: const Text('Share PDF'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_bill == null) {
      return Center(
        child: Text(
          _error == null
              ? 'Invoice not found'
              : 'Failed to load invoice.\n$_error',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.danger),
        ),
      );
    }

    final bill = _bill!;
    final summary = GstService.summarize(bill.items);
    final isIntra = summary.totalIgst == 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Card(
          color: AppTheme.primary.withValues(alpha: 0.06),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        bill.invoiceNo,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    PaymentStatusChip(paymentStatus: bill.paymentStatus),
                  ],
                ),
                const SizedBox(height: 4),
                Text(AppDateUtils.formatDisplay(bill.invoiceDate)),
                const SizedBox(height: 4),
                Text(
                  'Paid ${CurrencyUtils.format(bill.paidAmount)}'
                  ' · Remaining ${CurrencyUtils.format(bill.remainingAmount)}',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            title: Text(
              bill.partyName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              [
                if (bill.partyAddress.isNotEmpty) bill.partyAddress,
                bill.partyState,
                if (bill.partyGSTIN.isNotEmpty) bill.partyGSTIN,
              ].join('\n'),
            ),
            isThreeLine: bill.partyAddress.isNotEmpty,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Items',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        InvoiceItemsTable(items: bill.items),
        const SizedBox(height: 8),
        InvoiceTotalsCard(
          subtotal: bill.subtotal,
          totalTax: bill.totalTax,
          grandTotal: bill.grandTotal,
          totalGross: summary.totalGross,
          totalDiscount: summary.totalDiscount,
          totalCgst: summary.totalCgst,
          totalSgst: summary.totalSgst,
          totalIgst: summary.totalIgst,
          isIntraState: isIntra,
        ),
        const SizedBox(height: 12),
        Text(
          'Payment',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        _paymentCard(bill),
        const SizedBox(height: 16),
        Text(
          'Grand total: ${CurrencyUtils.format(bill.grandTotal)}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
        ),
      ],
    );
  }

  Widget _paymentCard(Bill bill) {
    if (!_canEditPayment) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _paymentRow(
                'Payment status',
                PaymentStatus.label(bill.paymentStatus),
              ),
              _paymentRow(
                'Paid amount',
                CurrencyUtils.format(bill.paidAmount),
              ),
              _paymentRow(
                'Remaining',
                CurrencyUtils.format(bill.remainingAmount),
                emphasize: bill.remainingAmount > 0,
              ),
            ],
          ),
        ),
      );
    }

    return Card(
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
                      'Must be more than 0 and less than ${CurrencyUtils.format(bill.grandTotal)}',
                ),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              _paymentPreviewText(bill.grandTotal),
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: _saving ? null : _savePayment,
              child: _saving
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Update payment'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _paymentRow(String label, String value, {bool emphasize = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: emphasize ? AppTheme.warning : null,
            ),
          ),
        ],
      ),
    );
  }
}
