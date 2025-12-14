import 'package:flutter/material.dart';
import '../common/app_card.dart';
import '../common/app_key_value.dart';

class UserStatsCard extends StatelessWidget {
  final String thisWeek;
  final String thisMonth;
  final String daysStreak;


  const UserStatsCard({
    super.key,
    required this.thisWeek,
    required this.thisMonth,
    required this.daysStreak,
  });

  @override
  Widget build(BuildContext context) {

    final rows = <(String, String)>[
      ('This week', thisWeek ),
      ('This month', thisMonth),
      ('Days streak', daysStreak),
    ];

    return AppCard(
      child: AppKeyValueColumn(title: '📊 Stats', rows: rows),
    );
  }
}
