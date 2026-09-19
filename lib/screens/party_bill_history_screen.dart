import 'package:flutter/material.dart';

import '../models/bill.dart';
import '../models/party.dart';
import '../services/bill_service.dart';
import '../services/party_service.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';
import '../utils/currency_utils.dart';
import '../utils/date_utils.dart';
import '../widgets/live_refresh_builder.dart';
import 'invoice_details_screen.dart';
import 'party_form_screen.dart';

class PartyBillHistoryScreen extends StatefulWidget {
  const PartyBillHistoryScreen({super.key, required this.party});

  final Party party;

  @override
  State<PartyBillHistoryScreen> createState() => _PartyBillHistoryScreenState();
}

class _PartyBillHistoryScreenState extends State<PartyBillHistoryScreen> {
  final _billService = BillService();
  final _partyService = PartyService();

  late Party _party;
  int _reload = 0;

  @override
  void initState() {
    super.initState();
    _party = widget.party;
  }

  Future<void> _edit() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PartyFormScreen(party: _party)),
    );
    if (!mounted) return;
    final fresh = await _partyService.getParty(_party.partyId);
    if (fresh != null && mounted) {
      setState(() {
        _party = fresh;
        _reload++;
      });
    }
  }

  Future<void> _openBill(Bill bill) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InvoiceDetailsScreen(billId: bill.billId, bill: bill),
      ),
    );
    if (mounted) setState(() => _reload++);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Party History'),
        actions: [
          if (SessionService.instance.canManageShop)
            IconButton(
              tooltip: 'Edit party',
              onPressed: _edit,
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
      body: LiveRefreshBuilder<List<Bill>>(
        key: ValueKey('${_party.partyId}-$_reload'),
        load: () => _billService.getPartyBills(_party.partyId),
        listen: () => _billService.watchPartyBills(_party.partyId),
        errorTitle: 'Could not load bills for this party.',
        builder: (context, bills) {
          final totalBilled = bills.fold<double>(
            0,
            (sum, bill) => sum + bill.grandTotal,
          );
          final totalTax = bills.fold<double>(
            0,
            (sum, bill) => sum + bill.totalTax,
          );

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _party.name,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        [
                          if (_party.mobile.isNotEmpty) _party.mobile,
                          _party.state,
                          if (_party.gstin.isNotEmpty) 'GSTIN ${_party.gstin}',
                        ].join(' · '),
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      if (_party.address.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          _party.address,
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _SummaryTile(
                      label: 'Bills',
                      value: '${bills.length}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryTile(
                      label: 'Total billed',
                      value: CurrencyUtils.format(
                        CurrencyUtils.roundMoney(totalBilled),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryTile(
                      label: 'Total tax',
                      value: CurrencyUtils.format(
                        CurrencyUtils.roundMoney(totalTax),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Bills',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              if (bills.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'No bills for this party yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ),
                )
              else
                ...bills.map(
                  (bill) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              AppTheme.primary.withValues(alpha: 0.12),
                          foregroundColor: AppTheme.primary,
                          child: const Icon(Icons.receipt_long),
                        ),
                        title: Text(
                          bill.invoiceNo,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${AppDateUtils.formatDisplay(bill.invoiceDate)}'
                          ' · ${PaymentStatus.label(bill.paymentStatus)}',
                        ),
                        trailing: Text(
                          CurrencyUtils.format(bill.grandTotal),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        onTap: () => _openBill(bill),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
