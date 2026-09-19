import 'package:flutter/material.dart';

import '../models/bill.dart';
import '../theme/app_theme.dart';

class PaymentStatusChip extends StatelessWidget {
  const PaymentStatusChip({
    super.key,
    required this.paymentStatus,
    this.compact = false,
  });

  final String paymentStatus;
  final bool compact;

  Color get _color {
    switch (paymentStatus) {
      case PaymentStatus.paid:
        return AppTheme.success;
      case PaymentStatus.partial:
        return AppTheme.warning;
      case PaymentStatus.unpaid:
      default:
        return AppTheme.danger;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Chip(
      visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
      backgroundColor: color.withValues(alpha: 0.12),
      side: BorderSide.none,
      label: Text(
        PaymentStatus.label(paymentStatus),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: compact ? 11 : 12,
        ),
      ),
    );
  }
}
