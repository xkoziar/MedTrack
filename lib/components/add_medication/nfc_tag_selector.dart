import 'package:flutter/material.dart';
import 'package:med_track/components/common/app_card.dart';
import 'package:med_track/database/model/nfc_tag.dart';
import 'package:med_track/utils/constants.dart';

class NfcTagSelector extends StatelessWidget {
  final String? selectedNfcTagId;
  final List<NfcTag> availableTags;
  final bool isScanning;
  final bool isLoadingTags;
  final VoidCallback onShowPicker;

  const NfcTagSelector({
    super.key,
    required this.selectedNfcTagId,
    required this.availableTags,
    required this.isScanning,
    required this.isLoadingTags,
    required this.onShowPicker,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoadingTags) {
      return const Center(child: CircularProgressIndicator());
    }

    final selectedTag = availableTags.firstWhere(
      (tag) => tag.id == selectedNfcTagId,
      orElse: () => NfcTag(
        userId: '',
        tagId: '',
        name: '',
        medicationIds: [],
      ),
    );

    if (selectedNfcTagId != null && selectedTag.name.isNotEmpty) {
      return AppCard(
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: AppGradients.green,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.nfc, color: Colors.white, size: 24),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectedTag.name,
                    style: AppTextStyles.bodyMediumSemiBold,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'NFC Tag Selected',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: onShowPicker,
              tooltip: 'Change NFC tag',
            ),
          ],
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: isScanning ? null : onShowPicker,
      icon: isScanning
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.nfc),
      label: Text(isScanning ? 'Scanning...' : 'Add NFC Tag'),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.all(AppSpacing.md),
      ),
    );
  }
}
