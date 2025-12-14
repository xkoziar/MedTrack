import 'package:flutter/material.dart';

import '../../utils/constants.dart';
import 'app_card.dart';

class AdherenceRateCard extends StatelessWidget {
  final String rate;
  final String period;

  const AdherenceRateCard({
    super.key,
    required this.rate,
    required this.period,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      gradient: AppGradients.purple,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            rate,
            style: AppTextStyles.adherenceRate
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Adherence rate over ($period)',
            style: TextStyle(color: Colors.white),
            ),
        ],
      ),
    );
  }
}
