import 'package:flutter/material.dart';

import '../models/bill.dart';
import '../models/shop_config.dart';
import '../services/bill_service.dart';
import '../services/gst_service.dart';
import '../services/pdf_service.dart';
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

  late Future<Bill?> _future;
  bool _pdfBusy = false;

  @override
  void initState() {
    super.initState();
    _future = widget.bill != null
        ? Future.value(widget.bill)
        : _billService.getBill(widget.billId);
  }

  Future<ShopConfig> _shopConfig() => _shopConfigService.getOrCreateDefault();

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
    return FutureBuilder<Bill?>(
      future: _future,
      builder: (context, snapshot) {
        final bill = snapshot.data;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Invoice'),
            actions: [
              if (bill != null) ...[
                IconButton(
                  tooltip: 'Preview PDF',
                  onPressed: _pdfBusy ? null : () => _preview(bill),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                ),
                IconButton(
                  tooltip: 'Share / Download PDF',
                  onPressed: _pdfBusy ? null : () => _share(bill),
                  icon: const Icon(Icons.share_outlined),
                ),
              ],
            ],
          ),
          body: _buildBody(snapshot),
          bottomNavigationBar: bill == null
              ? null
              : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pdfBusy ? null : () => _preview(bill),
                            icon: const Icon(Icons.visibility_outlined),
                            label: const Text('Preview PDF'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _pdfBusy ? null : () => _share(bill),
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
      },
    );
  }

  Widget _buildBody(AsyncSnapshot<Bill?> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }
    if (snapshot.hasError) {
      return Center(
        child: Text(
          'Failed to load invoice.\n${snapshot.error}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.danger),
        ),
      );
    }

    final bill = snapshot.data;
    if (bill == null) {
      return const Center(child: Text('Invoice not found'));
    }

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
        Card(
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
        ),
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
