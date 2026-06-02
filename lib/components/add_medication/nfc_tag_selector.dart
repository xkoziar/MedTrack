import 'package:flutter/material.dart';
import 'package:med_track/components/common/app_card.dart';
import 'package:med_track/components/common/nfc_icon_container.dart';
import 'package:med_track/database/model/nfc_tag.dart';
import 'package:med_track/utils/constants.dart';

class NfcTagSelector extends StatelessWidget {
  final Set<String> selectedNfcTagIds;
  final List<NfcTag> availableTags;
  final bool isScanning;
  final bool isLoadingTags;
  final VoidCallback onShowPicker;

  const NfcTagSelector({
    super.key,
    required this.selectedNfcTagIds,
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

    final selectedTags = availableTags
        .where((tag) => selectedNfcTagIds.contains(tag.id))
        .toList();

    if (selectedTags.isNotEmpty) {
      return Column(
        children: [
          ...selectedTags.map((tag) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: AppCard(
              child: Row(
                children: [
                  const NfcIconContainer(),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tag.name,
                          style: AppTextStyles.bodyMediumSemiBold,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'NFC Tag',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )),
          OutlinedButton.icon(
            onPressed: isScanning ? null : onShowPicker,
            icon: const Icon(Icons.edit),
            label: Text('Manage NFC Tags (${selectedTags.length})'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.all(AppSpacing.md),
            ),
          ),
        ],
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
