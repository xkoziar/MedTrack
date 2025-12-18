import 'package:flutter/material.dart';
import 'package:med_track/database/ioc/ioc_container.dart';
import 'package:med_track/database/model/nfc_tag.dart';
import 'package:med_track/database/service/auth_service.dart';
import 'package:med_track/database/service/nfc_background_service.dart';
import 'package:med_track/database/service/nfc_tag_database_service.dart';
import 'package:med_track/database/service/nfc_writer_service.dart';
import 'package:med_track/utils/constants.dart';
import 'package:med_track/utils/snackbar_utils.dart';
import 'package:nfc_manager/nfc_manager.dart' as nfc_manager;

/// Reusable NFC tag dialogs
class NfcTagDialogs {
  /// Show dialog to name and create new NFC tag
  static Future<NfcTag?> showNameNewTagDialog(
    BuildContext context,
    String tagId, {
    nfc_manager.NfcTag? nfcTag,
    List<String>? initialMedicationIds,
    bool pauseScanning = false,
  }) async {
    final nameController = TextEditingController();
    final authService = get<AuthService>();
    final nfcTagService = get<NfcTagDatabaseService>();
    final nfcWriter = get<NfcWriterService>();
    final nfcService = get<NfcBackgroundService>();

    if (nfcTag != null) {
      try {
        await nfcWriter.writeAppLaunchRecordToTag(nfcTag, tagId);
      } catch (e) {
        // Ignore write errors
      }
    }

    if (pauseScanning) {
      await nfcService.startIgnoringScans();
    }

    if (!context.mounted) return null;

    final result = await showDialog<NfcTag>(
      context: context,
      barrierDismissible: !pauseScanning,
      builder: (ctx) => AlertDialog(
        title: const Text('Name Your NFC Tag'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tag ID: $tagId',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Tag Name',
                  hintText: 'e.g., Morning Meds, Bedside Table',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                showSnackBar(ctx, 'Please enter a name');
                return;
              }

              final userId = authService.user?.uid;
              if (userId == null) {
                Navigator.of(ctx).pop();
                return;
              }

              try {
                final newTag = NfcTag(
                  userId: userId,
                  tagId: tagId,
                  name: name,
                  medicationIds: initialMedicationIds ?? [],
                );

                await nfcTagService.create(newTag);

                if (!ctx.mounted) return;

                Navigator.of(ctx).pop(newTag);

                showSnackBar(
                  ctx,
                  'Tag "$name" created successfully',
                  backgroundColor: AppColors.success,
                );
              } catch (e) {
                Navigator.of(ctx).pop();

                if (!ctx.mounted) return;
                showSnackBar(
                  ctx,
                  'Error creating tag: $e',
                  backgroundColor: AppColors.danger,
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (pauseScanning) {
      nfcService.stopIgnoringScans();
    }

    return result;
  }

  /// Show a dialog to rename an existing NFC tag
  static Future<String?> showRenameTagDialog(
    BuildContext context,
    String currentName,
  ) async {
    final nameController = TextEditingController(text: currentName);

    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename NFC Tag'),
        content: SingleChildScrollView(
          child: TextField(
            controller: nameController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Tag Name',
              hintText: 'e.g., Morning Meds, Bedside Table',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final newName = nameController.text.trim();
              if (newName.isEmpty) {
                showSnackBar(ctx, 'Please enter a name');
                return;
              }
              Navigator.of(ctx).pop(newName);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  /// Show confirmation dialog before deleting NFC tag
  static Future<bool> showDeleteTagDialog(
    BuildContext context,
    String tagName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete NFC Tag?'),
        content: SingleChildScrollView(
          child: Text(
            'Are you sure you want to delete "$tagName"?\n\n'
            'This will remove the tag from all medications.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    return confirmed ?? false;
  }

  /// Show dialog with tag options (rename/delete)
  static Future<void> showTagOptionsDialog(
    BuildContext context,
    NfcTag tag, {
    required VoidCallback onUpdated,
  }) async {
    final nfcTagService = get<NfcTagDatabaseService>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tag.name),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tag ID: ${tag.tagId}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Rename'),
              onTap: () async {
                Navigator.of(ctx).pop();

                final newName = await showRenameTagDialog(context, tag.name);
                if (newName != null && newName != tag.name) {
                  await nfcTagService.update(tag.id, tag.copyWith(name: newName));

                  if (context.mounted) {
                    showSnackBar(
                      context,
                      'Tag renamed to "$newName"',
                      backgroundColor: AppColors.success,
                    );
                    onUpdated();
                  }
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: AppColors.danger),
              title: Text('Delete', style: TextStyle(color: AppColors.danger)),
              onTap: () async {
                Navigator.of(ctx).pop();

                final confirmed = await showDeleteTagDialog(context, tag.name);
                if (confirmed) {
                  await nfcTagService.delete(tag.id);

                  if (context.mounted) {
                    showSnackBar(
                      context,
                      'Tag "${tag.name}" deleted',
                      backgroundColor: AppColors.success,
                    );
                    onUpdated();
                  }
                }
              },
            ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
