import 'package:flutter/material.dart';

import '../models/bill.dart';
import '../services/bill_csv_export_service.dart';
import '../services/bill_service.dart';
import '../services/pdf_service.dart';
import '../services/shop_config_service.dart';
import '../theme/app_theme.dart';
import '../utils/currency_utils.dart';
import '../utils/date_utils.dart';
import 'create_invoice_screen.dart';
import 'invoice_details_screen.dart';

class BillListScreen extends StatefulWidget {
  const BillListScreen({super.key});

  @override
  State<BillListScreen> createState() => _BillListScreenState();
}

class _BillListScreenState extends State<BillListScreen> {
  final _billService = BillService();
  final _shopConfigService = ShopConfigService();
  final _pdfService = PdfService();
  final _csvExportService = BillCsvExportService();
  final _searchController = TextEditingController();

  String _query = '';
  bool _pdfBusy = false;
  bool _exportBusy = false;
  DateTimeRange? _dateRange;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openCreate() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CreateInvoiceScreen()),
    );
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _dateRange,
      helpText: 'Filter bills by date',
    );
    if (picked == null || !mounted) return;
    setState(() => _dateRange = picked);
  }

  void _openDetails(Bill bill) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InvoiceDetailsScreen(billId: bill.billId, bill: bill),
      ),
    );
  }

  Future<void> _viewPdf(Bill bill) async {
    setState(() => _pdfBusy = true);
    try {
      final shop = await _shopConfigService.getOrCreateDefault();
      await _pdfService.previewInvoice(bill: bill, shop: shop);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF failed: $error'),
          backgroundColor: AppTheme.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _pdfBusy = false);
    }
  }

  Future<void> _exportCsv(List<Bill> bills) async {
    if (bills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No bills to export')),
      );
      return;
    }

    setState(() => _exportBusy = true);
    try {
      await _csvExportService.shareCsv(List<Bill>.from(bills));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exported ${bills.length} bill(s) as CSV')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('CSV export failed: $error'),
          backgroundColor: AppTheme.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _exportBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Bill>>(
      stream: _billService.watchBills(),
      builder: (context, snapshot) {
        final bills = _billService.filterBills(
          snapshot.data ?? const [],
          _query,
          from: _dateRange?.start,
          to: _dateRange?.end,
        );
        final canExport = !_exportBusy && bills.isNotEmpty;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Bill History'),
            actions: [
              IconButton(
                tooltip: 'Export CSV',
                onPressed: canExport ? () => _exportCsv(bills) : null,
                icon: _exportBusy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.file_download_outlined),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'fab_bills',
            onPressed: _openCreate,
            icon: const Icon(Icons.receipt_long),
            label: const Text('Create Invoice'),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by party or invoice no...',
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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickDateRange,
                        icon: const Icon(Icons.date_range_outlined, size: 18),
                        label: Text(
                          _dateRange == null
                              ? 'All dates'
                              : '${AppDateUtils.formatDisplay(_dateRange!.start)}'
                                  ' - '
                                  '${AppDateUtils.formatDisplay(_dateRange!.end)}',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ),
                    if (_dateRange != null) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Clear date filter',
                        onPressed: () => setState(() => _dateRange = null),
                        icon: const Icon(Icons.filter_alt_off_outlined),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(child: _buildBillList(snapshot, bills)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBillList(
    AsyncSnapshot<List<Bill>> snapshot,
    List<Bill> bills,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting &&
        !snapshot.hasData) {
      return const Center(child: CircularProgressIndicator());
    }

    if (snapshot.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Could not load bills.\n${snapshot.error}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.danger),
          ),
        ),
      );
    }

    if (bills.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _query.isEmpty && _dateRange == null
                ? 'No bills yet.\nTap Create Invoice to generate one.'
                : 'No bills match your search.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
      itemCount: bills.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final bill = bills[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
              foregroundColor: AppTheme.primary,
              child: const Icon(Icons.receipt_long),
            ),
            title: Text(
              bill.invoiceNo,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              '${bill.partyName}\n'
              '${AppDateUtils.formatDisplay(bill.invoiceDate)}'
              ' · ${PaymentStatus.label(bill.paymentStatus)}',
            ),
            isThreeLine: true,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  CurrencyUtils.format(bill.grandTotal),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'open') {
                      _openDetails(bill);
                    } else if (value == 'pdf') {
                      _viewPdf(bill);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'open',
                      child: Text('Open bill'),
                    ),
                    PopupMenuItem(
                      value: 'pdf',
                      enabled: !_pdfBusy,
                      child: const Text('Print / Preview PDF'),
                    ),
                  ],
                ),
              ],
            ),
            onTap: () => _openDetails(bill),
          ),
        );
      },
    );
  }
}
