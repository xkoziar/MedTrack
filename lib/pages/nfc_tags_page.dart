import 'package:flutter/material.dart';
import 'package:med_track/components/common/gradient_header.dart';
import 'package:med_track/components/nfc/nfc_tag_dialogs.dart';
import 'package:med_track/database/ioc/ioc_container.dart';
import 'package:med_track/database/model/nfc_tag.dart';
import 'package:med_track/database/service/auth_service.dart';
import 'package:med_track/database/service/medication_database_service.dart';
import 'package:med_track/database/service/nfc_tag_database_service.dart';
import 'package:med_track/utils/constants.dart';
import 'package:med_track/utils/snackbar_utils.dart';

class NfcTagsPage extends StatefulWidget {
  const NfcTagsPage({super.key});

  @override
  State<NfcTagsPage> createState() => _NfcTagsPageState();
}

class _NfcTagsPageState extends State<NfcTagsPage> {
  final _nfcTagService = get<NfcTagDatabaseService>();
  final _medicationService = get<MedicationDatabaseService>();
  final _authService = get<AuthService>();

  List<NfcTag> _tags = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  Future<void> _loadTags() async {
    final userId = _authService.user?.uid;
    if (userId == null) return;

    setState(() => _isLoading = true);

    try {
      final tags = await _nfcTagService.getUserTags(userId);
      setState(() {
        _tags = tags;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        showSnackBar(
          context,
          'Error loading tags: $e',
          backgroundColor: AppColors.danger,
        );
      }
    }
  }

  Future<void> _deleteTag(NfcTag tag) async {
    final confirmed = await NfcTagDialogs.showDeleteTagDialog(context, tag.name);

    if (confirmed) {
      try {
        await _nfcTagService.delete(tag.id);
        await _loadTags();

        if (mounted) {
          showSnackBar(
            context,
            'Tag "${tag.name}" deleted',
            backgroundColor: AppColors.success,
          );
        }
      } catch (e) {
        if (mounted) {
          showSnackBar(
            context,
            'Error deleting tag: $e',
            backgroundColor: AppColors.danger,
          );
        }
      }
    }
  }

  Future<void> _renameTag(NfcTag tag) async {
    final newName = await NfcTagDialogs.showRenameTagDialog(context, tag.name);

    if (newName != null && newName.isNotEmpty && newName != tag.name) {
      try {
        await _nfcTagService.updateTagName(tag.id, newName);
        await _loadTags();

        if (mounted) {
          showSnackBar(
            context,
            'Tag renamed to "$newName"',
            backgroundColor: AppColors.success,
          );
        }
      } catch (e) {
        if (mounted) {
          showSnackBar(
            context,
            'Error renaming tag: $e',
            backgroundColor: AppColors.danger,
          );
        }
      }
    }
  }

  Future<int> _getMedicationCount(NfcTag tag) async {
    final userId = _authService.user?.uid;
    if (userId == null) return 0;

    try {
      final medications = await _medicationService.getUserMedications(userId);
      return medications.where((med) => med.nfcTagId == tag.id).length;
    } catch (e) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          GradientSliverHeader(
            title: 'NFC Tags',
            subtitle: 'Manage your NFC tags',
            onBack: () => Navigator.of(context).pop(),
          ),
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_tags.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.nfc, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No NFC tags',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Add tags when creating medications',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final tag = _tags[index];
                    return FutureBuilder<int>(
                      future: _getMedicationCount(tag),
                      builder: (context, snapshot) {
                        final medCount = snapshot.data ?? 0;
                        return Card(
                          margin: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: AppGradients.green,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.nfc,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            title: Text(
                              tag.name,
                              style: AppTextStyles.bodyBold,
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  'Tag ID: ${tag.tagId}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$medCount medication${medCount != 1 ? 's' : ''}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'rename') {
                                  _renameTag(tag);
                                } else if (value == 'delete') {
                                  _deleteTag(tag);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'rename',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit, size: 20),
                                      SizedBox(width: 12),
                                      Text('Rename'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete, size: 20, color: AppColors.danger),
                                      SizedBox(width: 12),
                                      Text('Delete', style: TextStyle(color: AppColors.danger)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                  childCount: _tags.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
