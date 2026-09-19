import 'package:flutter/material.dart';

import '../models/bill.dart';
import '../services/bill_service.dart';
import '../theme/app_theme.dart';
import '../utils/currency_utils.dart';
import '../utils/date_utils.dart';
import '../widgets/live_refresh_builder.dart';
import 'invoice_details_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _billService = BillService();
  int _reload = 0;

  Future<void> _openBill(Bill bill) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InvoiceDetailsScreen(
          billId: bill.billId,
          bill: bill,
        ),
      ),
    );
    if (mounted) setState(() => _reload++);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      primary: false,
      body: LiveRefreshBuilder<List<Bill>>(
        key: ValueKey(_reload),
        load: _billService.getBills,
        listen: _billService.watchBills,
        errorTitle: 'Could not load dashboard.',
        builder: (context, bills) {
          final stats = _billService.buildDashboardStats(bills);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Overview',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.45,
                children: [
                  _StatCard(
                    label: "Today's sales",
                    value: CurrencyUtils.format(stats.todaySales),
                    icon: Icons.today_outlined,
                  ),
                  _StatCard(
                    label: "Today's bills",
                    value: '${stats.todayBillCount}',
                    icon: Icons.receipt_outlined,
                  ),
                  _StatCard(
                    label: "Today's tax",
                    value: CurrencyUtils.format(stats.todayTax),
                    icon: Icons.percent_outlined,
                  ),
                  _StatCard(
                    label: 'Monthly sales',
                    value: CurrencyUtils.format(stats.monthlySales),
                    icon: Icons.calendar_month_outlined,
                  ),
                  _StatCard(
                    label: 'Monthly bills',
                    value: '${stats.monthlyBillCount}',
                    icon: Icons.summarize_outlined,
                  ),
                  _StatCard(
                    label: 'Monthly tax',
                    value: CurrencyUtils.format(stats.monthlyTax),
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _StatCard(
                label: 'Total tax collected (all time)',
                value: CurrencyUtils.format(stats.totalTax),
                icon: Icons.account_balance_outlined,
                wide: true,
              ),
              const SizedBox(height: 24),
              Text(
                'Recent bills',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              if (stats.recentBills.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'No bills yet. Create an invoice to get started.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ),
                )
              else
                ...stats.recentBills.map(
                  (bill) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      child: ListTile(
                        title: Text(
                          bill.invoiceNo,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${bill.partyName} · '
                          '${AppDateUtils.formatDisplay(bill.invoiceDate)}',
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

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.wide = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: wide
            ? Row(
                children: [
                  Icon(icon, color: AppTheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          value,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: AppTheme.primary, size: 22),
                  const Spacer(),
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: const TextStyle(
                        fontSize: 18,
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
