import 'package:flutter/material.dart';
import 'package:med_track/components/add_medication/date_selector.dart';
import 'package:med_track/components/add_medication/day_selector.dart';
import 'package:med_track/components/add_medication/nfc_tag_selector.dart';
import 'package:med_track/components/add_medication/time_selector.dart';
import 'package:med_track/components/common/buttons/primary_button.dart';
import 'package:med_track/components/common/buttons/secondary_button.dart';
import 'package:med_track/components/common/custom_text_field.dart';
import 'package:med_track/components/common/gradient_header.dart';
import 'package:med_track/components/nfc/nfc_tag_dialogs.dart';
import 'package:med_track/database/ioc/ioc_container.dart';
import 'package:med_track/database/model/medication.dart';
import 'package:med_track/database/model/nfc_tag.dart';
import 'package:med_track/utils/constants.dart';
import 'package:med_track/utils/snackbar_utils.dart';

import 'package:med_track/database/service/auth_service.dart';
import 'package:med_track/database/service/medication_database_service.dart';
import 'package:med_track/database/service/nfc/nfc_tag_database_service.dart';
import 'package:med_track/database/service/nfc/nfc_service.dart';

class AddMedicationPage extends StatefulWidget {
  final Medication? medication;

  const AddMedicationPage({super.key, this.medication});

  @override
  State<AddMedicationPage> createState() => _AddMedicationPageState();
}

class _AddMedicationPageState extends State<AddMedicationPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _dosageController = TextEditingController();
  final _medicationService = get<MedicationDatabaseService>();
  final _authService = get<AuthService>();
  final _nfcTagService = get<NfcTagDatabaseService>();

  late bool _isEditMode;
  final Set<int> _selectedDays = {};
  final List<TimeOfDay> _selectedTimes = [];
  late DateTime _startDate;
  bool _isSaving = false;
  late bool _isActive;

  Set<String> _selectedNfcTagIds = {};
  List<NfcTag> _availableTags = [];
  bool _isLoadingTags = false;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.medication != null;
    _loadNfcTags();

    if (_isEditMode) {
      final med = widget.medication!;
      _nameController.text = med.name;
      _descriptionController.text = med.description ?? '';
      _dosageController.text = med.dosage;
      _startDate = med.startDate;
      _isActive = med.isActive;
      _selectedNfcTagIds = Set<String>.from(med.nfcTagIds);
      _selectedDays.addAll(med.scheduleDays);
      _selectedTimes.addAll(
        med.scheduleTimes.map((timeStr) {
          final parts = timeStr.split(':');
          return TimeOfDay(
            hour: int.parse(parts[0]),
            minute: int.parse(parts[1]),
          );
        }),
      );
    } else {
      _startDate = DateTime.now();
      _isActive = true;
      _selectedTimes.add(const TimeOfDay(hour: 8, minute: 0));
    }
  }



  Future<void> _loadNfcTags() async {
    final userId = _authService.user?.uid;
    if (userId == null) return;

    setState(() => _isLoadingTags = true);
    try {
      final tags = await _nfcTagService.getUserTags(userId);
      if (mounted) {
        setState(() {
          _availableTags = tags;
          _isLoadingTags = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingTags = false);
      }
    }
  }

  Future<void> _startPersistentNfcSession() async {
    final nfcService = get<NfcService>();
    final isAvailable = await nfcService.isNfcAvailable();
    if (!isAvailable) {
      setState(() => _isScanning = false);
      if (mounted) {
        showSnackBar(context, 'NFC not available', backgroundColor: AppColors.danger);
      }
      return;
    }

    nfcService.scanAndWriteTag(
      onSuccess: (tag, tagId) async {
        await _handleNewTagScanned(tagId);
      },
      onError: (error) {
        if (mounted) {
          setState(() => _isScanning = false);
          showSnackBar(context, error, backgroundColor: AppColors.danger);
        }
      },
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _dosageController.dispose();
    get<NfcService>().resumeScanning();
    super.dispose();
  }

  Future<void> _saveMedication() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedDays.isEmpty || _selectedTimes.isEmpty) {
      showSnackBar(
        context,
        'Please select at least one day and one time for the schedule.',
        backgroundColor: AppColors.danger,
      );
      return;
    }

    setState(() => _isSaving = true);

    final userId = _authService.user?.uid;
    if (userId == null) {
      if (mounted) {
        showSnackBar(
          context,
          'Error: You must be logged in to save a medication.',
        );
      }
      setState(() => _isSaving = false);
      return;
    }

    try {
      Medication medicationToSave;
      final scheduleTimes =
          _selectedTimes
              .map(
                (t) =>
                    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
              )
              .toList()
            ..sort();
      final scheduleDays = _selectedDays.toList()..sort();

      if (_isEditMode) {
        medicationToSave = widget.medication!.copyWith(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          dosage: _dosageController.text.trim(),
          startDate: _startDate,
          isActive: _isActive,
          scheduleDays: scheduleDays,
          scheduleTimes: scheduleTimes,
          nfcTagIds: _selectedNfcTagIds.toList(),
          updatedAt: DateTime.now(),
        );
        await _medicationService.update(medicationToSave.id, medicationToSave);
      } else {
        final userId = _authService.user?.uid;
        if (userId == null) {
          throw Exception('User not authenticated');
        }

        medicationToSave = Medication(
          userId: userId,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          dosage: _dosageController.text.trim(),
          startDate: _startDate,
          isActive: _isActive,
          scheduleDays: scheduleDays,
          scheduleTimes: scheduleTimes,
          nfcTagIds: _selectedNfcTagIds.toList(),
        );
        await _medicationService.create(medicationToSave);
      }

      if (mounted) {
        final message = '"${medicationToSave.name}" saved successfully';

        showSnackBar(context, message, backgroundColor: AppColors.success);
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(
          context,
          'Error saving medication: $e',
          backgroundColor: AppColors.danger,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context, int index) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTimes[index],
    );
    if (picked != null && picked != _selectedTimes[index]) {
      setState(() {
        _selectedTimes[index] = picked;
      });
    }
  }

  void _addTime() {
    setState(() {
      _selectedTimes.add(const TimeOfDay(hour: 20, minute: 0));
    });
  }

  void _removeTime(int index) {
    setState(() {
      if (_selectedTimes.length > 1) {
        _selectedTimes.removeAt(index);
      }
    });
  }

  void _toggleDay(int day) {
    setState(() {
      if (_selectedDays.contains(day)) {
        _selectedDays.remove(day);
      } else {
        _selectedDays.add(day);
      }
    });
  }

  Future<void> _scanNewNfcTag() async {
    if (_isScanning) return;

    final nfcService = get<NfcService>();
    nfcService.pauseScanning();

    setState(() => _isScanning = true);

    if (!mounted) return;
    showSnackBar(context, 'Ready to scan - hold NFC tag near phone');

    await _startPersistentNfcSession();
  }

  Future<void> _handleNewTagScanned(String tagId) async {
    final nfcService = get<NfcService>();

    if (!mounted) {
      await nfcService.stopListening();
      return;
    }
    setState(() => _isScanning = false);

    final userId = _authService.user?.uid;
    if (userId == null) {
      await nfcService.stopListening();
      if (mounted) {
        showSnackBar(context, 'User not authenticated', backgroundColor: AppColors.danger);
      }
      return;
    }

    final existingTag = await _nfcTagService.findTagWithFallback(userId, tagId);

    if (!mounted) {
      await nfcService.stopListening();
      return;
    }

    if (existingTag != null) {
      // Tag already exists, toggle selection
      setState(() {
        if (_selectedNfcTagIds.contains(existingTag.id)) {
          _selectedNfcTagIds.remove(existingTag.id);
        } else {
          _selectedNfcTagIds.add(existingTag.id);
        }
      });
      showSnackBar(
        context,
        _selectedNfcTagIds.contains(existingTag.id)
          ? 'Selected tag: ${existingTag.name}'
          : 'Deselected tag: ${existingTag.name}',
        backgroundColor: AppColors.success,
      );
    } else {
      // New tag - show naming dialog
      final newTag = await NfcTagDialogs.showNameNewTagDialog(
        context,
        tagId,
      );

      if (newTag != null) {
        setState(() {
          _selectedNfcTagIds.add(newTag.id);
        });
        await _loadNfcTags();

        if (mounted) {
          showSnackBar(context, 'Tag registered!', backgroundColor: AppColors.success);
        }
      }
    }

    // Stop NFC session after dialog closes to prevent Android from reading AAR
    await nfcService.stopListening();
  }



  Future<void> _confirmDeleteTag(BuildContext modalContext, NfcTag tag) async {
    final confirmed = await NfcTagDialogs.showDeleteTagDialog(context, tag.name);

    if (confirmed) {
      try {
        await _nfcTagService.delete(tag.id);

        if (!modalContext.mounted) return;
        Navigator.of(modalContext).pop();

        setState(() {
          _selectedNfcTagIds.remove(tag.id);
        });
        await _loadNfcTags();

        if (!mounted) return;
        showSnackBar(
          context,
          'Tag "${tag.name}" deleted',
          backgroundColor: AppColors.success,
        );
      } catch (e) {
        if (!mounted) return;
        showSnackBar(
          context,
          'Error deleting tag: $e',
          backgroundColor: AppColors.danger,
        );
      }
    }
  }

  void _showNfcTagPicker() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              Text('Select NFC Tags', style: AppTextStyles.heading2),
              const SizedBox(height: AppSpacing.md),
              if (_availableTags.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Text(
                    'No NFC tags.\nScan a new one below.',
                    textAlign: TextAlign.center,
                  ),
                )
              else
                ...(_availableTags.map((tag) => Row(
                      children: [
                        Expanded(
                          child: CheckboxListTile(
                            value: _selectedNfcTagIds.contains(tag.id),
                            onChanged: (bool? value) {
                              setSheetState(() {
                                if (value == true) {
                                  _selectedNfcTagIds.add(tag.id);
                                } else {
                                  _selectedNfcTagIds.remove(tag.id);
                                }
                              });
                              // Also update parent state
                              setState(() {});
                            },
                            secondary: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                gradient: AppGradients.green,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.nfc, color: Colors.white),
                            ),
                            title: Text(tag.name),
                            subtitle: Text(tag.tagId),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: const EdgeInsets.only(left: 8),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline, color: AppColors.danger),
                          onPressed: () => _confirmDeleteTag(ctx, tag),
                        ),
                      ],
                    ))),
              const Divider(),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _scanNewNfcTag();
                },
                icon: const Icon(Icons.nfc),
                label: const Text('Scan New NFC Tag'),
              ),
              if (_selectedNfcTagIds.isNotEmpty)
                TextButton(
                  onPressed: () {
                    setSheetState(() => _selectedNfcTagIds.clear());
                    setState(() {});
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('Clear All Tags'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Form(
        key: _formKey,
        child: CustomScrollView(
          slivers: [
            GradientSliverHeader(
              title: _isEditMode ? 'Edit Medication' : 'Add Medication',
              subtitle: 'Fill in the details below',
              onBack: () => Navigator.of(context).pop(),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: AppPadding.page,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CustomTextField(
                      label: 'Medication Name *',
                      hintText: 'e.g., Aspirin 100mg',
                      controller: _nameController,
                      validator: (v) =>
                          v!.isEmpty ? 'Name cannot be empty' : null,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    CustomTextField(
                      label: 'Description / Note',
                      hintText: 'Optional instructions',
                      controller: _descriptionController,
                      maxLines: 2,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    CustomTextField(
                      label: 'Dosage *',
                      hintText: 'e.g., 1 tablet',
                      controller: _dosageController,
                      validator: (v) =>
                          v!.isEmpty ? 'Dosage cannot be empty' : null,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    DaySelector(
                      selectedDays: _selectedDays,
                      onDayToggled: _toggleDay,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TimeSelector(
                      selectedTimes: _selectedTimes,
                      onTimeSelected: (index) => _selectTime(context, index),
                      onAddTime: _addTime,
                      onRemoveTime: _removeTime,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    DateSelector(
                      selectedDate: _startDate,
                      onDateSelected: () => _selectDate(context),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'NFC Tag (Optional)',
                      style: AppTextStyles.bodyMediumSemiBold,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Assign an NFC chip to quickly mark this medication as taken',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _buildNfcTagSelector(),
                    const SizedBox(height: AppSpacing.xxl),
                    PrimaryGradientButton(
                      label: _isSaving
                          ? 'Saving...'
                          : (_isEditMode ? 'Save Changes' : 'Save Medication'),
                      onPressed: _isSaving ? () {} : _saveMedication,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SecondaryOutlineButton(
                      label: 'Cancel',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNfcTagSelector() {
    return NfcTagSelector(
      selectedNfcTagIds: _selectedNfcTagIds,
      availableTags: _availableTags,
      isScanning: _isScanning,
      isLoadingTags: _isLoadingTags,
      onShowPicker: _showNfcTagPicker,
    );
  }
}
