import 'package:flutter/material.dart';
import 'package:med_track/components/common/gradient_header.dart';
import 'package:med_track/components/nfc/nfc_tag_dialogs.dart';
import 'package:med_track/components/nfc/nfc_tag_card.dart';
import 'package:med_track/database/ioc/ioc_container.dart';
import 'package:med_track/database/model/nfc_tag.dart';
import 'package:med_track/database/service/auth_service.dart';
import 'package:med_track/database/service/medication_database_service.dart';
import 'package:med_track/database/service/nfc/nfc_tag_database_service.dart';
import 'package:med_track/utils/constants.dart';
import 'package:med_track/utils/snackbar_utils.dart';
import 'package:med_track/pages/home/empty_state.dart';

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
  int _refreshKey = 0;

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

  Future<void> _manageMedications(NfcTag tag) async {
    await NfcTagDialogs.showManageMedicationsDialog(context, tag);
    await _loadTags();
    setState(() => _refreshKey++);
  }

  Future<int> _getMedicationCount(NfcTag tag) async {
    final userId = _authService.user?.uid;
    if (userId == null) return 0;

    try {
      final medications = await _medicationService.getUserMedications(userId);
      final assigned = medications.where((med) => med.nfcTagIds.contains(tag.id)).toList();
      final count = assigned.length;

      debugPrint('=== Medication Count for ${tag.name} ===');
      debugPrint('Total medications in system: ${medications.length}');
      debugPrint('Medications with tag ${tag.id}: $count');
      if (assigned.isNotEmpty) {
        debugPrint('Assigned medications:');
        for (final med in assigned) {
          debugPrint('  - ${med.name} (nfcTagIds: ${med.nfcTagIds})');
        }
      }

      return count;
    } catch (e) {
      debugPrint('Error getting medication count: $e');
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
              child: EmptyState(
                title: 'No NFC tags',
                subtitle: 'Add tags when creating medications',
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
                      key: ValueKey('${tag.id}_$_refreshKey'),
                      future: _getMedicationCount(tag),
                      builder: (context, snapshot) {
                        final medCount = snapshot.data ?? 0;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: NfcTagCard(
                            tag: tag,
                            subtitle: 'Tag ID: ${tag.tagId}\n$medCount medication${medCount != 1 ? 's' : ''}',
                            showChevron: false,
                            trailing: PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert),
                              onSelected: (value) {
                                if (value == 'manage') {
                                  _manageMedications(tag);
                                } else if (value == 'rename') {
                                  _renameTag(tag);
                                } else if (value == 'delete') {
                                  _deleteTag(tag);
                                }
                              },
                              itemBuilder: (context) {
                                return [
                                const PopupMenuItem(
                                  value: 'manage',
                                  child: Row(
                                    children: [
                                      Icon(Icons.medication, size: 20),
                                      SizedBox(width: 12),
                                      Text('Manage Medications'),
                                    ],
                                  ),
                                ),
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
                              ];
                              },
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
