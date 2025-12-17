import 'package:flutter/material.dart';
import 'package:med_track/components/common/app_card.dart';
import 'package:med_track/database/model/nfc_tag.dart';
import 'package:med_track/utils/constants.dart';
import 'package:med_track/components/common/nfc_icon_container.dart';

class NfcTagCard extends StatelessWidget {
  final NfcTag tag;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool showChevron;

  const NfcTagCard({
    super.key,
    required this.tag,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    final Widget cardContent = Row(
      children: [
        const NfcIconContainer(),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tag.name, style: AppTextStyles.bodyMediumSemiBold),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle!,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null)
          trailing!
        else if (showChevron)
          Icon(Icons.chevron_right, color: AppColors.textSecondary),
      ],
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: AppCard(child: cardContent),
      );
    }

    return AppCard(child: cardContent);
  }
}
