import 'package:flutter/material.dart';
import 'package:med_track/components/add_medication/date_selector.dart';
import 'package:med_track/components/add_medication/day_selector.dart';
import 'package:med_track/components/add_medication/time_selector.dart';
import 'package:med_track/components/common/buttons/primary_button.dart';
import 'package:med_track/components/common/buttons/secondary_button.dart';
import 'package:med_track/components/common/custom_text_field.dart';
import 'package:med_track/components/common/gradient_header.dart';
import 'package:med_track/database/ioc/ioc_container.dart';
import 'package:med_track/database/model/medication.dart';
import 'package:med_track/utils/constants.dart';

import '../database/service/medication_database_service.dart';
import '../utils/snackbar_utils.dart';

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

  late bool _isEditMode;
  final Set<int> _selectedDays = {};
  final List<TimeOfDay> _selectedTimes = [];
  late DateTime _startDate;
  bool _isSaving = false;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.medication != null;

    if (_isEditMode) {
      final med = widget.medication!;
      _nameController.text = med.name;
      _descriptionController.text = med.description ?? '';
      _dosageController.text = med.dosage;
      _startDate = med.startDate;
      _isActive = med.isActive;
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

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _dosageController.dispose();
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
          updatedAt: DateTime.now(),
        );
        await _medicationService.update(medicationToSave.id, medicationToSave);
      } else {
        medicationToSave = Medication(
          userId: 'current_user',
          // TODO: Replace with actual user ID
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          dosage: _dosageController.text.trim(),
          startDate: _startDate,
          isActive: _isActive,
          scheduleDays: scheduleDays,
          scheduleTimes: scheduleTimes,
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
}
