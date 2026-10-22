import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

import 'dashboard_glass_card.dart';

class DashboardLoadingState extends StatelessWidget {
  const DashboardLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    final placeholders = List<Widget>.generate(
      4,
      (index) => const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: DashboardGlassCard(
          child: SizedBox(height: 96, width: double.infinity),
        ),
      ),
    );
    return Skeletonizer(
      enabled: true,
      child: Column(children: placeholders),
    );
  }
}
