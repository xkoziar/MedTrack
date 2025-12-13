import 'package:flutter/material.dart';
import '../../utils/constants.dart';

class AppKeyValueColumn extends StatelessWidget {
  final String title;
  final List<(String, String)> rows;

  const AppKeyValueColumn({
    super.key,
    required this.title,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.heading3),
        const SizedBox(height: AppSpacing.sm),
        ...rows.map(
              (r) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: AppKeyValueRow(k: r.$1, v: r.$2),
          ),
        ),
      ],
    );
  }
}

class AppKeyValueRow extends StatelessWidget {
  final String k;
  final String v;

  const AppKeyValueRow({super.key, required this.k, required this.v});

  @override
  Widget build(BuildContext context) {
    final base = DefaultTextStyle.of(context).style;

    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$k: ',
            style: base.copyWith(fontWeight: FontWeight.w700),
          ),
          TextSpan(
            text: v,
            style: base.copyWith(color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}
