import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:med_track/database/ioc/ioc_container.dart';
import 'package:med_track/database/model/dose_buddy_device.dart';
import 'package:med_track/database/model/dose_buddy_event.dart';
import 'package:med_track/database/model/medication.dart';
import 'package:med_track/database/model/app_user.dart';
import 'package:med_track/database/service/auth_service.dart';
import 'package:med_track/database/service/dose_buddy/dose_buddy_device_database_service.dart';
import 'package:med_track/database/service/dose_buddy/dose_buddy_event_database_service.dart';
import 'package:med_track/database/service/dose_event/dose_event_database_service.dart';
import 'package:med_track/database/service/medication_database_service.dart';
import 'package:med_track/utils/constants.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DoseBuddyConnectionStatus {
  unsupported,
  bluetoothOff,
  disconnected,
  scanning,
  connecting,
  connected,
  syncing,
  attention,
}

class DoseBuddyScanCandidate {
  final String remoteId;
  final String displayName;
  final int rssi;

  const DoseBuddyScanCandidate({
    required this.remoteId,
    required this.displayName,
    required this.rssi,
  });
}

const Object _doseBuddyCopySentinel = Object();

class DoseBuddyDemoState {
  final String stepKey;
  final String title;
  final String description;
  final int stepIndex;
  final int totalSteps;
  final bool isRunning;

  const DoseBuddyDemoState({
    required this.stepKey,
    required this.title,
    required this.description,
    required this.stepIndex,
    required this.totalSteps,
    required this.isRunning,
  });
}

class _DoseBuddyTutorialStep {
  final String stepKey;
  final String title;
  final String description;

  const _DoseBuddyTutorialStep({
    required this.stepKey,
    required this.title,
    required this.description,
  });
}

const List<_DoseBuddyTutorialStep> _doseBuddyTutorialSteps = [
  _DoseBuddyTutorialStep(
    stepKey: 'window_open',
    title: 'Dose window is open',
    description:
        'The wheel is ready. Press the hardware button during the last hour of the interval to dispense one dose.',
  ),
  _DoseBuddyTutorialStep(
    stepKey: 'dispensing',
    title: 'Wheel dispensing',
    description:
        'The stepper turns the dosing wheel and releases one prepared dose.',
  ),
  _DoseBuddyTutorialStep(
    stepKey: 'missed_interval',
    title: 'Missed interval alert',
    description:
        'A red blinking alert means the take window expired and the dose needs attention.',
  ),
  _DoseBuddyTutorialStep(
    stepKey: 'refill_needed',
    title: 'Refill needed',
    description:
        'After 15 dispenses, the device asks for a refill with alternating red and green LEDs.',
  ),
];

class DoseBuddySessionState {
  final DoseBuddyConnectionStatus status;
  final String? deviceId;
  final String? deviceName;
  final String? message;
  final int? batteryLevel;
  final int? remainingDoses;
  final int? dispenserCapacity;
  final DateTime? nextDueAt;
  final DateTime? lastSeenAt;
  final DateTime? lastSyncAt;
  final DateTime? lastConfirmedAt;
  final bool isAlarmActive;
  final bool refillNeeded;
  final bool isDispenseWindowOpen;
  final DoseBuddyDemoState? demoState;

  const DoseBuddySessionState({
    required this.status,
    this.deviceId,
    this.deviceName,
    this.message,
    this.batteryLevel,
    this.remainingDoses,
    this.dispenserCapacity,
    this.nextDueAt,
    this.lastSeenAt,
    this.lastSyncAt,
    this.lastConfirmedAt,
    this.isAlarmActive = false,
    this.refillNeeded = false,
    this.isDispenseWindowOpen = false,
    this.demoState,
  });

  factory DoseBuddySessionState.initial() => const DoseBuddySessionState(
    status: DoseBuddyConnectionStatus.disconnected,
    message: 'Pair a DoseBuddy to get started.',
  );

  DoseBuddySessionState copyWith({
    DoseBuddyConnectionStatus? status,
    String? deviceId,
    String? deviceName,
    String? message,
    int? batteryLevel,
    int? remainingDoses,
    int? dispenserCapacity,
    DateTime? nextDueAt,
    DateTime? lastSeenAt,
    DateTime? lastSyncAt,
    DateTime? lastConfirmedAt,
    bool? isAlarmActive,
    bool? refillNeeded,
    bool? isDispenseWindowOpen,
    Object? demoState = _doseBuddyCopySentinel,
  }) {
    return DoseBuddySessionState(
      status: status ?? this.status,
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      message: message ?? this.message,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      remainingDoses: remainingDoses ?? this.remainingDoses,
      dispenserCapacity: dispenserCapacity ?? this.dispenserCapacity,
      nextDueAt: nextDueAt ?? this.nextDueAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      lastConfirmedAt: lastConfirmedAt ?? this.lastConfirmedAt,
      isAlarmActive: isAlarmActive ?? this.isAlarmActive,
      refillNeeded: refillNeeded ?? this.refillNeeded,
      isDispenseWindowOpen: isDispenseWindowOpen ?? this.isDispenseWindowOpen,
      demoState: identical(demoState, _doseBuddyCopySentinel)
          ? this.demoState
          : demoState as DoseBuddyDemoState?,
    );
  }
}

class DoseBuddyService {
  final AuthService _authService = get<AuthService>();
  final DoseBuddyDeviceDatabaseService _deviceDb =
      get<DoseBuddyDeviceDatabaseService>();
  final DoseBuddyEventDatabaseService _eventDb =
      get<DoseBuddyEventDatabaseService>();
  final MedicationDatabaseService _medicationDb =
      get<MedicationDatabaseService>();
  final DoseEventDatabaseService _doseEventDb = get<DoseEventDatabaseService>();

  final BehaviorSubject<DoseBuddySessionState> _sessionState =
      BehaviorSubject.seeded(DoseBuddySessionState.initial());

  StreamSubscription<AppUser?>? _authSubscription;
  StreamSubscription<DoseBuddyDevice?>? _deviceSubscription;
  StreamSubscription<BluetoothAdapterState>? _adapterSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  StreamSubscription<List<int>>? _eventSubscription;

  BluetoothDevice? _activeDevice;
  BluetoothCharacteristic? _controlCharacteristic;
  BluetoothCharacteristic? _eventCharacteristic;
  DoseBuddyDevice? _currentConfig;
  String? _currentUserId;
  String? _activeRemoteId;
  bool _initialized = false;
  bool _didInitialReconnectForUser = false;
  bool _hasConnectedOnce = false;
  bool _isPreparingConnection = false;
  bool _didSyncForCurrentConnection = false;
  int _scanAttemptCounter = 0;
  int _lastKnownTutorialStepIndex = 0;
  String? _lastSyncedConfigFingerprint;
  final List<int> _eventMessageBuffer = <int>[];
  Future<void> _controlOperationQueue = Future.value();
  Future<bool>? _syncInFlight;
  Timer? _scheduledSyncRetry;

  Stream<DoseBuddySessionState> get sessionState => _sessionState.stream;
  DoseBuddySessionState get sessionStateNow => _sessionState.value;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await _restoreSessionState();

    _adapterSubscription = FlutterBluePlus.adapterState.listen((state) {
      _handleAdapterStateChanged(state);
    });

    _authSubscription = _authService.currentUserStream.listen((user) {
      unawaited(_handleAuthenticatedUserChanged(user?.id));
    });
  }

  Future<void> dispose() async {
    _cancelScheduledSyncRetry();
    await _eventSubscription?.cancel();
    await _connectionSubscription?.cancel();
    await _deviceSubscription?.cancel();
    await _adapterSubscription?.cancel();
    await _authSubscription?.cancel();
    await _sessionState.close();
  }

  Future<void> handleAppResumed() async {
    if (_currentConfig == null || !_currentConfig!.autoReconnectEnabled) {
      return;
    }

    if (_isPreparingConnection ||
        sessionStateNow.status == DoseBuddyConnectionStatus.connecting ||
        sessionStateNow.status == DoseBuddyConnectionStatus.syncing) {
      return;
    }

    if (_activeDevice != null &&
        _activeDevice!.isConnected &&
        _activeRemoteId == _currentConfig!.bleDeviceId) {
      await refreshDeviceStatus();
      return;
    }

    await connectToConfiguredDevice(
      autoConnect: true,
      waitForConnection: false,
    );
  }

  Future<List<DoseBuddyScanCandidate>> scanForCandidates() async {
    if (!await _ensureBluetoothReady()) {
      return const [];
    }

    final scanAttempt = ++_scanAttemptCounter;
    final startedAt = DateTime.now();
    final rawResults = <String, ScanResult>{};
    final locationServiceEnabled = await _isLocationServiceEnabled();
    final bluetoothScanStatus = await Permission.bluetoothScan.status;
    final bluetoothConnectStatus = await Permission.bluetoothConnect.status;
    final locationPermissionStatus = await Permission.locationWhenInUse.status;

    _logScanDebug(
      'scan#$scanAttempt start '
      'adapter=${FlutterBluePlus.adapterStateNow.name} '
      'sdk=${_androidSdkVersionLabel()} '
      'btScan=$bluetoothScanStatus '
      'btConnect=$bluetoothConnectStatus '
      'locationPermission=$locationPermissionStatus '
      'locationService=${locationServiceEnabled == null
          ? 'unknown'
          : locationServiceEnabled
          ? 'enabled'
          : 'disabled'}',
    );

    _emitState(
      sessionStateNow.copyWith(
        status: DoseBuddyConnectionStatus.scanning,
        message: 'Looking for nearby DoseBuddy devices...',
      ),
    );

    final seen = <String, DoseBuddyScanCandidate>{};
    late final StreamSubscription<List<ScanResult>> subscription;

    subscription = FlutterBluePlus.onScanResults.listen(
      (results) {
        for (final result in results) {
          final remoteId = result.device.remoteId.str;
          final previous = rawResults[remoteId];
          rawResults[remoteId] = result;

          if (_shouldLogScanResult(previous, result)) {
            _logScanDebug(
              'scan#$scanAttempt result ${_formatScanResultForDebug(result)} '
              'candidate=${_isDoseBuddyCandidate(result)}',
            );
          }

          if (!_isDoseBuddyCandidate(result)) {
            continue;
          }

          final name = _candidateName(result);
          seen[result.device.remoteId.str] = DoseBuddyScanCandidate(
            remoteId: result.device.remoteId.str,
            displayName: name,
            rssi: result.rssi,
          );

          _logScanDebug(
            'scan#$scanAttempt matched remoteId=${result.device.remoteId.str} '
            'name="$name" rssi=${result.rssi}',
          );
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        _logScanDebug('scan#$scanAttempt stream error: $error');
        _emitState(
          sessionStateNow.copyWith(
            status: DoseBuddyConnectionStatus.attention,
            message: 'DoseBuddy scan failed. Check Bluetooth permissions.',
          ),
        );
      },
    );

    try {
      await FlutterBluePlus.startScan(
        androidUsesFineLocation: _requiresFineLocationForBleScan(),
        androidCheckLocationServices: false,
        timeout: const Duration(seconds: DoseBuddyConstants.scanTimeoutSeconds),
      );
      await FlutterBluePlus.isScanning.where((value) => value == false).first;
    } catch (e) {
      _logScanDebug('scan#$scanAttempt startScan error: $e');
      rethrow;
    } finally {
      await subscription.cancel();
    }

    _logScanDebug(
      'scan#$scanAttempt finished '
      'durationMs=${DateTime.now().difference(startedAt).inMilliseconds} '
      'rawDevices=${rawResults.length} matchedDevices=${seen.length}',
    );

    final items = seen.values.toList()
      ..sort((a, b) {
        final aLikely = a.displayName.toLowerCase().contains('dosebuddy');
        final bLikely = b.displayName.toLowerCase().contains('dosebuddy');
        if (aLikely != bLikely) {
          return bLikely ? 1 : -1;
        }

        final rssiCompare = b.rssi.compareTo(a.rssi);
        if (rssiCompare != 0) {
          return rssiCompare;
        }

        return a.displayName.compareTo(b.displayName);
      });

    if (items.isEmpty) {
      _emitState(
        sessionStateNow.copyWith(
          status: DoseBuddyConnectionStatus.disconnected,
          message: _buildNoDoseBuddyFoundMessage(
            rawDeviceCount: rawResults.length,
            locationServiceEnabled: locationServiceEnabled,
          ),
        ),
      );
    } else if (items.length == 1) {
      _emitState(
        sessionStateNow.copyWith(
          status: DoseBuddyConnectionStatus.connecting,
          message: 'DoseBuddy found. Connecting automatically...',
        ),
      );
    } else {
      _emitState(
        sessionStateNow.copyWith(
          status: DoseBuddyConnectionStatus.disconnected,
          message: 'Choose the DoseBuddy device to pair.',
        ),
      );
    }

    return items;
  }

  Future<void> upsertConfiguration(DoseBuddyDevice device) async {
    final normalizedDevice = device.copyWith(
      id: device.userId,
      medicationIds: _sortedUnique(device.medicationIds),
      manualIntervals: _sortedUnique(device.manualIntervals),
      updatedAt: DateTime.now(),
    );

    _currentConfig = normalizedDevice;
    await _deviceDb.savePrimaryDevice(normalizedDevice);

    _emitState(
      sessionStateNow.copyWith(
        deviceId: normalizedDevice.bleDeviceId,
        deviceName: normalizedDevice.displayName,
      ),
    );
  }

  Future<void> removeConfiguration() async {
    final userId = _currentUserId;
    if (userId == null) return;

    await disconnect(showDisconnectedMessage: false);
    await _deviceDb.delete(userId);
    _currentConfig = null;

    _emitState(
      DoseBuddySessionState(
        status: DoseBuddyConnectionStatus.disconnected,
        message: 'DoseBuddy has been removed.',
      ),
    );
  }

  Future<void> connectToConfiguredDevice({
    bool autoConnect = true,
    bool waitForConnection = false,
  }) async {
    final config = _currentConfig;
    if (config == null) return;

    await _connectToRemoteId(
      remoteId: config.bleDeviceId,
      displayName: config.displayName,
      autoConnect: autoConnect,
      waitForConnection: waitForConnection,
    );
  }

  Future<bool> syncConfiguration({bool scheduleRetryOnFailure = true}) {
    final inFlight = _syncInFlight;
    if (inFlight != null) {
      return inFlight;
    }

    final syncFuture = _performSyncConfiguration(
      scheduleRetryOnFailure: scheduleRetryOnFailure,
    );
    _syncInFlight = syncFuture.whenComplete(() {
      _syncInFlight = null;
    });

    return _syncInFlight!;
  }

  Future<bool> refreshDeviceStatus() async {
    final characteristic = _controlCharacteristic;
    if (characteristic == null) {
      return false;
    }

    try {
      final bytes = utf8.encode(jsonEncode(const {'type': 'request_status'}));
      await _enqueueControlOperation(() async {
        await _writeControlPayload(characteristic, bytes);
      });
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('DoseBuddy status refresh failed: $e');
      }
      return false;
    }
  }

  Future<bool> _performSyncConfiguration({
    required bool scheduleRetryOnFailure,
  }) async {
    final config = _currentConfig;
    final userId = _currentUserId;
    final characteristic = _controlCharacteristic;

    if (config == null || userId == null || characteristic == null) {
      return false;
    }

    _cancelScheduledSyncRetry();

    try {
      final medications = await _medicationDb.getUserMedications(userId);
      final assignedMedications = medications
          .where((medication) => config.medicationIds.contains(medication.id))
          .toList();

      final payload = _buildSyncPayload(config, assignedMedications);
      final syncFingerprint = _buildSyncFingerprint(
        config,
        assignedMedications,
      );
      if (_didSyncForCurrentConnection &&
          syncFingerprint == _lastSyncedConfigFingerprint) {
        return refreshDeviceStatus();
      }

      _emitState(
        sessionStateNow.copyWith(
          status: DoseBuddyConnectionStatus.syncing,
          message: 'Updating DoseBuddy schedule...',
        ),
      );

      final bytes = utf8.encode(jsonEncode(payload));
      await _enqueueControlOperation(() async {
        await _writeControlPayload(characteristic, bytes);
      });

      _didSyncForCurrentConnection = true;
      _lastSyncedConfigFingerprint = syncFingerprint;

      _emitState(
        sessionStateNow.copyWith(
          status: DoseBuddyConnectionStatus.connected,
          message: 'DoseBuddy is up to date.',
          lastSyncAt: DateTime.now(),
          lastSeenAt: DateTime.now(),
        ),
      );
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('DoseBuddy sync failed: $e');
      }

      if (_isRetryableControlWriteError(e)) {
        if (scheduleRetryOnFailure) {
          _scheduleSyncRetry();
        }

        _emitState(
          sessionStateNow.copyWith(
            status: DoseBuddyConnectionStatus.connected,
            message:
                'Dispenser is connected. The app will try the update again in a moment.',
            lastSeenAt: DateTime.now(),
          ),
        );
        return false;
      }

      _emitState(
        sessionStateNow.copyWith(
          status: DoseBuddyConnectionStatus.attention,
          message: 'Could not update the dispenser. Reconnect and try again.',
        ),
      );
      return false;
    }
  }

  Future<void> startTutorialDemo() async {
    _lastKnownTutorialStepIndex = 0;
    await _sendTutorialCommand(
      type: 'start_demo',
      message: 'DoseBuddy tutorial is starting...',
      nextDemoState: _buildOptimisticTutorialState(_lastKnownTutorialStepIndex),
    );
  }

  Future<void> replayTutorialStep() async {
    await _sendTutorialCommand(
      type: 'demo_replay',
      message: 'DoseBuddy is replaying this tutorial step.',
      nextDemoState: _buildOptimisticTutorialState(_lastKnownTutorialStepIndex),
    );
  }

  Future<void> continueTutorialDemo() async {
    final lastIndex = _doseBuddyTutorialSteps.length - 1;
    if (_lastKnownTutorialStepIndex >= lastIndex) {
      _lastKnownTutorialStepIndex = 0;
      await _sendTutorialCommand(
        type: 'demo_next',
        message:
            'DoseBuddy tutorial finished. The device is back in normal mode.',
        nextDemoState: null,
      );
      return;
    }

    _lastKnownTutorialStepIndex++;
    await _sendTutorialCommand(
      type: 'demo_next',
      message: 'DoseBuddy tutorial is moving to the next mode.',
      nextDemoState: _buildOptimisticTutorialState(_lastKnownTutorialStepIndex),
    );
  }

  Future<void> stopTutorialDemo() async {
    _lastKnownTutorialStepIndex = 0;
    await _sendTutorialCommand(
      type: 'stop_demo',
      message: 'DoseBuddy tutorial is ending...',
      nextDemoState: null,
    );
  }

  Future<void> markDispenserRefilled() async {
    await _sendTutorialCommand(
      type: 'refill_dispenser',
      message: 'DoseBuddy dispenser refill is being confirmed...',
      nextDemoState: null,
    );
  }

  Future<void> triggerFeedbackTest() async {
    await startTutorialDemo();
  }

  Future<void> _sendTutorialCommand({
    required String type,
    required String message,
    Object? nextDemoState = _doseBuddyCopySentinel,
  }) async {
    final characteristic = _controlCharacteristic;
    if (characteristic == null) {
      _emitState(
        sessionStateNow.copyWith(
          status: DoseBuddyConnectionStatus.attention,
          message: 'Connect DoseBuddy before starting the tutorial demo.',
        ),
      );
      return;
    }

    _emitState(
      sessionStateNow.copyWith(
        status: DoseBuddyConnectionStatus.connected,
        message: message,
        lastSeenAt: DateTime.now(),
        demoState: nextDemoState,
      ),
    );

    final bytes = utf8.encode(jsonEncode({'type': type}));
    await _enqueueControlOperation(() async {
      await _writeControlPayload(characteristic, bytes);
    });
  }

  DoseBuddyDemoState _buildOptimisticTutorialState(int zeroBasedIndex) {
    final normalizedIndex = zeroBasedIndex.clamp(
      0,
      _doseBuddyTutorialSteps.length - 1,
    );
    final step = _doseBuddyTutorialSteps[normalizedIndex];

    return DoseBuddyDemoState(
      stepKey: step.stepKey,
      title: step.title,
      description: step.description,
      stepIndex: normalizedIndex + 1,
      totalSteps: _doseBuddyTutorialSteps.length,
      isRunning: true,
    );
  }

  Future<void> _enqueueControlOperation(Future<void> Function() action) async {
    final completer = Completer<void>();

    _controlOperationQueue = _controlOperationQueue.catchError((_) {}).then((
      _,
    ) async {
      try {
        await action();
        if (!completer.isCompleted) {
          completer.complete();
        }
      } catch (e, stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(e, stackTrace);
        }
      }
    });

    await completer.future;
  }

  Future<void> _writeControlPayload(
    BluetoothCharacteristic characteristic,
    List<int> bytes,
  ) async {
    final supportsWriteWithResponse = characteristic.properties.write;
    final withoutResponse =
        characteristic.properties.writeWithoutResponse &&
        !supportsWriteWithResponse;

    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        await characteristic.write(
          bytes,
          withoutResponse: withoutResponse,
          allowLongWrite: supportsWriteWithResponse,
        );
        return;
      } catch (e) {
        if (!_isRetryableControlWriteError(e) || attempt == 1) {
          rethrow;
        }
        await Future<void>.delayed(const Duration(milliseconds: 450));
      }
    }
  }

  bool _isRetryableControlWriteError(Object error) {
    final description = error.toString().toLowerCase();
    return description.contains('writecharacteristic') &&
        (description.contains('android code: 17') ||
            description.contains('gatt_insufficient_rescources') ||
            description.contains('gatt_insufficient_resources'));
  }

  void _scheduleSyncRetry() {
    if (_scheduledSyncRetry?.isActive ?? false) {
      return;
    }

    _scheduledSyncRetry = Timer(const Duration(seconds: 2), () {
      _scheduledSyncRetry = null;
      unawaited(syncConfiguration(scheduleRetryOnFailure: false));
    });
  }

  void _cancelScheduledSyncRetry() {
    _scheduledSyncRetry?.cancel();
    _scheduledSyncRetry = null;
  }

  Future<void> disconnect({bool showDisconnectedMessage = true}) async {
    final device = _activeDevice;

    await _eventSubscription?.cancel();
    await _connectionSubscription?.cancel();
    _eventSubscription = null;
    _connectionSubscription = null;
    _controlCharacteristic = null;
    _eventCharacteristic = null;
    _activeDevice = null;
    _activeRemoteId = null;
    _hasConnectedOnce = false;
    _didSyncForCurrentConnection = false;
    _lastSyncedConfigFingerprint = null;
    _eventMessageBuffer.clear();

    if (device != null) {
      try {
        await device.disconnect(queue: false);
      } catch (_) {}
    }

    if (showDisconnectedMessage) {
      _emitState(
        sessionStateNow.copyWith(
          status: DoseBuddyConnectionStatus.disconnected,
          message: _currentConfig == null
              ? 'Pair a DoseBuddy to get started.'
              : 'DoseBuddy is disconnected.',
        ),
      );
    }
  }

  Future<void> _handleAuthenticatedUserChanged(String? userId) async {
    await _deviceSubscription?.cancel();
    _deviceSubscription = null;
    _currentUserId = userId;
    _currentConfig = null;
    _didInitialReconnectForUser = false;

    if (userId == null) {
      await disconnect(showDisconnectedMessage: false);
      _emitState(
        const DoseBuddySessionState(
          status: DoseBuddyConnectionStatus.disconnected,
          message: 'Sign in to pair a DoseBuddy.',
        ),
      );
      return;
    }

    _deviceSubscription = _deviceDb.observePrimaryDevice(userId).listen((
      device,
    ) {
      unawaited(_handleDeviceConfigurationChanged(device));
    });
  }

  Future<void> _handleDeviceConfigurationChanged(
    DoseBuddyDevice? device,
  ) async {
    _currentConfig = device;

    if (device == null) {
      await disconnect(showDisconnectedMessage: false);
      _emitState(
        const DoseBuddySessionState(
          status: DoseBuddyConnectionStatus.disconnected,
          message: 'Pair a DoseBuddy to get started.',
        ),
      );
      return;
    }

    _emitState(
      sessionStateNow.copyWith(
        deviceId: device.bleDeviceId,
        deviceName: device.displayName,
      ),
    );

    if (_activeRemoteId != null && _activeRemoteId != device.bleDeviceId) {
      await disconnect(showDisconnectedMessage: false);
    }

    if (!_didInitialReconnectForUser && device.autoReconnectEnabled) {
      _didInitialReconnectForUser = true;
      await connectToConfiguredDevice(
        autoConnect: true,
        waitForConnection: false,
      );
      return;
    }

    if (_activeDevice != null && _activeDevice!.isConnected) {
      await syncConfiguration();
    }
  }

  Future<void> _connectToRemoteId({
    required String remoteId,
    required String displayName,
    required bool autoConnect,
    required bool waitForConnection,
  }) async {
    if (!await _ensureBluetoothReady()) {
      return;
    }

    if (_activeRemoteId == remoteId && _activeDevice != null) {
      if (sessionStateNow.status == DoseBuddyConnectionStatus.connecting ||
          sessionStateNow.status == DoseBuddyConnectionStatus.syncing) {
        return;
      }

      if (_activeDevice!.isConnected) {
        await syncConfiguration();
        return;
      }

      if (_activeDevice!.isAutoConnectEnabled && autoConnect) {
        return;
      }
    }

    if (_activeRemoteId != null && _activeRemoteId != remoteId) {
      await disconnect(showDisconnectedMessage: false);
    }

    final device = BluetoothDevice.fromId(remoteId);
    _activeDevice = device;
    _activeRemoteId = remoteId;
    _hasConnectedOnce = false;
    _didSyncForCurrentConnection = false;
    _lastSyncedConfigFingerprint = null;

    await _connectionSubscription?.cancel();
    _connectionSubscription = device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.connected) {
        _hasConnectedOnce = true;
        unawaited(_prepareConnectedDevice(device));
      } else if (state == BluetoothConnectionState.disconnected &&
          _hasConnectedOnce) {
        unawaited(_eventSubscription?.cancel() ?? Future.value());
        _eventSubscription = null;
        _controlCharacteristic = null;
        _eventCharacteristic = null;
        _didSyncForCurrentConnection = false;
        _lastSyncedConfigFingerprint = null;
        _emitState(
          sessionStateNow.copyWith(
            status: DoseBuddyConnectionStatus.disconnected,
            message: 'DoseBuddy connection was lost.',
          ),
        );
      }
    });

    _emitState(
      sessionStateNow.copyWith(
        status: DoseBuddyConnectionStatus.connecting,
        deviceId: remoteId,
        deviceName: displayName,
        message: autoConnect
            ? 'Trying to reconnect to DoseBuddy...'
            : 'Connecting to DoseBuddy...',
      ),
    );

    try {
      await device.connect(
        license: License.nonprofit,
        autoConnect: autoConnect,
        mtu: autoConnect ? null : 512,
      );

      if (waitForConnection && autoConnect) {
        await device.connectionState
            .where((value) => value == BluetoothConnectionState.connected)
            .first
            .timeout(const Duration(seconds: 12));
      }
    } catch (e) {
      _emitState(
        sessionStateNow.copyWith(
          status: DoseBuddyConnectionStatus.attention,
          message: 'DoseBuddy connection failed: $e',
        ),
      );
    }
  }

  Future<void> _prepareConnectedDevice(BluetoothDevice device) async {
    if (_isPreparingConnection) return;
    _isPreparingConnection = true;

    try {
      _emitState(
        sessionStateNow.copyWith(
          status: DoseBuddyConnectionStatus.syncing,
          message: 'Preparing DoseBuddy...',
        ),
      );

      if (!kIsWeb && Platform.isAndroid && device.mtuNow < 185) {
        await device.requestMtu(512);
      }

      final services = await device.discoverServices();
      final doseBuddyService = services.cast<BluetoothService?>().firstWhere(
        (service) => service?.uuid == Guid(DoseBuddyConstants.serviceUuid),
        orElse: () => null,
      );

      if (doseBuddyService == null) {
        throw StateError('DoseBuddy BLE service was not found.');
      }

      _controlCharacteristic = doseBuddyService.characteristics
          .cast<BluetoothCharacteristic?>()
          .firstWhere(
            (characteristic) =>
                characteristic?.uuid ==
                Guid(DoseBuddyConstants.controlCharacteristicUuid),
            orElse: () => null,
          );

      _eventCharacteristic = doseBuddyService.characteristics
          .cast<BluetoothCharacteristic?>()
          .firstWhere(
            (characteristic) =>
                characteristic?.uuid ==
                Guid(DoseBuddyConstants.eventCharacteristicUuid),
            orElse: () => null,
          );

      if (_controlCharacteristic == null || _eventCharacteristic == null) {
        throw StateError('DoseBuddy characteristics are missing.');
      }

      await _eventSubscription?.cancel();
      _eventSubscription = _eventCharacteristic!.onValueReceived.listen((
        value,
      ) {
        if (value.isEmpty) return;
        unawaited(_appendDeviceMessageChunk(value));
      });
      await _eventCharacteristic!.setNotifyValue(true);

      final syncSucceeded = await syncConfiguration();

      if (syncSucceeded) {
        _emitState(
          sessionStateNow.copyWith(
            status: DoseBuddyConnectionStatus.connected,
            message: 'DoseBuddy is connected and ready.',
            lastSeenAt: DateTime.now(),
          ),
        );
      } else if (sessionStateNow.status ==
          DoseBuddyConnectionStatus.connected) {
        _emitState(
          sessionStateNow.copyWith(
            status: DoseBuddyConnectionStatus.connected,
            lastSeenAt: DateTime.now(),
          ),
        );
      }
    } catch (e) {
      _emitState(
        sessionStateNow.copyWith(
          status: DoseBuddyConnectionStatus.attention,
          message: 'Could not prepare DoseBuddy: $e',
        ),
      );
    } finally {
      _isPreparingConnection = false;
    }
  }

  Future<void> _appendDeviceMessageChunk(List<int> value) async {
    _eventMessageBuffer.addAll(value);
    if (_eventMessageBuffer.length > 8192) {
      _eventMessageBuffer.clear();
      return;
    }

    Map<String, dynamic> message;
    try {
      final decoded = jsonDecode(utf8.decode(_eventMessageBuffer));
      message = Map<String, dynamic>.from(decoded as Map);
    } catch (_) {
      return;
    }

    _eventMessageBuffer.clear();

    final type = message['type'] as String?;
    final confirmedAt = _parseDateTime(message['confirmedAt']);
    final scheduledAt = _parseDateTime(message['scheduledAt']);
    final batteryLevel = _asInt(message['batteryLevel']);
    final remainingDoses = _asInt(message['remainingDoses']);
    final dispenserCapacity = _asInt(message['dispenserCapacity']);
    final refillNeeded = _asBool(message['refillNeeded']);
    final isDispenseWindowOpen = _asBool(message['dispenseWindowOpen']);

    switch (type) {
      case 'status':
        _lastKnownTutorialStepIndex = 0;
        _emitState(
          sessionStateNow.copyWith(
            status: DoseBuddyConnectionStatus.connected,
            message:
                (message['message'] as String?) ??
                'DoseBuddy sent a fresh status update.',
            batteryLevel: batteryLevel,
            remainingDoses: remainingDoses,
            dispenserCapacity: dispenserCapacity,
            nextDueAt: _parseDateTime(message['nextDueAt']),
            lastSeenAt: DateTime.now(),
            isAlarmActive: message['alarmActive'] == true,
            refillNeeded: refillNeeded ?? sessionStateNow.refillNeeded,
            isDispenseWindowOpen:
                isDispenseWindowOpen ?? sessionStateNow.isDispenseWindowOpen,
            demoState: null,
          ),
        );
        return;
      case 'demo_step':
        final title = (message['title'] as String?) ?? 'DoseBuddy tutorial';
        final description =
            (message['description'] as String?) ??
            'DoseBuddy is previewing what this state means.';
        final stepIndex = _asInt(message['index']) ?? 1;
        final totalSteps = _asInt(message['total']) ?? 1;
        _lastKnownTutorialStepIndex = (stepIndex - 1).clamp(
          0,
          _doseBuddyTutorialSteps.length - 1,
        );

        _emitState(
          sessionStateNow.copyWith(
            status: DoseBuddyConnectionStatus.connected,
            message:
                (message['message'] as String?) ??
                'DoseBuddy tutorial is running.',
            lastSeenAt: DateTime.now(),
            isAlarmActive: false,
            refillNeeded: refillNeeded ?? sessionStateNow.refillNeeded,
            isDispenseWindowOpen:
                isDispenseWindowOpen ?? sessionStateNow.isDispenseWindowOpen,
            demoState: DoseBuddyDemoState(
              stepKey: (message['stepKey'] as String?) ?? 'tutorial',
              title: title,
              description: description,
              stepIndex: stepIndex,
              totalSteps: totalSteps,
              isRunning: true,
            ),
          ),
        );
        return;
      case 'demo_finished':
        _lastKnownTutorialStepIndex = 0;
        _emitState(
          sessionStateNow.copyWith(
            status: DoseBuddyConnectionStatus.connected,
            message:
                (message['message'] as String?) ??
                'DoseBuddy tutorial finished. The device is back in normal mode.',
            lastSeenAt: DateTime.now(),
            isAlarmActive: false,
            refillNeeded: refillNeeded ?? sessionStateNow.refillNeeded,
            isDispenseWindowOpen:
                isDispenseWindowOpen ?? sessionStateNow.isDispenseWindowOpen,
            demoState: null,
          ),
        );
        return;
      case 'button_confirmed':
        await _recordConfirmation(
          feedbackType: 'confirmed',
          confirmedAt: confirmedAt ?? DateTime.now(),
          scheduledAt: scheduledAt,
          batteryLevel: batteryLevel,
          remainingDoses: remainingDoses,
          dispenserCapacity: dispenserCapacity,
          refillNeeded: refillNeeded,
          isDispenseWindowOpen: isDispenseWindowOpen,
        );
        return;
      case 'already_taken':
        _lastKnownTutorialStepIndex = 0;
        await _recordConfirmation(
          feedbackType: 'already_taken',
          confirmedAt: confirmedAt ?? DateTime.now(),
          scheduledAt: scheduledAt,
          batteryLevel: batteryLevel,
          remainingDoses: remainingDoses,
          dispenserCapacity: dispenserCapacity,
          refillNeeded: refillNeeded,
          isDispenseWindowOpen: isDispenseWindowOpen,
        );
        _emitState(
          sessionStateNow.copyWith(
            status: DoseBuddyConnectionStatus.connected,
            message: 'DoseBuddy reports this dose was already confirmed.',
            batteryLevel: batteryLevel,
            remainingDoses: remainingDoses,
            dispenserCapacity: dispenserCapacity,
            lastSeenAt: DateTime.now(),
            refillNeeded: refillNeeded ?? sessionStateNow.refillNeeded,
            isDispenseWindowOpen:
                isDispenseWindowOpen ?? sessionStateNow.isDispenseWindowOpen,
            demoState: null,
          ),
        );
        return;
      case 'missed_alert':
        _lastKnownTutorialStepIndex = 0;
        _emitState(
          sessionStateNow.copyWith(
            status: DoseBuddyConnectionStatus.attention,
            message: 'DoseBuddy needs attention for a missed interval.',
            batteryLevel: batteryLevel,
            remainingDoses: remainingDoses,
            dispenserCapacity: dispenserCapacity,
            lastSeenAt: DateTime.now(),
            isAlarmActive: true,
            refillNeeded: refillNeeded ?? sessionStateNow.refillNeeded,
            isDispenseWindowOpen:
                isDispenseWindowOpen ?? sessionStateNow.isDispenseWindowOpen,
            demoState: null,
          ),
        );
        return;
      case 'refill_needed':
        _lastKnownTutorialStepIndex = _doseBuddyTutorialSteps.length - 1;
        _emitState(
          sessionStateNow.copyWith(
            status: DoseBuddyConnectionStatus.attention,
            message:
                (message['message'] as String?) ??
                'DoseBuddy dispenser needs a refill.',
            batteryLevel: batteryLevel,
            remainingDoses: remainingDoses ?? 0,
            dispenserCapacity:
                dispenserCapacity ??
                DoseBuddyConstants.defaultDispenserCapacity,
            lastSeenAt: DateTime.now(),
            refillNeeded: true,
            isDispenseWindowOpen:
                isDispenseWindowOpen ?? sessionStateNow.isDispenseWindowOpen,
            demoState: null,
          ),
        );
        return;
      default:
        return;
    }
  }

  Future<void> _recordConfirmation({
    required String feedbackType,
    required DateTime confirmedAt,
    DateTime? scheduledAt,
    int? batteryLevel,
    int? remainingDoses,
    int? dispenserCapacity,
    bool? refillNeeded,
    bool? isDispenseWindowOpen,
  }) async {
    final userId = _currentUserId;
    final config = _currentConfig;
    if (userId == null || config == null) return;

    final medications = await _medicationDb.getUserMedications(userId);
    final assignedMedications = medications
        .where((medication) => config.medicationIds.contains(medication.id))
        .where((medication) => medication.isActive)
        .toList();

    final resolvedMedicationIds = <String>[];

    if (feedbackType == 'confirmed') {
      for (final medication in assignedMedications) {
        final resolvedSchedule = _resolveMedicationSchedule(
          medication,
          confirmedAt,
          scheduledAt,
          config.allowLateDispenseAfterMissedHour,
        );

        if (resolvedSchedule == null) continue;

        await _doseEventDb.recordDose(
          userId: userId,
          medicationId: medication.id,
          scheduledAt: resolvedSchedule,
          taken: true,
          takenAt: confirmedAt,
        );

        resolvedMedicationIds.add(medication.id);
      }
    }

    final resolvedInterval =
        scheduledAt ??
        _resolveManualInterval(
          config.manualIntervals,
          confirmedAt,
          config.allowLateDispenseAfterMissedHour,
        );
    final eventScheduledAt = resolvedInterval ?? confirmedAt;

    await _eventDb.upsertEvent(
      DoseBuddyEvent(
        id: _buildEventId(config.id, feedbackType, eventScheduledAt),
        userId: userId,
        deviceId: config.id,
        scheduledAt: eventScheduledAt,
        confirmedAt: confirmedAt,
        medicationIds: resolvedMedicationIds,
        feedbackType: feedbackType,
      ),
    );

    _emitState(
      sessionStateNow.copyWith(
        status: DoseBuddyConnectionStatus.connected,
        message: feedbackType == 'confirmed'
            ? 'DoseBuddy dispensed one dose.'
            : 'DoseBuddy says this interval was already confirmed.',
        batteryLevel: batteryLevel,
        remainingDoses: remainingDoses,
        dispenserCapacity: dispenserCapacity,
        lastConfirmedAt: confirmedAt,
        lastSeenAt: DateTime.now(),
        isAlarmActive: false,
        refillNeeded: refillNeeded ?? sessionStateNow.refillNeeded,
        isDispenseWindowOpen:
            isDispenseWindowOpen ?? sessionStateNow.isDispenseWindowOpen,
      ),
    );
  }

  DateTime? _resolveMedicationSchedule(
    Medication medication,
    DateTime confirmedAt,
    DateTime? preferredSchedule,
    bool allowLateDispenseAfterMissedHour,
  ) {
    final candidates = <DateTime>[];

    if (preferredSchedule != null &&
        _matchesMedicationSchedule(medication, preferredSchedule) &&
        _isWithinConfirmationWindow(
          preferredSchedule,
          confirmedAt,
          allowLateDispenseAfterMissedHour,
        )) {
      candidates.add(preferredSchedule);
    }

    final dayAnchor = DateTime(
      confirmedAt.year,
      confirmedAt.month,
      confirmedAt.day,
    );

    for (final offset in const [-1, 0, 1]) {
      final date = dayAnchor.add(Duration(days: offset));
      if (!medication.scheduleDays.contains(date.weekday)) continue;

      for (final time in medication.scheduleTimes) {
        final parts = time.split(':');
        if (parts.length != 2) continue;

        final hour = int.tryParse(parts[0]);
        final minute = int.tryParse(parts[1]);
        if (hour == null || minute == null) continue;

        final candidate = DateTime(
          date.year,
          date.month,
          date.day,
          hour,
          minute,
        );

        if (!_matchesMedicationSchedule(medication, candidate)) continue;
        if (!_isWithinConfirmationWindow(
          candidate,
          confirmedAt,
          allowLateDispenseAfterMissedHour,
        )) {
          continue;
        }

        candidates.add(candidate);
      }
    }

    if (candidates.isEmpty) return null;

    candidates.sort(
      (a, b) => confirmedAt
          .difference(a)
          .abs()
          .compareTo(confirmedAt.difference(b).abs()),
    );

    return candidates.first;
  }

  DateTime? _resolveManualInterval(
    List<String> manualIntervals,
    DateTime confirmedAt,
    bool allowLateDispenseAfterMissedHour,
  ) {
    if (manualIntervals.isEmpty) return null;

    final candidates = <DateTime>[];
    final dayAnchor = DateTime(
      confirmedAt.year,
      confirmedAt.month,
      confirmedAt.day,
    );

    for (final offset in const [-1, 0, 1]) {
      final date = dayAnchor.add(Duration(days: offset));
      for (final interval in manualIntervals) {
        final parts = interval.split(':');
        if (parts.length != 2) continue;

        final hour = int.tryParse(parts[0]);
        final minute = int.tryParse(parts[1]);
        if (hour == null || minute == null) continue;

        final candidate = DateTime(
          date.year,
          date.month,
          date.day,
          hour,
          minute,
        );

        if (_isWithinConfirmationWindow(
          candidate,
          confirmedAt,
          allowLateDispenseAfterMissedHour,
        )) {
          candidates.add(candidate);
        }
      }
    }

    if (candidates.isEmpty) return null;

    candidates.sort(
      (a, b) => confirmedAt
          .difference(a)
          .abs()
          .compareTo(confirmedAt.difference(b).abs()),
    );

    return candidates.first;
  }

  bool _matchesMedicationSchedule(Medication medication, DateTime candidate) {
    final startDate = DateTime(
      medication.startDate.year,
      medication.startDate.month,
      medication.startDate.day,
    );

    if (candidate.isBefore(startDate)) {
      return false;
    }

    if (medication.endDate != null) {
      final endDate = DateTime(
        medication.endDate!.year,
        medication.endDate!.month,
        medication.endDate!.day,
        23,
        59,
        59,
      );

      if (candidate.isAfter(endDate)) {
        return false;
      }
    }

    if (!medication.scheduleDays.contains(candidate.weekday)) {
      return false;
    }

    final time =
        '${candidate.hour.toString().padLeft(2, '0')}:${candidate.minute.toString().padLeft(2, '0')}';

    return medication.scheduleTimes.contains(time);
  }

  bool _isWithinConfirmationWindow(
    DateTime scheduledAt,
    DateTime confirmedAt,
    bool allowLateDispenseAfterMissedHour,
  ) {
    final earliest = scheduledAt.subtract(
      const Duration(minutes: DoseBuddyConstants.earlyConfirmationMinutes),
    );

    if (allowLateDispenseAfterMissedHour) {
      return !confirmedAt.isBefore(earliest);
    }

    final latest = scheduledAt.add(
      const Duration(minutes: DoseBuddyConstants.missedAlertGraceMinutes),
    );

    return !confirmedAt.isBefore(earliest) && !confirmedAt.isAfter(latest);
  }

  Future<bool> _ensureBluetoothReady() async {
    if (kIsWeb) {
      _emitState(
        const DoseBuddySessionState(
          status: DoseBuddyConnectionStatus.unsupported,
          message: 'DoseBuddy pairing is available in the Android app.',
        ),
      );
      return false;
    }

    if (!await FlutterBluePlus.isSupported) {
      _emitState(
        const DoseBuddySessionState(
          status: DoseBuddyConnectionStatus.unsupported,
          message: 'Bluetooth Low Energy is not supported on this device.',
        ),
      );
      return false;
    }

    final permissionsGranted = await _requestBluetoothPermissions();
    if (!permissionsGranted) {
      _emitState(
        sessionStateNow.copyWith(
          status: DoseBuddyConnectionStatus.attention,
          message:
              'DoseBuddy needs Bluetooth permissions to connect in the background.',
        ),
      );
      return false;
    }

    if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
      try {
        await FlutterBluePlus.turnOn();
      } catch (_) {}

      try {
        await FlutterBluePlus.adapterState
            .where((state) => state == BluetoothAdapterState.on)
            .first
            .timeout(const Duration(seconds: 6));
      } catch (_) {
        _emitState(
          sessionStateNow.copyWith(
            status: DoseBuddyConnectionStatus.bluetoothOff,
            message: 'Turn on Bluetooth to connect DoseBuddy.',
          ),
        );
        return false;
      }
    }

    return true;
  }

  Future<bool> _requestBluetoothPermissions() async {
    if (!Platform.isAndroid) return true;

    final permissions = <Permission>[
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      if (_requiresFineLocationForBleScan()) Permission.locationWhenInUse,
    ];

    final result = await permissions.request();

    return result.values.every((status) => status.isGranted);
  }

  bool _requiresFineLocationForBleScan() {
    if (!Platform.isAndroid) {
      return false;
    }

    final sdkMatch = RegExp(
      r'SDK\s+(\d+)',
    ).firstMatch(Platform.operatingSystemVersion);
    final sdkVersion = int.tryParse(sdkMatch?.group(1) ?? '');
    return sdkVersion != null && sdkVersion < 31;
  }

  String _androidSdkVersionLabel() {
    if (!Platform.isAndroid) {
      return 'n/a';
    }

    final sdkMatch = RegExp(
      r'SDK\s+(\d+)',
    ).firstMatch(Platform.operatingSystemVersion);
    return sdkMatch?.group(1) ?? 'unknown';
  }

  Future<bool?> _isLocationServiceEnabled() async {
    if (!Platform.isAndroid) {
      return null;
    }

    try {
      final serviceStatus = await Permission.locationWhenInUse.serviceStatus;
      return serviceStatus == ServiceStatus.enabled;
    } catch (_) {
      return null;
    }
  }

  String _buildNoDoseBuddyFoundMessage({
    required int rawDeviceCount,
    required bool? locationServiceEnabled,
  }) {
    if (locationServiceEnabled == false) {
      return 'Turn on system Location Services. Android BLE scan is blocked while they are off.';
    }

    if (rawDeviceCount == 0) {
      return 'No DoseBuddy found nearby. BLE scan saw 0 devices. This usually points to phone-side scan blocking or Android scan throttling.';
    }

    return 'No DoseBuddy found nearby. BLE scan saw $rawDeviceCount device(s), but none exposed the DoseBuddy name or service UUID.';
  }

  void _logScanDebug(String message) {
    debugPrint('[DoseBuddyScan] $message');
  }

  bool _shouldLogScanResult(ScanResult? previous, ScanResult current) {
    if (previous == null) {
      return true;
    }

    final previousData = previous.advertisementData;
    final currentData = current.advertisementData;
    return previous.rssi != current.rssi ||
        previousData.advName != currentData.advName ||
        previous.device.platformName != current.device.platformName ||
        previousData.connectable != currentData.connectable ||
        !_sameGuidList(previousData.serviceUuids, currentData.serviceUuids) ||
        !_sameGuidList(
          previousData.serviceData.keys,
          currentData.serviceData.keys,
        ) ||
        !_sameManufacturerKeys(
          previousData.manufacturerData.keys,
          currentData.manufacturerData.keys,
        );
  }

  bool _sameGuidList(Iterable<Guid> left, Iterable<Guid> right) {
    final leftList = left.map((guid) => guid.toString()).toList()..sort();
    final rightList = right.map((guid) => guid.toString()).toList()..sort();
    if (leftList.length != rightList.length) {
      return false;
    }

    for (var index = 0; index < leftList.length; index++) {
      if (leftList[index] != rightList[index]) {
        return false;
      }
    }

    return true;
  }

  bool _sameManufacturerKeys(Iterable<int> left, Iterable<int> right) {
    final leftList = left.toList()..sort();
    final rightList = right.toList()..sort();
    if (leftList.length != rightList.length) {
      return false;
    }

    for (var index = 0; index < leftList.length; index++) {
      if (leftList[index] != rightList[index]) {
        return false;
      }
    }

    return true;
  }

  String _formatScanResultForDebug(ScanResult result) {
    final advertisementData = result.advertisementData;
    final serviceUuids = advertisementData.serviceUuids
        .map((guid) => guid.toString())
        .join(',');
    final serviceDataKeys = advertisementData.serviceData.keys
        .map((guid) => guid.toString())
        .join(',');
    final manufacturerKeys = advertisementData.manufacturerData.keys
        .map((key) => '0x${key.toRadixString(16)}')
        .join(',');

    return 'id=${result.device.remoteId.str} '
        'advName="${advertisementData.advName}" '
        'platformName="${result.device.platformName}" '
        'rssi=${result.rssi} '
        'connectable=${advertisementData.connectable} '
        'serviceUuids=[$serviceUuids] '
        'serviceData=[$serviceDataKeys] '
        'manufacturerData=[$manufacturerKeys]';
  }

  void _handleAdapterStateChanged(BluetoothAdapterState state) {
    if (state == BluetoothAdapterState.on) {
      if (sessionStateNow.status == DoseBuddyConnectionStatus.bluetoothOff) {
        _emitState(
          sessionStateNow.copyWith(
            status: DoseBuddyConnectionStatus.disconnected,
            message: _currentConfig == null
                ? 'Pair a DoseBuddy to get started.'
                : 'DoseBuddy is ready to reconnect.',
          ),
        );
      }
      return;
    }

    if (state == BluetoothAdapterState.off ||
        state == BluetoothAdapterState.unauthorized) {
      _emitState(
        sessionStateNow.copyWith(
          status: DoseBuddyConnectionStatus.bluetoothOff,
          message: 'Turn on Bluetooth to connect DoseBuddy.',
        ),
      );
    }
  }

  Map<String, dynamic> _buildSyncPayload(
    DoseBuddyDevice device,
    List<Medication> medications,
  ) {
    return {
      'type': 'sync_config',
      'deviceName': device.displayName,
      'syncedAt': DateTime.now().toIso8601String(),
      'simpleMode': true,
      'earlyConfirmationMinutes': DoseBuddyConstants.earlyConfirmationMinutes,
      'lateConfirmationMinutes': DoseBuddyConstants.dispenserWindowMinutes,
      'dispenseWindowMinutes': DoseBuddyConstants.dispenserWindowMinutes,
      'dispenserCapacity': DoseBuddyConstants.maxDispenserCapacity,
      'allowLateDispenseAfterMissedHour':
          device.allowLateDispenseAfterMissedHour,
      'manualIntervals': device.manualIntervals,
      'medicationSlots': _buildMedicationSlots(medications),
    };
  }

  String _buildSyncFingerprint(
    DoseBuddyDevice device,
    List<Medication> medications,
  ) {
    return jsonEncode({
      'deviceName': device.displayName,
      'simpleMode': true,
      'earlyConfirmationMinutes': DoseBuddyConstants.earlyConfirmationMinutes,
      'lateConfirmationMinutes': DoseBuddyConstants.dispenserWindowMinutes,
      'dispenseWindowMinutes': DoseBuddyConstants.dispenserWindowMinutes,
      'dispenserCapacity': DoseBuddyConstants.maxDispenserCapacity,
      'allowLateDispenseAfterMissedHour':
          device.allowLateDispenseAfterMissedHour,
      'manualIntervals': _sortedUnique(device.manualIntervals),
      'medicationSlots': _buildMedicationSlots(medications),
    });
  }

  bool? _asBool(Object? value) {
    if (value is bool) {
      return value;
    }

    return null;
  }

  List<String> _buildMedicationSlots(List<Medication> medications) {
    final slots = <String>{};

    for (final medication in medications.where(
      (medication) => medication.isActive,
    )) {
      for (final weekday in medication.scheduleDays) {
        for (final time in medication.scheduleTimes) {
          slots.add('$weekday|$time');
        }
      }
    }

    final sortedSlots = slots.toList()..sort();
    return sortedSlots;
  }

  String _candidateName(ScanResult result) {
    final advertisedName = result.advertisementData.advName.trim();
    if (advertisedName.isNotEmpty) {
      return advertisedName;
    }

    final platformName = result.device.platformName.trim();
    if (platformName.isNotEmpty) {
      return platformName;
    }

    return result.device.remoteId.str;
  }

  bool _isDoseBuddyCandidate(ScanResult result) {
    final advertisedName = result.advertisementData.advName
        .trim()
        .toLowerCase();
    final platformName = result.device.platformName.trim().toLowerCase();
    final hasMatchingName =
        advertisedName.contains(
          DoseBuddyConstants.advertisedName.toLowerCase(),
        ) ||
        platformName.contains(DoseBuddyConstants.advertisedName.toLowerCase());
    final hasMatchingService = result.advertisementData.serviceUuids.any(
      (uuid) => uuid.toString().toLowerCase() == DoseBuddyConstants.serviceUuid,
    );

    return hasMatchingName || hasMatchingService;
  }

  List<String> _sortedUnique(List<String> values) {
    final unique = values.toSet().toList()..sort();
    return unique;
  }

  DateTime? _parseDateTime(dynamic raw) {
    if (raw is! String || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  int? _asInt(dynamic raw) {
    if (raw is int) return raw;
    return int.tryParse('$raw');
  }

  String _buildEventId(String deviceId, String feedbackType, DateTime slot) {
    return '${deviceId}_${feedbackType}_${slot.millisecondsSinceEpoch}';
  }

  void _emitState(DoseBuddySessionState nextState) {
    _sessionState.add(nextState);
    unawaited(_persistSessionState(nextState));
  }

  Future<void> _restoreSessionState() async {
    final prefs = await SharedPreferences.getInstance();
    final statusIndex = prefs.getInt(
      '${DoseBuddyConstants.prefsKeyPrefix}_status',
    );

    if (statusIndex == null) return;

    final status = DoseBuddyConnectionStatus.values[statusIndex];
    _sessionState.add(
      DoseBuddySessionState(
        status: status,
        deviceId: prefs.getString(
          '${DoseBuddyConstants.prefsKeyPrefix}_device_id',
        ),
        deviceName: prefs.getString(
          '${DoseBuddyConstants.prefsKeyPrefix}_device_name',
        ),
        message: prefs.getString(
          '${DoseBuddyConstants.prefsKeyPrefix}_message',
        ),
        batteryLevel: prefs.getInt(
          '${DoseBuddyConstants.prefsKeyPrefix}_battery',
        ),
        remainingDoses: prefs.getInt(
          '${DoseBuddyConstants.prefsKeyPrefix}_remaining_doses',
        ),
        dispenserCapacity: prefs.getInt(
          '${DoseBuddyConstants.prefsKeyPrefix}_dispenser_capacity',
        ),
        nextDueAt: _millisToDateTime(
          prefs.getInt('${DoseBuddyConstants.prefsKeyPrefix}_next_due'),
        ),
        lastSeenAt: _millisToDateTime(
          prefs.getInt('${DoseBuddyConstants.prefsKeyPrefix}_last_seen'),
        ),
        lastSyncAt: _millisToDateTime(
          prefs.getInt('${DoseBuddyConstants.prefsKeyPrefix}_last_sync'),
        ),
        lastConfirmedAt: _millisToDateTime(
          prefs.getInt('${DoseBuddyConstants.prefsKeyPrefix}_last_confirmed'),
        ),
        isAlarmActive:
            prefs.getBool('${DoseBuddyConstants.prefsKeyPrefix}_alarm') ??
            false,
        refillNeeded:
            prefs.getBool('${DoseBuddyConstants.prefsKeyPrefix}_refill') ??
            false,
        isDispenseWindowOpen:
            prefs.getBool('${DoseBuddyConstants.prefsKeyPrefix}_window_open') ??
            false,
      ),
    );
  }

  Future<void> _persistSessionState(DoseBuddySessionState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      '${DoseBuddyConstants.prefsKeyPrefix}_status',
      state.status.index,
    );

    await _setOrRemoveString(
      prefs,
      '${DoseBuddyConstants.prefsKeyPrefix}_device_id',
      state.deviceId,
    );
    await _setOrRemoveString(
      prefs,
      '${DoseBuddyConstants.prefsKeyPrefix}_device_name',
      state.deviceName,
    );
    await _setOrRemoveString(
      prefs,
      '${DoseBuddyConstants.prefsKeyPrefix}_message',
      state.message,
    );

    await _setOrRemoveInt(
      prefs,
      '${DoseBuddyConstants.prefsKeyPrefix}_battery',
      state.batteryLevel,
    );
    await _setOrRemoveInt(
      prefs,
      '${DoseBuddyConstants.prefsKeyPrefix}_remaining_doses',
      state.remainingDoses,
    );
    await _setOrRemoveInt(
      prefs,
      '${DoseBuddyConstants.prefsKeyPrefix}_dispenser_capacity',
      state.dispenserCapacity,
    );
    await _setOrRemoveInt(
      prefs,
      '${DoseBuddyConstants.prefsKeyPrefix}_next_due',
      state.nextDueAt?.millisecondsSinceEpoch,
    );
    await _setOrRemoveInt(
      prefs,
      '${DoseBuddyConstants.prefsKeyPrefix}_last_seen',
      state.lastSeenAt?.millisecondsSinceEpoch,
    );
    await _setOrRemoveInt(
      prefs,
      '${DoseBuddyConstants.prefsKeyPrefix}_last_sync',
      state.lastSyncAt?.millisecondsSinceEpoch,
    );
    await _setOrRemoveInt(
      prefs,
      '${DoseBuddyConstants.prefsKeyPrefix}_last_confirmed',
      state.lastConfirmedAt?.millisecondsSinceEpoch,
    );
    await prefs.setBool(
      '${DoseBuddyConstants.prefsKeyPrefix}_alarm',
      state.isAlarmActive,
    );
    await prefs.setBool(
      '${DoseBuddyConstants.prefsKeyPrefix}_refill',
      state.refillNeeded,
    );
    await prefs.setBool(
      '${DoseBuddyConstants.prefsKeyPrefix}_window_open',
      state.isDispenseWindowOpen,
    );
  }

  Future<void> _setOrRemoveString(
    SharedPreferences prefs,
    String key,
    String? value,
  ) {
    if (value == null || value.isEmpty) {
      return prefs.remove(key);
    }

    return prefs.setString(key, value);
  }

  Future<void> _setOrRemoveInt(
    SharedPreferences prefs,
    String key,
    int? value,
  ) {
    if (value == null) {
      return prefs.remove(key);
    }

    return prefs.setInt(key, value);
  }

  DateTime? _millisToDateTime(int? value) {
    if (value == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
}
