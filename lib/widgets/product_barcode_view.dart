import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Renders a real Code128 barcode image for [value], or a placeholder if empty.
class ProductBarcodeView extends StatelessWidget {
  const ProductBarcodeView({
    super.key,
    required this.value,
    this.height = 88,
  });

  final String value;
  final double height;

  @override
  Widget build(BuildContext context) {
    final code = value.trim();
    if (code.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.border),
        ),
        child: Text(
          'No barcode assigned yet',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.border),
          ),
          child: BarcodeWidget(
            barcode: Barcode.code128(),
            data: code,
            width: double.infinity,
            height: height,
            drawText: false,
            errorBuilder: (context, error) => Text(
              'Could not render barcode.\n$error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.danger),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          code,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}
