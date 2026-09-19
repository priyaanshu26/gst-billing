import 'package:flutter/material.dart';

import '../models/bill.dart';
import '../services/bill_service.dart';
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

  Future<void> _openCreate() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CreateInvoiceScreen()),
    );
  }

  void _openDetails(Bill bill) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InvoiceDetailsScreen(billId: bill.billId, bill: bill),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invoices')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.receipt_long),
        label: const Text('Create Invoice'),
      ),
      body: StreamBuilder<List<Bill>>(
        stream: _billService.watchBills(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load invoices.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.danger),
                ),
              ),
            );
          }

          final bills = snapshot.data ?? const [];
          if (bills.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No invoices yet.\nTap Create Invoice to generate one.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
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
                    '${AppDateUtils.formatDisplay(bill.invoiceDate)}',
                  ),
                  isThreeLine: true,
                  trailing: Text(
                    CurrencyUtils.format(bill.grandTotal),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onTap: () => _openDetails(bill),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
