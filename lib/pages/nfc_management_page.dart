import 'package:flutter/material.dart';
import 'package:med_track/components/common/gradient_header.dart';
import 'package:med_track/database/ioc/ioc_container.dart';
import 'package:med_track/database/model/medication.dart';
import 'package:med_track/database/model/nfc_tag.dart';
import 'package:med_track/database/service/auth_service.dart';
import 'package:med_track/database/service/medication_database_service.dart';
import 'package:med_track/database/service/nfc_manager_service.dart';
import 'package:med_track/database/service/nfc_tag_database_service.dart';
import 'package:med_track/utils/constants.dart';
import 'package:med_track/utils/snackbar_utils.dart';
import 'package:med_track/components/common/app_card.dart';
import 'package:med_track/components/common/buttons/primary_button.dart';
import 'package:med_track/components/nfc_help_dialog.dart';

class NfcManagementPage extends StatefulWidget {
  final Medication? medication; // If provided, auto-assign to this medication

  const NfcManagementPage({super.key, this.medication});

  @override
  State<NfcManagementPage> createState() => _NfcManagementPageState();
}

class _NfcManagementPageState extends State<NfcManagementPage> {
  final _nfcManager = get<NfcManagerService>();
  final _nfcTagService = get<NfcTagDatabaseService>();
  final _medicationService = get<MedicationDatabaseService>();
  final _authService = get<AuthService>();

  bool _isScanning = false;
  bool _isNfcAvailable = true;
  List<NfcTag> _userTags = [];
  List<Medication> _userMedications = [];

  @override
  void initState() {
    super.initState();
    _checkNfcAvailability();
    _loadUserData();
  }

  Future<void> _checkNfcAvailability() async {
    final available = await _nfcManager.isNfcAvailable();
    if (mounted) {
      setState(() {
        _isNfcAvailable = available;
      });
    }
  }

  Future<void> _loadUserData() async {
    final userId = _authService.user?.uid;
    if (userId == null) return;

    final tags = await _nfcTagService.getUserTags(userId);
    final medications = await _medicationService.getUserMedications(userId);

    if (mounted) {
      setState(() {
        _userTags = tags;
        _userMedications = medications;
      });
    }
  }

  Future<void> _scanNfcTag() async {
    if (!_isNfcAvailable) {
      showSnackBar(
        context,
        'NFC is not available on this device',
        backgroundColor: AppColors.danger,
      );
      return;
    }

    setState(() {
      _isScanning = true;
    });

    showSnackBar(context, 'Hold your phone near the NFC tag...');

    await _nfcManager.scanNfcTag(
      onTagDiscovered: (tagId, nfcTag) async {
        await _handleTagScanned(tagId);
      },
      onError: () {
        if (mounted) {
          showSnackBar(
            context,
            'Error scanning NFC tag',
            backgroundColor: AppColors.danger,
          );
        }
      },
    );

    if (mounted) {
      setState(() {
        _isScanning = false;
      });
    }
  }

  Future<void> _handleTagScanned(String tagId) async {
    final userId = _authService.user?.uid;
    if (userId == null) return;

    // Check if tag already exists
    final existingTag = await _nfcTagService.findByTagId(userId, tagId);

    if (existingTag != null) {
      // Tag exists, show options to manage it
      if (mounted) {
        _showTagOptionsDialog(existingTag);
      }
    } else {
      // New tag, prompt for name
      if (mounted) {
        _showNameTagDialog(tagId);
      }
    }
  }

  void _showNameTagDialog(String tagId) {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Name Your NFC Tag'),
        content: Column(
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
              Navigator.of(ctx).pop();
              await _createNewTag(tagId, name);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _createNewTag(String tagId, String name) async {
    final userId = _authService.user?.uid;
    if (userId == null) return;

    final newTag = NfcTag(
      userId: userId,
      tagId: tagId,
      name: name,
      medicationIds: widget.medication != null ? [widget.medication!.id] : [],
    );

    await _nfcTagService.create(newTag);

    if (mounted) {
      showSnackBar(
        context,
        'NFC tag "$name" created successfully',
        backgroundColor: AppColors.success,
      );
      _loadUserData();
    }
  }

  void _showTagOptionsDialog(NfcTag tag) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tag.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tag ID: ${tag.tagId}'),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Assigned to ${tag.medicationIds.length} medication(s)',
              style: AppTextStyles.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _showManageTagPage(tag);
            },
            child: const Text('Manage'),
          ),
        ],
      ),
    );
  }

  void _showManageTagPage(NfcTag tag) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => ManageNfcTagPage(tag: tag),
      ),
    ).then((_) => _loadUserData());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          GradientSliverHeader(
            title: 'NFC Tags',
            subtitle: 'Scan and manage your NFC tags',
            onBack: () => Navigator.of(context).maybePop(),
            trailing: IconButton(
              icon: const Icon(Icons.help_outline, color: Colors.white),
              onPressed: () => NfcHelpDialog.show(context),
              tooltip: 'How to use NFC',
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: AppPadding.page,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!_isNfcAvailable)
                    AppCard(
                      color: AppColors.danger.withAlpha(25),
                      child: Row(
                        children: [
                          Icon(Icons.error, color: AppColors.danger),
                          const SizedBox(width: AppSpacing.md),
                          const Expanded(
                            child: Text(
                              'NFC is not available on this device',
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_isNfcAvailable) ...[
                    PrimaryGradientButton(
                      label: _isScanning ? 'Scanning...' : 'Scan NFC Tag',
                      onPressed: _isScanning ? () {} : _scanNfcTag,
                      icon: _isScanning
                          ? const Icon(
                              Icons.hourglass_empty,
                              color: Colors.white,
                              size: 20,
                            )
                          : const Icon(Icons.nfc, color: Colors.white),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    Text(
                      'Your NFC Tags',
                      style: AppTextStyles.heading2,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (_userTags.isEmpty)
                      AppCard(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Text(
                              'No NFC tags yet.\nScan a tag to get started!',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      ..._userTags.map((tag) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.md,
                            ),
                            child: _NfcTagCard(
                              tag: tag,
                              medications: _userMedications
                                  .where(
                                    (m) => tag.medicationIds.contains(m.id),
                                  )
                                  .toList(),
                              onTap: () => _showManageTagPage(tag),
                            ),
                          )),
                  ],
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NfcTagCard extends StatelessWidget {
  final NfcTag tag;
  final List<Medication> medications;
  final VoidCallback onTap;

  const _NfcTagCard({
    required this.tag,
    required this.medications,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AppCard(
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                gradient: AppGradients.green,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.nfc, color: Colors.white, size: 28),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tag.name, style: AppTextStyles.bodyMediumSemiBold),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    medications.isEmpty
                        ? 'No medications assigned'
                        : '${medications.length} medication(s) assigned',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

// Separate page for managing a specific NFC tag
class ManageNfcTagPage extends StatefulWidget {
  final NfcTag tag;

  const ManageNfcTagPage({super.key, required this.tag});

  @override
  State<ManageNfcTagPage> createState() => _ManageNfcTagPageState();
}

class _ManageNfcTagPageState extends State<ManageNfcTagPage> {
  final _nfcTagService = get<NfcTagDatabaseService>();
  final _medicationService = get<MedicationDatabaseService>();
  final _authService = get<AuthService>();

  late NfcTag _tag;
  List<Medication> _allMedications = [];

  @override
  void initState() {
    super.initState();
    _tag = widget.tag;
    _loadMedications();
  }

  Future<void> _loadMedications() async {
    final userId = _authService.user?.uid;
    if (userId == null) return;

    final medications = await _medicationService.getUserMedications(userId);
    if (mounted) {
      setState(() {
        _allMedications = medications;
      });
    }
  }

  Future<void> _toggleMedication(String medicationId) async {
    final isAssigned = _tag.medicationIds.contains(medicationId);

    if (isAssigned) {
      await _nfcTagService.removeMedicationFromTag(_tag.id, medicationId);
    } else {
      await _nfcTagService.addMedicationToTag(_tag.id, medicationId);
    }

    // Reload tag
    final updatedTag = await _nfcTagService.get(_tag.id);
    if (updatedTag != null && mounted) {
      setState(() {
        _tag = updatedTag;
      });
    }
  }

  Future<void> _renameTag() async {
    final nameController = TextEditingController(text: _tag.name);

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Tag'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Tag Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(nameController.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != _tag.name) {
      await _nfcTagService.updateTagName(_tag.id, newName);
      final updatedTag = await _nfcTagService.get(_tag.id);
      if (updatedTag != null && mounted) {
        setState(() {
          _tag = updatedTag;
        });
        showSnackBar(context, 'Tag renamed successfully');
      }
    }
  }

  Future<void> _deleteTag() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete NFC Tag?'),
        content: Text('Are you sure you want to delete "${_tag.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _nfcTagService.delete(_tag.id);
      if (mounted) {
        Navigator.of(context).pop();
        showSnackBar(context, 'Tag deleted successfully');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          GradientSliverHeader(
            title: _tag.name,
            subtitle: 'Tag ID: ${_tag.tagId}',
            onBack: () => Navigator.of(context).pop(),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: AppPadding.page,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Assign Medications',
                    style: AppTextStyles.heading2,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Select which medications should be marked as taken when this tag is scanned',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (_allMedications.isEmpty)
                    AppCard(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Text(
                            'No medications available.\nAdd medications first.',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    ..._allMedications.map((medication) {
                      final isAssigned =
                          _tag.medicationIds.contains(medication.id);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: AppCard(
                          child: CheckboxListTile(
                            value: isAssigned,
                            onChanged: (_) => _toggleMedication(medication.id),
                            title: Text(medication.name),
                            subtitle: Text(medication.dosage),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: AppSpacing.xxl),
                  Text(
                    'Tag Actions',
                    style: AppTextStyles.heading2,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton.icon(
                    onPressed: _renameTag,
                    icon: const Icon(Icons.edit),
                    label: const Text('Rename Tag'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.all(AppSpacing.md),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton.icon(
                    onPressed: _deleteTag,
                    icon: const Icon(Icons.delete),
                    label: const Text('Delete Tag'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: BorderSide(color: AppColors.danger),
                      padding: const EdgeInsets.all(AppSpacing.md),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
