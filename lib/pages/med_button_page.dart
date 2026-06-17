import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:med_track/components/common/app_card.dart';
import 'package:med_track/components/common/buttons/primary_button.dart';
import 'package:med_track/components/common/buttons/secondary_button.dart';
import 'package:med_track/components/common/gradient_header.dart';
import 'package:med_track/database/ioc/ioc_container.dart';
import 'package:med_track/database/model/dose_buddy_device.dart';
import 'package:med_track/database/model/dose_buddy_event.dart';
import 'package:med_track/database/model/medication.dart';
import 'package:med_track/database/service/auth_service.dart';
import 'package:med_track/database/service/dose_buddy/dose_buddy_device_database_service.dart';
import 'package:med_track/database/service/dose_buddy/dose_buddy_event_database_service.dart';
import 'package:med_track/database/service/dose_buddy/dose_buddy_service.dart';
import 'package:med_track/database/service/medication_database_service.dart';
import 'package:med_track/utils/constants.dart';
import 'package:med_track/utils/helpers/medication_scheduling.dart';
import 'package:med_track/utils/handling_stream_builder.dart';
import 'package:med_track/utils/snackbar_utils.dart';

final ValueNotifier<bool> medButtonTutorialOverlayActive = ValueNotifier<bool>(
  false,
);

class MedButtonPage extends StatefulWidget {
  const MedButtonPage({super.key});

  @override
  State<MedButtonPage> createState() => _MedButtonPageState();
}

class _MedButtonPageState extends State<MedButtonPage> {
  final AuthService _authService = get<AuthService>();
  final DoseBuddyDeviceDatabaseService _deviceDb =
      get<DoseBuddyDeviceDatabaseService>();
  final DoseBuddyEventDatabaseService _eventDb =
      get<DoseBuddyEventDatabaseService>();
  final MedicationDatabaseService _medicationDb =
      get<MedicationDatabaseService>();
  final DoseBuddyService _doseBuddyService = get<DoseBuddyService>();

  bool _isPairing = false;
  bool _isSaving = false;
  bool _tutorialOverlayVisible = false;
  bool _isTutorialActionPending = false;
  bool _tutorialTimedOut = false;
  int _tutorialAnimationSeed = 0;
  Timer? _tutorialResponseTimeout;

  String? get _userId => _authService.user?.uid;

  @override
  void dispose() {
    _clearTutorialResponseTimeout();
    medButtonTutorialOverlayActive.value = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null) {
      return const Scaffold(body: Center(child: Text('No logged-in user')));
    }

    return StreamBuilder<DoseBuddySessionState>(
      stream: _doseBuddyService.sessionState,
      initialData: _doseBuddyService.sessionStateNow,
      builder: (context, sessionSnapshot) {
        final session = sessionSnapshot.data ?? DoseBuddySessionState.initial();
        _syncTutorialOverlay(session);

        return StreamBuilder<DoseBuddyDevice?>(
          stream: _deviceDb.observePrimaryDevice(_userId!),
          builder: (context, deviceSnapshot) {
            if (deviceSnapshot.connectionState == ConnectionState.waiting &&
                !deviceSnapshot.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final device = deviceSnapshot.data;

            return Scaffold(
              body: HandlingStreamBuilder<List<Medication>>(
                stream: _medicationDb.observeUserMedications(_userId!),
                builder: (medications) {
                  final medicationMap = {
                    for (final medication in medications)
                      medication.id: medication,
                  };
                  return Stack(
                    children: [
                      CustomScrollView(
                        slivers: [
                          const GradientSliverHeader(
                            title: 'Dose Buddy',
                            subtitle: 'Simple control of your dispenser',
                          ),
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: AppPadding.page,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildStatusCard(
                                    session,
                                    device,
                                    medications,
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                  _buildDeviceCard(device, session),
                                  const SizedBox(height: AppSpacing.lg),
                                  _buildMissedDosePolicyCard(device),
                                  const SizedBox(height: AppSpacing.lg),
                                  _buildMedicationCard(device, medications),
                                  const SizedBox(height: AppSpacing.xl),
                                  _buildIntervalsCard(device),
                                  const SizedBox(height: AppSpacing.xl),
                                  if (device != null)
                                    _buildRecentActivityLauncher(medicationMap),
                                  const SizedBox(height: 96),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_tutorialOverlayVisible)
                        _buildTutorialOverlay(session),
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatusCard(
    DoseBuddySessionState session,
    DoseBuddyDevice? device,
    List<Medication> medications,
  ) {
    final accentColor = _statusColor(session.status);
    final nextDueAt = session.nextDueAt;
    final nextTimeValue = nextDueAt == null ? '--:--' : formatTimeHm(nextDueAt);
    final nextDayValue = nextDueAt == null
        ? 'Choose medicines or add times below'
        : relativeDayLabel(nextDueAt);
    final intervalValue = _buildDoseBuddyIntervalSummary(device, medications);
    final dosesLeftValue = session.remainingDoses == null
        ? '--'
        : session.dispenserCapacity == null
        ? '${session.remainingDoses}'
        : '${session.remainingDoses}/${session.dispenserCapacity}';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _StatusChip(
                icon: _statusIcon(session.status),
                label: _statusShortLabel(session.status),
                color: accentColor,
              ),
              if (session.isDispenseWindowOpen)
                _StatusChip(
                  icon: Icons.schedule_send_rounded,
                  label: 'Window open',
                  color: AppColors.success,
                ),
              if (session.refillNeeded)
                _StatusChip(
                  icon: Icons.inventory_2_outlined,
                  label: 'Refill needed',
                  color: AppColors.warning,
                ),
            ],
          ),
          if (session.message != null &&
              session.status != DoseBuddyConnectionStatus.connected) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              session.message!,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Next dose',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            nextTimeValue,
            textAlign: TextAlign.center,
            style: AppTextStyles.heading1.copyWith(
              fontSize: 42,
              color: AppColors.textTertiary,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            nextDayValue,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMediumSemiBold.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _DashboardMetricCard(
                  label: 'Interval',
                  value: intervalValue,
                  icon: Icons.schedule_rounded,
                  color: accentColor,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _DashboardMetricCard(
                  label: 'Doses left',
                  value: dosesLeftValue,
                  icon: Icons.inventory_2_outlined,
                  color: session.refillNeeded
                      ? AppColors.warning
                      : AppColors.primary,
                  alignCenter: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _buildDoseBuddyIntervalSummary(
    DoseBuddyDevice? device,
    List<Medication> medications,
  ) {
    if (device == null) {
      return 'Choose medicines or add times';
    }

    final manualIntervals = [...device.manualIntervals]..sort();
    if (manualIntervals.isNotEmpty) {
      return _formatIntervalSummary(const [
        1,
        2,
        3,
        4,
        5,
        6,
        7,
      ], manualIntervals);
    }

    final selectedMedications = medications
        .where((medication) => device.medicationIds.contains(medication.id))
        .where((medication) => medication.isActive)
        .toList();

    final scheduleDays = <int>{};
    final scheduleTimes = <String>{};
    for (final medication in selectedMedications) {
      scheduleDays.addAll(medication.scheduleDays);
      scheduleTimes.addAll(medication.scheduleTimes);
    }

    if (scheduleTimes.isEmpty) {
      return 'Choose medicines or add times';
    }

    return _formatIntervalSummary(
      scheduleDays.toList(),
      scheduleTimes.toList(),
    );
  }

  String _formatIntervalSummary(List<int> days, List<String> times) {
    final sortedTimes = [...times]..sort();
    if (sortedTimes.isEmpty) {
      return 'Choose medicines or add times';
    }

    final sortedDays = [...days]..sort();
    final everyDay =
        sortedDays.length == 7 &&
        List<int>.generate(7, (index) => index + 1).every(sortedDays.contains);
    final timeText = _joinNaturalList(sortedTimes);

    if (everyDay) {
      return 'Every day at $timeText';
    }

    if (sortedDays.isEmpty) {
      return 'At $timeText';
    }

    return '${sortedDays.map(weekdayNameShort).join(', ')} at $timeText';
  }

  String _joinNaturalList(List<String> values) {
    if (values.isEmpty) return '';
    if (values.length == 1) return values.first;
    if (values.length == 2) return '${values.first} and ${values.last}';
    return '${values.sublist(0, values.length - 1).join(', ')} and ${values.last}';
  }

  String _statusShortLabel(DoseBuddyConnectionStatus status) {
    switch (status) {
      case DoseBuddyConnectionStatus.connected:
        return 'Connected';
      case DoseBuddyConnectionStatus.syncing:
        return 'Syncing';
      case DoseBuddyConnectionStatus.scanning:
        return 'Searching';
      case DoseBuddyConnectionStatus.connecting:
        return 'Connecting';
      case DoseBuddyConnectionStatus.bluetoothOff:
        return 'Bluetooth off';
      case DoseBuddyConnectionStatus.attention:
        return 'Needs attention';
      case DoseBuddyConnectionStatus.unsupported:
        return 'Unavailable';
      case DoseBuddyConnectionStatus.disconnected:
        return 'Disconnected';
    }
  }

  Widget _buildDeviceCard(
    DoseBuddyDevice? device,
    DoseBuddySessionState session,
  ) {
    final canStartTutorial =
        device != null && session.status == DoseBuddyConnectionStatus.connected;
    final allActions = device == null
        ? const <_ActionButtonConfig>[]
        : [
            _ActionButtonConfig(
              label: 'Connect',
              icon: Icons.bluetooth_connected,
              onPressed: _connectNow,
            ),
            _ActionButtonConfig(
              label: 'Update',
              icon: Icons.sync,
              onPressed: _syncNow,
            ),
            _ActionButtonConfig(
              label: 'Refilled',
              icon: Icons.inventory_2_outlined,
              onPressed: _markDispenserRefilled,
            ),
            _ActionButtonConfig(
              label: 'Find again',
              icon: Icons.bluetooth_searching,
              onPressed: () => _pairDevice(device),
            ),
            _ActionButtonConfig(
              label: 'Disconnect',
              icon: Icons.link_off,
              onPressed: _disconnectNow,
            ),
            _ActionButtonConfig(
              label: 'Remove',
              icon: Icons.delete_outline,
              onPressed: () => _forgetDevice(device),
              danger: true,
            ),
          ];
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dose Buddy', style: AppTextStyles.heading3),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      device == null
                          ? 'Simple pill dispenser connected through Bluetooth.'
                          : 'Your dispenser is saved and ready.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (device != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.successBackground,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Paired',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (device == null)
            PrimaryGradientButton(
              label: _isPairing ? 'Searching...' : 'Find dispenser',
              onPressed: _isPairing ? null : () => _pairDevice(device),
              icon: const Icon(Icons.bluetooth_searching, color: Colors.white),
            )
          else ...[
            PrimaryGradientButton(
              label: 'Open Wheel Tutorial',
              onPressed: canStartTutorial ? _startTutorialDemo : null,
              icon: const Icon(Icons.auto_awesome, color: Colors.white),
            ),
            const SizedBox(height: AppSpacing.md),
            _buildActionButtonGrid(
              allActions,
              compact: true,
              preferTwoColumns: true,
            ),
          ],
          if (session.refillNeeded) ...[
            const SizedBox(height: AppSpacing.md),
            _InlineNotice(
              icon: Icons.inventory_rounded,
              color: AppColors.warning,
              message: 'Refill the wheel, then tap Refilled.',
            ),
          ],
          if (session.isAlarmActive) ...[
            const SizedBox(height: AppSpacing.md),
            _InlineNotice(
              icon: Icons.warning_amber_rounded,
              color: AppColors.warning,
              message:
                  'A dose window was missed. Check the dispenser and the schedule.',
            ),
          ],
          if (device != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(20),
              ),
              child: SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Auto reconnect'),
                subtitle: const Text('Reconnect when the app opens.'),
                value: device.autoReconnectEnabled,
                onChanged: _isSaving
                    ? null
                    : (value) => _toggleAutoReconnect(device, value),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMedicationCard(
    DoseBuddyDevice? device,
    List<Medication> medications,
  ) {
    final selectedMedications = medications
        .where(
          (medication) =>
              device?.medicationIds.contains(medication.id) ?? false,
        )
        .toList();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Linked medicines', style: AppTextStyles.heading3),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'When the dispenser releases a dose, these medicines are marked as taken.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (device == null)
            const Text('Pair Dose Buddy first.')
          else if (medications.isEmpty)
            const Text('No medications available yet.')
          else if (selectedMedications.isEmpty)
            const Text('Nothing linked yet.')
          else
            ...selectedMedications.map(
              (medication) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _InfoRow(
                  label: medication.name,
                  value:
                      '${medication.dosage} • ${formatSchedule(medication.scheduleDays, medication.scheduleTimes)}',
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: SecondaryOutlineButton(
              label: 'Choose medications',
              onPressed: device == null || medications.isEmpty
                  ? null
                  : () => _editMedicationAssignments(device, medications),
              icon: const Icon(Icons.medication_outlined),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMissedDosePolicyCard(DoseBuddyDevice? device) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Missed dose', style: AppTextStyles.heading3),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'If a dose is missed, Dose Buddy reminds you for one more hour.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (device == null)
            const Text('Pair Dose Buddy first.')
          else
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Allow one late dispense'),
              subtitle: const Text(
                'Keep one dispense available after that hour ends.',
              ),
              value: device.allowLateDispenseAfterMissedHour,
              onChanged: _isSaving
                  ? null
                  : (value) =>
                        _toggleLateDispenseAfterMissedHour(device, value),
            ),
        ],
      ),
    );
  }

  Widget _buildRecentActivityLauncher(Map<String, Medication> medicationsById) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Recent activity', style: AppTextStyles.heading3),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Open the latest Dose Buddy updates only when you need them.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SecondaryOutlineButton(
            label: 'Open recent activity',
            onPressed: _userId == null
                ? null
                : () => _openRecentActivitySheet(medicationsById),
            icon: const Icon(Icons.history_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildIntervalsCard(DoseBuddyDevice? device) {
    final intervals = device?.manualIntervals ?? const <String>[];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Manual times', style: AppTextStyles.heading3),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Use daily times when one button covers several meds together.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (device == null)
            const Text('Pair Dose Buddy first.')
          else if (intervals.isEmpty)
            const Text('No times added yet.')
          else
            ...intervals.map(
              (interval) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: _InfoRow(label: 'Reminder time', value: interval),
                    ),
                    IconButton(
                      onPressed: _isSaving
                          ? null
                          : () => _removeManualInterval(device, interval),
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Remove interval',
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: SecondaryOutlineButton(
              label: 'Add time',
              onPressed: device == null
                  ? null
                  : () => _addManualInterval(device),
              icon: const Icon(Icons.schedule_outlined),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentEventsCard(
    List<DoseBuddyEvent> events,
    Map<String, Medication> medicationsById,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (events.isEmpty)
          const Text('No activity yet.')
        else
          ...events.map(
            (event) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _EventRow(
                title: _eventTitle(event.feedbackType),
                subtitle: _eventSubtitle(event, medicationsById),
                timeLabel:
                    '${relativeDayLabel(event.confirmedAt)} ${formatTimeHm(event.confirmedAt)}',
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _openRecentActivitySheet(
    Map<String, Medication> medicationsById,
  ) async {
    if (_userId == null) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.88,
            child: Padding(
              padding: AppPadding.page,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Recent activity', style: AppTextStyles.heading3),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Latest signals reported by Dose Buddy.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Expanded(
                    child: HandlingStreamBuilder<List<DoseBuddyEvent>>(
                      stream: _eventDb.observeRecentUserEvents(_userId!),
                      builder: (events) => SingleChildScrollView(
                        child: _buildRecentEventsCard(events, medicationsById),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SecondaryOutlineButton(
                    label: 'Exit',
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _pairDevice(DoseBuddyDevice? currentDevice) async {
    if (_isPairing || _userId == null) return;

    setState(() => _isPairing = true);

    try {
      final candidates = await _doseBuddyService.scanForCandidates();
      if (!mounted) return;

      if (candidates.isEmpty) {
        final session = _doseBuddyService.sessionStateNow;
        showSnackBar(
          context,
          session.message ?? 'No Dose Buddy device found nearby.',
          backgroundColor: switch (session.status) {
            DoseBuddyConnectionStatus.attention => AppColors.danger,
            DoseBuddyConnectionStatus.bluetoothOff => AppColors.warning,
            _ => AppColors.warning,
          },
        );
        return;
      }

      final selectedCandidate = candidates.length == 1
          ? candidates.first
          : await _showDevicePicker(candidates);
      if (!mounted || selectedCandidate == null) return;

      final nextDevice =
          (currentDevice ??
                  DoseBuddyDevice(
                    userId: _userId!,
                    displayName: selectedCandidate.displayName,
                    bleDeviceId: selectedCandidate.remoteId,
                  ))
              .copyWith(
                displayName: selectedCandidate.displayName,
                bleDeviceId: selectedCandidate.remoteId,
                updatedAt: DateTime.now(),
              );

      await _doseBuddyService.upsertConfiguration(nextDevice);
      await _doseBuddyService.connectToConfiguredDevice(
        autoConnect: false,
        waitForConnection: false,
      );

      if (mounted) {
        showSnackBar(
          context,
          candidates.length == 1
              ? 'Dose Buddy found and paired automatically.'
              : 'Dose Buddy paired successfully.',
          backgroundColor: AppColors.success,
        );
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(
          context,
          'Dose Buddy pairing failed: $e',
          backgroundColor: AppColors.danger,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPairing = false);
      }
    }
  }

  Future<void> _connectNow() async {
    try {
      await _doseBuddyService.connectToConfiguredDevice(
        autoConnect: false,
        waitForConnection: false,
      );
    } catch (e) {
      if (mounted) {
        showSnackBar(
          context,
          'Could not connect Dose Buddy: $e',
          backgroundColor: AppColors.danger,
        );
      }
    }
  }

  Future<void> _syncNow() async {
    try {
      final didSync = await _doseBuddyService.syncConfiguration();
      final syncState = _doseBuddyService.sessionStateNow;
      final syncMessage = didSync
          ? 'Dose Buddy updated.'
          : syncState.status == DoseBuddyConnectionStatus.connected
          ? 'Dispenser is connected. The app will try the update again in a moment.'
          : syncState.message ?? 'Connect the dispenser before updating.';
      final syncColor = didSync
          ? AppColors.success
          : syncState.status == DoseBuddyConnectionStatus.attention
          ? AppColors.danger
          : AppColors.warning;
      if (mounted) {
        showSnackBar(context, syncMessage, backgroundColor: syncColor);
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(
          context,
          'Dose Buddy sync failed: $e',
          backgroundColor: AppColors.danger,
        );
      }
    }
  }

  Future<void> _markDispenserRefilled() async {
    try {
      await _doseBuddyService.markDispenserRefilled();
      if (mounted) {
        showSnackBar(
          context,
          'Dose Buddy refill confirmed.',
          backgroundColor: AppColors.success,
        );
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(
          context,
          'Could not confirm the refill: $e',
          backgroundColor: AppColors.danger,
        );
      }
    }
  }

  Future<void> _disconnectNow() async {
    await _doseBuddyService.disconnect();
    if (_tutorialOverlayVisible && mounted) {
      setState(() {
        _setTutorialOverlayVisible(false);
        _isTutorialActionPending = false;
        _tutorialTimedOut = false;
      });
    }
    _clearTutorialResponseTimeout();
    if (mounted) {
      showSnackBar(context, 'Dose Buddy disconnected.');
    }
  }

  Future<void> _startTutorialDemo() async {
    if (!_tutorialOverlayVisible) {
      setState(() {
        _setTutorialOverlayVisible(true);
        _isTutorialActionPending = true;
        _tutorialTimedOut = false;
        _tutorialAnimationSeed++;
      });
    }

    try {
      await _doseBuddyService.startTutorialDemo();
      _ensureTutorialActionAccepted();
      _armTutorialResponseTimeout();
    } catch (e) {
      if (mounted) {
        setState(() {
          _setTutorialOverlayVisible(false);
          _isTutorialActionPending = false;
          _tutorialTimedOut = false;
        });
        _clearTutorialResponseTimeout();
        showSnackBar(
          context,
          'Could not start the tutorial demo: $e',
          backgroundColor: AppColors.danger,
        );
      }
    }
  }

  Future<void> _replayTutorialStep() async {
    setState(() {
      _isTutorialActionPending = true;
      _tutorialTimedOut = false;
      _tutorialAnimationSeed++;
    });

    try {
      await _doseBuddyService.replayTutorialStep();
      _ensureTutorialActionAccepted();
      _armTutorialResponseTimeout();
    } catch (e) {
      if (mounted) {
        setState(() => _isTutorialActionPending = false);
        _clearTutorialResponseTimeout();
        showSnackBar(
          context,
          'Could not replay this step: $e',
          backgroundColor: AppColors.danger,
        );
      }
    }
  }

  Future<void> _continueTutorialDemo() async {
    setState(() {
      _isTutorialActionPending = true;
      _tutorialTimedOut = false;
    });

    try {
      await _doseBuddyService.continueTutorialDemo();
      _ensureTutorialActionAccepted();
      _armTutorialResponseTimeout();
    } catch (e) {
      if (mounted) {
        setState(() => _isTutorialActionPending = false);
        _clearTutorialResponseTimeout();
        showSnackBar(
          context,
          'Could not continue the tutorial: $e',
          backgroundColor: AppColors.danger,
        );
      }
    }
  }

  Future<void> _finishTutorialDemo() async {
    setState(() => _isTutorialActionPending = true);
    _clearTutorialResponseTimeout();

    try {
      await _doseBuddyService.stopTutorialDemo();
      if (mounted) {
        setState(() {
          _setTutorialOverlayVisible(false);
          _isTutorialActionPending = false;
          _tutorialTimedOut = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isTutorialActionPending = false);
        showSnackBar(
          context,
          'Could not close the tutorial: $e',
          backgroundColor: AppColors.danger,
        );
      }
    }
  }

  Future<void> _forgetDevice(DoseBuddyDevice device) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Forget Dose Buddy?'),
          content: const Text(
            'This removes the paired device, linked medications, and manual intervals from Dose Buddy.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Forget'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await _doseBuddyService.removeConfiguration();
    if (mounted) {
      showSnackBar(
        context,
        'Dose Buddy removed.',
        backgroundColor: AppColors.success,
      );
    }
  }

  Future<void> _toggleAutoReconnect(
    DoseBuddyDevice device,
    bool enabled,
  ) async {
    await _saveDevice(
      device.copyWith(autoReconnectEnabled: enabled, updatedAt: DateTime.now()),
      successMessage: enabled
          ? 'Automatic reconnect enabled.'
          : 'Automatic reconnect disabled.',
    );
  }

  Future<void> _toggleLateDispenseAfterMissedHour(
    DoseBuddyDevice device,
    bool enabled,
  ) async {
    await _saveDevice(
      device.copyWith(
        allowLateDispenseAfterMissedHour: enabled,
        updatedAt: DateTime.now(),
      ),
      successMessage: enabled
          ? 'Late dispensing after the missed-alert hour enabled.'
          : 'Late dispensing after the missed-alert hour disabled.',
    );
  }

  Future<void> _editMedicationAssignments(
    DoseBuddyDevice device,
    List<Medication> medications,
  ) async {
    final selectedIds = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final selected = Set<String>.from(device.medicationIds);
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: AppPadding.page,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Choose linked medications',
                      style: AppTextStyles.heading3,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (medications.isEmpty)
                      const Text('No medications available yet.')
                    else
                      ...medications.map(
                        (medication) => CheckboxListTile(
                          value: selected.contains(medication.id),
                          contentPadding: EdgeInsets.zero,
                          title: Text(medication.name),
                          subtitle: Text(
                            '${medication.dosage} • ${formatSchedule(medication.scheduleDays, medication.scheduleTimes)}',
                          ),
                          onChanged: (value) {
                            setSheetState(() {
                              if (value == true) {
                                selected.add(medication.id);
                              } else {
                                selected.remove(medication.id);
                              }
                            });
                          },
                        ),
                      ),
                    const SizedBox(height: AppSpacing.md),
                    PrimaryGradientButton(
                      label: 'Save Selection',
                      onPressed: () => Navigator.of(
                        sheetContext,
                      ).pop(selected.toList()..sort()),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (selectedIds == null) return;

    await _saveDevice(
      device.copyWith(medicationIds: selectedIds, updatedAt: DateTime.now()),
      successMessage: 'Linked medications updated.',
    );
  }

  Future<void> _addManualInterval(DoseBuddyDevice device) async {
    if (device.manualIntervals.length >=
        DoseBuddyConstants.maxManualIntervals) {
      showSnackBar(
        context,
        'Dose Buddy is limited to ${DoseBuddyConstants.maxManualIntervals} manual intervals.',
        backgroundColor: AppColors.warning,
      );
      return;
    }

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
    );
    if (selectedTime == null) return;

    final interval = _timeToString(selectedTime);
    final nextIntervals = {...device.manualIntervals, interval}.toList()
      ..sort();

    await _saveDevice(
      device.copyWith(
        manualIntervals: nextIntervals,
        updatedAt: DateTime.now(),
      ),
      successMessage: 'Manual interval added.',
    );
  }

  Future<void> _removeManualInterval(
    DoseBuddyDevice device,
    String interval,
  ) async {
    final nextIntervals = [...device.manualIntervals]..remove(interval);
    await _saveDevice(
      device.copyWith(
        manualIntervals: nextIntervals,
        updatedAt: DateTime.now(),
      ),
      successMessage: 'Manual interval removed.',
    );
  }

  Future<void> _saveDevice(
    DoseBuddyDevice device, {
    required String successMessage,
  }) async {
    if (_isSaving) return;

    setState(() => _isSaving = true);
    try {
      await _doseBuddyService.upsertConfiguration(device);
      if (mounted) {
        showSnackBar(
          context,
          successMessage,
          backgroundColor: AppColors.success,
        );
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(
          context,
          'Dose Buddy update failed: $e',
          backgroundColor: AppColors.danger,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _syncTutorialOverlay(DoseBuddySessionState session) {
    if (!_tutorialOverlayVisible) {
      return;
    }

    final lowerMessage = (session.message ?? '').toLowerCase();
    if (session.demoState != null) {
      _clearTutorialResponseTimeout();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _isTutorialActionPending = false;
          _tutorialTimedOut = false;
        });
      });
      return;
    }

    final shouldClose =
        session.demoState == null &&
        (lowerMessage.contains('tutorial finished') ||
            lowerMessage.contains('back in normal mode') ||
            session.status == DoseBuddyConnectionStatus.disconnected);

    if (shouldClose) {
      _clearTutorialResponseTimeout();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _setTutorialOverlayVisible(false);
          _isTutorialActionPending = false;
          _tutorialTimedOut = false;
        });
      });
    }
  }

  void _setTutorialOverlayVisible(bool visible) {
    _tutorialOverlayVisible = visible;
    medButtonTutorialOverlayActive.value = visible;
  }

  void _clearTutorialResponseTimeout() {
    _tutorialResponseTimeout?.cancel();
    _tutorialResponseTimeout = null;
  }

  void _armTutorialResponseTimeout() {
    _clearTutorialResponseTimeout();
    _tutorialResponseTimeout = Timer(const Duration(seconds: 4), () {
      if (!mounted || !_tutorialOverlayVisible) {
        return;
      }

      if (_doseBuddyService.sessionStateNow.demoState != null) {
        return;
      }

      unawaited(_recoverTimedOutTutorial());
    });
  }

  Future<void> _recoverTimedOutTutorial() async {
    if (!mounted || !_tutorialOverlayVisible) {
      return;
    }

    setState(() {
      _isTutorialActionPending = true;
      _tutorialTimedOut = true;
    });

    try {
      await _doseBuddyService.stopTutorialDemo();
      if (!mounted) return;

      setState(() {
        _setTutorialOverlayVisible(false);
        _isTutorialActionPending = false;
        _tutorialTimedOut = false;
      });

      showSnackBar(
        context,
        'Dose Buddy tutorial timed out and was closed automatically.',
        backgroundColor: AppColors.warning,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isTutorialActionPending = false;
        _tutorialTimedOut = true;
      });

      showSnackBar(
        context,
        'Dose Buddy did not answer. Use Finish tutorial to force the device back to normal mode.',
        backgroundColor: AppColors.warning,
      );
    }
  }

  void _ensureTutorialActionAccepted() {
    final session = _doseBuddyService.sessionStateNow;
    if (session.status == DoseBuddyConnectionStatus.attention ||
        session.status == DoseBuddyConnectionStatus.bluetoothOff ||
        session.status == DoseBuddyConnectionStatus.disconnected) {
      throw StateError(
        session.message ?? 'Dose Buddy tutorial command could not be applied.',
      );
    }
  }

  Widget _buildActionButtonGrid(
    List<_ActionButtonConfig> actions, {
    bool compact = false,
    bool preferTwoColumns = false,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useTwoColumns =
            preferTwoColumns &&
            constraints.maxWidth >= 300 &&
            actions.length > 1;
        final columnCount = useTwoColumns
            ? 2
            : constraints.maxWidth >= 520
            ? 2
            : 1;
        final totalSpacing = AppSpacing.md * (columnCount - 1);
        final itemWidth = (constraints.maxWidth - totalSpacing) / columnCount;

        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: actions
              .map(
                (action) => SizedBox(
                  width: itemWidth,
                  child: _ActionTileButton(config: action, compact: compact),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildTutorialActionBar({
    required bool canReplayOrContinue,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withAlpha(18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _TutorialActionButton(
                  label: 'Replay',
                  icon: Icons.refresh_rounded,
                  accentColor: Colors.white,
                  onPressed: canReplayOrContinue ? _replayTutorialStep : null,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _TutorialActionButton(
                  label: 'Continue',
                  icon: Icons.arrow_forward_rounded,
                  accentColor: accentColor,
                  emphasized: true,
                  onPressed: canReplayOrContinue ? _continueTutorialDemo : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _TutorialActionButton(
            label: 'Finish tutorial',
            icon: Icons.close_rounded,
            accentColor: const Color(0xFF7DD3FC),
            onPressed: _isTutorialActionPending ? null : _finishTutorialDemo,
          ),
        ],
      ),
    );
  }

  Widget _buildTutorialOverlay(DoseBuddySessionState session) {
    final demoState = session.demoState;
    final presentation = _tutorialPresentation(demoState);
    final isWaitingForStep = demoState == null;
    final canReplayOrContinue = !_isTutorialActionPending;

    return Positioned.fill(
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: ColoredBox(
            color: const Color(0xFF09111F).withAlpha(242),
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compactLayout = constraints.maxHeight < 820;
                  final outerPadding = compactLayout ? 16.0 : 20.0;
                  final visualHeight = compactLayout ? 220.0 : 300.0;

                  return Padding(
                    padding: EdgeInsets.fromLTRB(
                      outerPadding,
                      compactLayout ? 12 : 20,
                      outerPadding,
                      compactLayout ? 16 : 20,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 540),
                        child: Container(
                          width: double.infinity,
                          height: double.infinity,
                          padding: EdgeInsets.all(compactLayout ? 16 : 20),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                presentation.accentColor.withAlpha(68),
                                const Color(0xFF101A2D),
                                const Color(0xFF09111F),
                              ],
                            ),
                            border: Border.all(
                              color: Colors.white.withAlpha(20),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: presentation.accentColor.withAlpha(48),
                                blurRadius: 40,
                                spreadRadius: 6,
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Wrap(
                                alignment: WrapAlignment.start,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: AppSpacing.sm,
                                runSpacing: AppSpacing.xs,
                                children: [
                                  _TutorialBadge(
                                    label: isWaitingForStep
                                        ? 'Preparing tutorial'
                                        : 'Mode ${demoState.stepIndex}/${demoState.totalSteps}',
                                    color: presentation.accentColor,
                                  ),
                                  Text(
                                    'Wheel tutorial',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: Colors.white.withAlpha(180),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(
                                height: compactLayout
                                    ? AppSpacing.md
                                    : AppSpacing.lg,
                              ),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      height: visualHeight,
                                      child: Center(
                                        child: isWaitingForStep
                                            ? Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  CircularProgressIndicator(
                                                    color: presentation
                                                        .accentColor,
                                                  ),
                                                  const SizedBox(
                                                    height: AppSpacing.md,
                                                  ),
                                                  Text(
                                                    _tutorialTimedOut
                                                        ? 'Dose Buddy did not answer.'
                                                        : 'Waiting for dispenser...',
                                                    style: AppTextStyles
                                                        .bodyMedium
                                                        .copyWith(
                                                          color: Colors.white,
                                                        ),
                                                  ),
                                                  const SizedBox(
                                                    height: AppSpacing.sm,
                                                  ),
                                                  Text(
                                                    _tutorialTimedOut
                                                        ? 'Trying to stop the tutorial. If needed, use Finish below.'
                                                        : 'Dose Buddy is preparing the wheel preview.',
                                                    textAlign: TextAlign.center,
                                                    style: AppTextStyles
                                                        .bodySmall
                                                        .copyWith(
                                                          color: Colors.white
                                                              .withAlpha(190),
                                                          height: 1.4,
                                                        ),
                                                  ),
                                                ],
                                              )
                                            : FittedBox(
                                                fit: BoxFit.contain,
                                                child: SizedBox(
                                                  width: compactLayout
                                                      ? 320
                                                      : 380,
                                                  height: compactLayout
                                                      ? 320
                                                      : 380,
                                                  child: _TutorialDeviceVisualizer(
                                                    stepKey:
                                                        presentation.stepKey,
                                                    accentColor: presentation
                                                        .accentColor,
                                                    animationSeed:
                                                        _tutorialAnimationSeed +
                                                        demoState.stepIndex,
                                                  ),
                                                ),
                                              ),
                                      ),
                                    ),
                                    SizedBox(
                                      height: compactLayout
                                          ? AppSpacing.md
                                          : AppSpacing.lg,
                                    ),
                                    Text(
                                      presentation.title,
                                      textAlign: TextAlign.center,
                                      style:
                                          (compactLayout
                                                  ? AppTextStyles.heading3
                                                  : AppTextStyles.heading2)
                                              .copyWith(color: Colors.white),
                                    ),
                                    const SizedBox(height: AppSpacing.sm),
                                    Text(
                                      presentation.meaning,
                                      textAlign: TextAlign.center,
                                      style:
                                          (compactLayout
                                                  ? AppTextStyles.bodySmall
                                                  : AppTextStyles.bodyMedium)
                                              .copyWith(
                                                color: Colors.white.withAlpha(
                                                  214,
                                                ),
                                                height: 1.42,
                                              ),
                                    ),
                                    const SizedBox(height: AppSpacing.md),
                                    Wrap(
                                      alignment: WrapAlignment.center,
                                      spacing: AppSpacing.sm,
                                      runSpacing: AppSpacing.sm,
                                      children: [
                                        _TutorialBadge(
                                          label: presentation.ledLabel,
                                          color: presentation.accentColor,
                                          outlined: true,
                                        ),
                                        _TutorialBadge(
                                          label: presentation.hintLabel,
                                          color: presentation.accentColor,
                                          outlined: true,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              _buildTutorialActionBar(
                                canReplayOrContinue: canReplayOrContinue,
                                accentColor: presentation.accentColor,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  _TutorialPresentation _tutorialPresentation(DoseBuddyDemoState? demoState) {
    switch (demoState?.stepKey) {
      case 'window_open':
      case 'interval_ready':
        return const _TutorialPresentation(
          stepKey: 'window_open',
          title: 'Dose window open',
          meaning:
              'Dose Buddy allows one dispense during the hour before the scheduled time. In the last 10 minutes, the green LED double-blinks every 5 seconds.',
          ledLabel: 'Green LED x2',
          hintLabel: 'One dose ready now',
          accentColor: Color(0xFF33C26F),
        );
      case 'dispensing':
      case 'confirmed':
        return const _TutorialPresentation(
          stepKey: 'dispensing',
          title: 'Wheel dispensing',
          meaning:
              'Pressing the button turns the Dose Buddy wheel, releases one dose, and closes this interval so it cannot be dispensed again.',
          ledLabel: 'Green confirm',
          hintLabel: 'Interval is finished',
          accentColor: Color(0xFF20B8A8),
        );
      case 'already_taken':
        return const _TutorialPresentation(
          stepKey: 'already_taken',
          title: 'Already dispensed',
          meaning:
              'This interval already triggered the wheel once, so a second press is ignored.',
          ledLabel: 'Green LED x2',
          hintLabel: 'No second dose now',
          accentColor: Color(0xFF28C98D),
        );
      case 'missed_interval':
      case 'missed_alert':
        return const _TutorialPresentation(
          stepKey: 'missed_interval',
          title: 'Missed interval',
          meaning:
              'After the scheduled time passes, the red LED triple-blinks every 10 seconds and the buzzer sounds for 30 seconds every 5 minutes for one hour.',
          ledLabel: 'Red LED x3',
          hintLabel: 'One hour to react',
          accentColor: Color(0xFFF05D5E),
        );
      case 'refill_needed':
        return const _TutorialPresentation(
          stepKey: 'refill_needed',
          title: 'Refill dispenser',
          meaning:
              'After 15 dispenses, the red and green LEDs alternate until Dose Buddy is refilled and confirmed in the app.',
          ledLabel: 'Red + green alternate',
          hintLabel: 'Load 15 new doses',
          accentColor: Color(0xFFFFB84D),
        );
      case 'needs_sync':
        return const _TutorialPresentation(
          stepKey: 'needs_sync',
          title: 'Needs sync',
          meaning:
              'A red warning pulse means the device needs a fresh update from the app.',
          ledLabel: 'Red LED x1',
          hintLabel: 'Reconnect and sync',
          accentColor: Color(0xFFFF8F4D),
        );
      case 'waiting':
      default:
        return const _TutorialPresentation(
          stepKey: 'waiting',
          title: 'Wheel idle',
          meaning:
              'No dose is due right now. Dose Buddy stays quiet until the next hour-before-dose window opens.',
          ledLabel: 'LEDs off',
          hintLabel: 'Waiting for next dose',
          accentColor: Color(0xFF8FA6C7),
        );
    }
  }

  Future<DoseBuddyScanCandidate?> _showDevicePicker(
    List<DoseBuddyScanCandidate> candidates,
  ) {
    return showModalBottomSheet<DoseBuddyScanCandidate>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: AppPadding.page,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Choose Dose Buddy', style: AppTextStyles.heading3),
                const SizedBox(height: AppSpacing.md),
                ...candidates.map(
                  (candidate) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.medication_rounded),
                    title: Text(candidate.displayName),
                    subtitle: Text(
                      'Signal ${candidate.rssi} dBm • ID ${candidate.remoteId}',
                    ),
                    onTap: () => Navigator.of(sheetContext).pop(candidate),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _timeToString(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _eventTitle(String feedbackType) {
    switch (feedbackType) {
      case 'confirmed':
        return 'Dose dispensed';
      case 'already_taken':
        return 'Already dispensed';
      default:
        return 'Dose Buddy update';
    }
  }

  String _eventSubtitle(
    DoseBuddyEvent event,
    Map<String, Medication> medicationsById,
  ) {
    if (event.medicationIds.isEmpty) {
      return 'Dispenser slot at ${formatTimeHm(event.scheduledAt)}';
    }

    final medicationNames = event.medicationIds
        .map((id) => medicationsById[id]?.name)
        .whereType<String>()
        .toList();

    if (medicationNames.isEmpty) {
      return 'Dispensed slot at ${formatTimeHm(event.scheduledAt)}';
    }

    return '${medicationNames.join(', ')} • dispensed at ${formatTimeHm(event.scheduledAt)}';
  }

  Color _statusColor(DoseBuddyConnectionStatus status) {
    switch (status) {
      case DoseBuddyConnectionStatus.connected:
        return AppColors.success;
      case DoseBuddyConnectionStatus.syncing:
      case DoseBuddyConnectionStatus.scanning:
      case DoseBuddyConnectionStatus.connecting:
        return AppColors.primary;
      case DoseBuddyConnectionStatus.bluetoothOff:
      case DoseBuddyConnectionStatus.attention:
        return AppColors.warning;
      case DoseBuddyConnectionStatus.unsupported:
        return AppColors.danger;
      case DoseBuddyConnectionStatus.disconnected:
        return AppColors.textSecondary;
    }
  }

  IconData _statusIcon(DoseBuddyConnectionStatus status) {
    switch (status) {
      case DoseBuddyConnectionStatus.connected:
        return Icons.check_circle_outline;
      case DoseBuddyConnectionStatus.syncing:
        return Icons.sync;
      case DoseBuddyConnectionStatus.scanning:
        return Icons.search;
      case DoseBuddyConnectionStatus.connecting:
        return Icons.bluetooth_connected;
      case DoseBuddyConnectionStatus.bluetoothOff:
        return Icons.bluetooth_disabled;
      case DoseBuddyConnectionStatus.attention:
        return Icons.warning_amber_rounded;
      case DoseBuddyConnectionStatus.unsupported:
        return Icons.block;
      case DoseBuddyConnectionStatus.disconnected:
        return Icons.medication_rounded;
    }
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label, style: AppTextStyles.bodyMediumSemiBold)),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionButtonConfig {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool danger;

  const _ActionButtonConfig({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.danger = false,
  });
}

class _ActionTileButton extends StatelessWidget {
  final _ActionButtonConfig config;
  final bool compact;

  const _ActionTileButton({required this.config, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final color = config.danger ? AppColors.danger : AppColors.primary;
    if (compact) {
      return Material(
        color: color.withAlpha(14),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: config.onPressed,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withAlpha(26),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(config.icon, color: color),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  config.label,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMediumSemiBold.copyWith(
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Material(
      color: color.withAlpha(16),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: config.onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withAlpha(28),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(config.icon, color: color),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  config.label,
                  style: AppTextStyles.bodyMediumSemiBold.copyWith(
                    color: color,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String message;

  const _InlineNotice({
    required this.icon,
    required this.color,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withAlpha(12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withAlpha(32)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodySmall.copyWith(
                color: color,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TutorialPresentation {
  final String stepKey;
  final String title;
  final String meaning;
  final String ledLabel;
  final String hintLabel;
  final Color accentColor;

  const _TutorialPresentation({
    required this.stepKey,
    required this.title,
    required this.meaning,
    required this.ledLabel,
    required this.hintLabel,
    required this.accentColor,
  });
}

class _TutorialBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool outlined;

  const _TutorialBadge({
    required this.label,
    required this.color,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final background = outlined ? Colors.transparent : color.withAlpha(28);
    final foreground = outlined ? Colors.white : color;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: outlined ? Colors.white.withAlpha(48) : Colors.transparent,
        ),
      ),
      child: Text(
        label,
        style: AppTextStyles.bodySmall.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TutorialActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color accentColor;
  final VoidCallback? onPressed;
  final bool emphasized;

  const _TutorialActionButton({
    required this.label,
    required this.icon,
    required this.accentColor,
    required this.onPressed,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final foreground = enabled ? Colors.white : Colors.white.withAlpha(130);
    final borderColor = emphasized
        ? accentColor.withAlpha(enabled ? 120 : 44)
        : Colors.white.withAlpha(enabled ? 30 : 18);
    final backgroundColor = emphasized
        ? accentColor.withAlpha(enabled ? 34 : 14)
        : Colors.white.withAlpha(enabled ? 10 : 6);

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: foreground),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMediumSemiBold.copyWith(
                      color: foreground,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TutorialDeviceVisualizer extends StatefulWidget {
  final String stepKey;
  final Color accentColor;
  final int animationSeed;

  const _TutorialDeviceVisualizer({
    required this.stepKey,
    required this.accentColor,
    required this.animationSeed,
  });

  @override
  State<_TutorialDeviceVisualizer> createState() =>
      _TutorialDeviceVisualizerState();
}

class _TutorialDeviceVisualizerState extends State<_TutorialDeviceVisualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant _TutorialDeviceVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stepKey != widget.stepKey ||
        oldWidget.animationSeed != widget.animationSeed) {
      _controller
        ..reset()
        ..repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final visual = _visualStateFor(widget.stepKey, _controller.value);

        return LayoutBuilder(
          builder: (context, constraints) {
            final deviceWidth = constraints.maxWidth > 380
                ? 360.0
                : constraints.maxWidth - 8;

            return Stack(
              alignment: Alignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 330,
                  height: 330,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        widget.accentColor.withAlpha(
                          visual.isAnySignalActive ? 70 : 18,
                        ),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                Container(
                  width: deviceWidth,
                  constraints: const BoxConstraints(maxWidth: 360),
                  padding: const EdgeInsets.fromLTRB(28, 28, 28, 26),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(34),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF1A2538), Color(0xFF0E1524)],
                    ),
                    border: Border.all(color: Colors.white.withAlpha(18)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _LedOrb(
                            label: 'Green',
                            active: visual.greenOn,
                            activeColor: const Color(0xFF37D67A),
                          ),
                          _LedOrb(
                            label: 'Red',
                            active: visual.redOn,
                            activeColor: const Color(0xFFF25A67),
                          ),
                        ],
                      ),
                      Container(
                        width: 148,
                        height: 148,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withAlpha(34),
                              Colors.white.withAlpha(10),
                            ],
                          ),
                          border: Border.all(
                            color: Colors.white.withAlpha(44),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: widget.accentColor.withAlpha(40),
                              blurRadius: 22,
                              spreadRadius: visual.isAnySignalActive ? 4 : 0,
                            ),
                          ],
                        ),
                        child: _WheelDial(
                          turns: visual.wheelTurns,
                          accentColor: widget.accentColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  _TutorialVisualState _visualStateFor(String stepKey, double progress) {
    bool isActive(List<List<double>> windows) {
      for (final window in windows) {
        if (progress >= window.first && progress <= window.last) {
          return true;
        }
      }
      return false;
    }

    switch (stepKey) {
      case 'interval_ready':
      case 'window_open':
        return _TutorialVisualState(
          greenOn: isActive([
            [0.04, 0.18],
            [0.30, 0.44],
            [0.56, 0.70],
          ]),
        );
      case 'dispensing':
      case 'confirmed':
        return _TutorialVisualState(
          greenOn: isActive([
            [0.08, 0.22],
          ]),
          wheelTurns: progress * 1.2,
        );
      case 'already_taken':
        return _TutorialVisualState(
          greenOn: isActive([
            [0.06, 0.16],
            [0.28, 0.38],
          ]),
        );
      case 'missed_interval':
      case 'missed_alert':
        return _TutorialVisualState(
          redOn: isActive([
            [0.06, 0.18],
            [0.30, 0.42],
            [0.54, 0.66],
          ]),
        );
      case 'refill_needed':
        return _TutorialVisualState(
          greenOn: isActive([
            [0.0, 0.18],
            [0.36, 0.54],
          ]),
          redOn: isActive([
            [0.18, 0.36],
            [0.54, 0.72],
          ]),
        );
      case 'needs_sync':
        return _TutorialVisualState(
          redOn: isActive([
            [0.10, 0.24],
          ]),
        );
      case 'waiting':
      default:
        return const _TutorialVisualState();
    }
  }
}

class _TutorialVisualState {
  final bool greenOn;
  final bool redOn;
  final double wheelTurns;

  const _TutorialVisualState({
    this.greenOn = false,
    this.redOn = false,
    this.wheelTurns = 0,
  });

  bool get isAnySignalActive => greenOn || redOn || wheelTurns > 0;
}

class _WheelDial extends StatelessWidget {
  final double turns;
  final Color accentColor;

  const _WheelDial({required this.turns, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: turns * math.pi * 2,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withAlpha(36), width: 2),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [accentColor.withAlpha(58), Colors.white.withAlpha(10)],
              ),
            ),
          ),
          for (var index = 0; index < 8; index++)
            Transform.rotate(
              angle: (math.pi * 2 / 8) * index,
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  margin: const EdgeInsets.only(top: 10),
                  width: 18,
                  height: 34,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: Colors.white.withAlpha(index.isEven ? 60 : 26),
                    border: Border.all(color: Colors.white.withAlpha(24)),
                  ),
                ),
              ),
            ),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF101926),
              border: Border.all(color: Colors.white.withAlpha(40)),
            ),
            child: Icon(Icons.medication_rounded, color: accentColor, size: 24),
          ),
        ],
      ),
    );
  }
}

class _LedOrb extends StatelessWidget {
  final String label;
  final bool active;
  final Color activeColor;

  const _LedOrb({
    required this.label,
    required this.active,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? activeColor : Colors.white.withAlpha(20),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: activeColor.withAlpha(140),
                      blurRadius: 24,
                      spreadRadius: 3,
                    ),
                  ]
                : [],
            border: Border.all(
              color: Colors.white.withAlpha(active ? 120 : 36),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: Colors.white.withAlpha(194),
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatusChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: color.withAlpha(12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool alignCenter;

  const _DashboardMetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.alignCenter = false,
  });

  @override
  Widget build(BuildContext context) {
    final crossAxisAlignment = alignCenter
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(188),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withAlpha(24)),
      ),
      child: Column(
        crossAxisAlignment: crossAxisAlignment,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withAlpha(16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(label, style: AppTextStyles.captionSecondary),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            textAlign: alignCenter ? TextAlign.center : TextAlign.left,
            style:
                (alignCenter
                        ? AppTextStyles.heading2
                        : AppTextStyles.bodyMediumSemiBold)
                    .copyWith(color: AppColors.textTertiary, height: 1.3),
          ),
        ],
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final String timeLabel;

  const _EventRow({
    required this.title,
    required this.subtitle,
    required this.timeLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.bodyMediumSemiBold),
          const SizedBox(height: AppSpacing.xs),
          Text(subtitle, style: AppTextStyles.bodyMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(timeLabel, style: AppTextStyles.captionSecondary),
        ],
      ),
    );
  }
}
