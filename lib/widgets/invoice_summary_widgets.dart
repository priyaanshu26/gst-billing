import 'package:flutter/material.dart';

import '../models/bill_item.dart';
import '../theme/app_theme.dart';
import '../utils/currency_utils.dart';

class InvoiceTotalsCard extends StatelessWidget {
  const InvoiceTotalsCard({
    super.key,
    required this.subtotal,
    required this.totalTax,
    required this.grandTotal,
    this.totalGross,
    this.totalDiscount,
    this.totalCgst,
    this.totalSgst,
    this.totalIgst,
    this.isIntraState,
  });

  final double subtotal;
  final double totalTax;
  final double grandTotal;
  final double? totalGross;
  final double? totalDiscount;
  final double? totalCgst;
  final double? totalSgst;
  final double? totalIgst;
  final bool? isIntraState;

  @override
  Widget build(BuildContext context) {
    final discount = totalDiscount ?? 0;
    final showGross = totalGross != null && discount > 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (showGross)
              _row('Gross', CurrencyUtils.format(totalGross!)),
            if (discount > 0)
              _row('Discount', '- ${CurrencyUtils.format(discount)}'),
            _row(
              discount > 0 ? 'Taxable subtotal' : 'Subtotal',
              CurrencyUtils.format(subtotal),
            ),
            if (isIntraState == true) ...[
              _row('CGST', CurrencyUtils.format(totalCgst ?? 0)),
              _row('SGST', CurrencyUtils.format(totalSgst ?? 0)),
            ] else if (isIntraState == false) ...[
              _row('IGST', CurrencyUtils.format(totalIgst ?? 0)),
            ],
            _row('Total Tax', CurrencyUtils.format(totalTax)),
            const Divider(height: 20),
            _row(
              'Grand Total',
              CurrencyUtils.format(grandTotal),
              emphasize: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool emphasize = false}) {
    final style = TextStyle(
      fontSize: emphasize ? 18 : 15,
      fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
      color: emphasize ? AppTheme.primary : null,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class InvoiceItemsTable extends StatelessWidget {
  const InvoiceItemsTable({super.key, required this.items});

  final List<BillItem> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            ListTile(
              title: Text(
                items[i].name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                'Qty ${items[i].quantity} × ${CurrencyUtils.format(items[i].rate)}'
                '${items[i].discount > 0 ? ' · Disc ${CurrencyUtils.format(items[i].discount)}' : ''}'
                ' · Taxable ${CurrencyUtils.format(items[i].taxableAmount)}'
                ' · GST ${items[i].gstPercent.toStringAsFixed(0)}%'
                '${items[i].hsnCode.isEmpty ? '' : ' · HSN ${items[i].hsnCode}'}',
              ),
              isThreeLine: items[i].discount > 0,
              trailing: Text(
                CurrencyUtils.format(items[i].lineTotal),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
