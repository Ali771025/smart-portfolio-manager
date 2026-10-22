import 'package:flutter/material.dart';

import '../widgets/manual_transaction_entry_form.dart';

class ManualTransactionEntryScreen extends StatelessWidget {
  const ManualTransactionEntryScreen({
    required this.portfolioId,
    required this.symbol,
    super.key,
  });

  final String portfolioId;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ثبت تراکنش دستی'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ManualTransactionEntryForm(
            portfolioId: portfolioId,
            symbol: symbol,
          ),
        ),
      ),
    );
  }
}
