import 'package:flutter/material.dart';
import 'package:med_track/components/common/app_card.dart';
import 'package:med_track/database/model/app_user.dart';
import 'package:med_track/utils/constants.dart';
import 'package:med_track/utils/helpers/account_share_payload.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ShareAccountCard extends StatelessWidget {
  final AppUser user;

  const ShareAccountCard({super.key, required this.user});

  String get _sharePayload {
    return AccountSharePayload(
      userId: user.id ?? '',
      name: user.name,
      email: user.email,
    ).encode();
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Share account', style: AppTextStyles.heading3),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Show this QR code to a family member or caregiver. When they scan it '
            'from their own MedTrack account, they will be linked to yours.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: AppButtonStyles.primaryButton,
              onPressed: () => _showQrSheet(context),
              icon: const Icon(Icons.qr_code_2_rounded),
              label: const Text('Generate QR code'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showQrSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: AppPadding.page,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text('Share account', style: AppTextStyles.heading3),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Ask your caregiver to open the QR scanner on their Profile '
                  'tab and scan this code to link to your account.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: QrImageView(
                    data: _sharePayload,
                    size: 240,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Color(0xFF2F3B8F),
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(user.name, style: AppTextStyles.bodyMediumSemiBold),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  user.email,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: AppButtonStyles.primaryOutlinedButton,
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
