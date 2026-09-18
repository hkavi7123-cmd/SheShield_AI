import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'ai_guardian_service.dart';

/// Detected transport context states.
enum TransportState {
  stationary("Stationary", "User is stationary or walking (< 7 km/h)"),
  travelling(
    "Travelling",
    "Active moving transit detected (Auto / Bike / Car / Bus / Train)",
  ),
  possibleTransport(
    "Possible Transport",
    "Low speed vehicle transit or heavy traffic (7-12 km/h)",
  ),
  unknown("Calibrating", "Acquiring transit baseline");

  final String label;
  final String detail;

  const TransportState(this.label, this.detail);
}

/// Overall safety state evaluated specifically for transit scenarios.
enum TransportSafetyState {
  safe(
    label: "SAFE",
    emoji: "🟢",
    description:
    "Normal travelling movement and road vibrations verified safe.",
  ),
  attention(
    label: "ATTENTION",
    emoji: "🟡",
    description: "Unexpected travel route detected. Monitoring continues.",
  ),
  potentialEmergency(
    label: "POTENTIAL EMERGENCY",
    emoji: "🟠",
    description: "Multiple unusual safety signals detected.",
  );

  final String label;
  final String emoji;
  final String description;

  const TransportSafetyState({
    required this.label,
    required this.emoji,
    required this.description,
  });
}

/// Route progression behavior states.
enum RouteBehaviour {
  normal(
    "Normal Route",
    "Transit path is consistent with normal travel",
  ),
  unexpected(
    "Unexpected Route",
    "Significant route departure or unusual travel deviation",
  ),
  unknown(
    "Establishing Baseline",
    "Acquiring GPS travel trajectory",
  );

  final String label;
  final String detail;

  const RouteBehaviour(this.label, this.detail);
}

/// Immutable snapshot representing live Transport Detection telemetry.
class TransportDetectionSnapshot {
  final bool isMonitoring;
  final TransportState transportState;
  final TransportSafetyState safetyState;
  final RouteBehaviour routeBehaviour;
  final double currentSpeedKmh;
  final double movementIntensity;
  final bool isRoadVibrationFiltered;
  final bool isVoiceEmergency;
  final String? voiceSpokenWords;
  final String decisionReason;
  final DateTime lastUpdated;

  const TransportDetectionSnapshot({
    required this.isMonitoring,
    required this.transportState,
    required this.safetyState,
    required this.routeBehaviour,
    required this.currentSpeedKmh,
    required this.movementIntensity,
    required this.isRoadVibrationFiltered,
    required this.isVoiceEmergency,
    this.voiceSpokenWords,
    required this.decisionReason,
    required this.lastUpdated,
  });

  factory TransportDetectionSnapshot.initial() {
    return TransportDetectionSnapshot(
      isMonitoring: false,
      transportState: TransportState.unknown,
      safetyState: TransportSafetyState.safe,
      routeBehaviour: RouteBehaviour.unknown,
      currentSpeedKmh: 0.0,
      movementIntensity: 0.0,
      isRoadVibrationFiltered: false,
      isVoiceEmergency: false,
      voiceSpokenWords: null,
      decisionReason:
      "Transport monitoring is inactive. Tap 'Start Transport Monitoring' to begin.",
      lastUpdated: DateTime.now(),
    );
  }

  TransportDetectionSnapshot copyWith({
    bool? isMonitoring,
    TransportState? transportState,
    TransportSafetyState? safetyState,
    RouteBehaviour? routeBehaviour,
    double? currentSpeedKmh,
    double? movementIntensity,
    bool? isRoadVibrationFiltered,
    bool? isVoiceEmergency,
    String? voiceSpokenWords,
    String? decisionReason,
    DateTime? lastUpdated,
  }) {
    return TransportDetectionSnapshot(
      isMonitoring: isMonitoring ?? this.isMonitoring,
      transportState: transportState ?? this.transportState,
      safetyState: safetyState ?? this.safetyState,
      routeBehaviour: routeBehaviour ?? this.routeBehaviour,
      currentSpeedKmh: currentSpeedKmh ?? this.currentSpeedKmh,
      movementIntensity: movementIntensity ?? this.movementIntensity,
      isRoadVibrationFiltered:
      isRoadVibrationFiltered ?? this.isRoadVibrationFiltered,
      isVoiceEmergency: isVoiceEmergency ?? this.isVoiceEmergency,
      voiceSpokenWords: voiceSpokenWords ?? this.voiceSpokenWords,
      decisionReason: decisionReason ?? this.decisionReason,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

/// Service responsible ONLY for transport-context detection and transit safety
/// filtering.
///
/// Core Flow:
/// GPS + Movement Pattern
///        ↓
/// Detect Transport Context
///        ↓
/// Check Route Behaviour
///        ↓
/// Check Existing Voice Signal
///        ↓
/// Check Existing Movement Signal
///        ↓
/// Safety Decision
class TransportDetectionService extends ChangeNotifier {
  static final TransportDetectionService instance =
  TransportDetectionService._internal();

  TransportDetectionService._internal();

  TransportDetectionSnapshot _snapshot =
  TransportDetectionSnapshot.initial();

  TransportDetectionSnapshot get snapshot => _snapshot;

  final StreamController<TransportDetectionSnapshot> _streamController =
  StreamController<TransportDetectionSnapshot>.broadcast();

  Stream<TransportDetectionSnapshot> get stream => _streamController.stream;

  StreamSubscription<AIGuardianSnapshot>? _guardianSub;

  // Manual / Injected route simulation flag.
  RouteBehaviour _simulatedRouteBehaviour = RouteBehaviour.normal;

  // Prevent multiple post-frame notifications from being queued
  // at the same time.
  bool _notificationScheduled = false;

  bool _isDisposed = false;

  // ===========================================================================
  // MONITORING CONTROL
  // ===========================================================================

  void startMonitoring() {
    if (_isDisposed) return;

    if (_snapshot.isMonitoring) {
      return;
    }

    _simulatedRouteBehaviour = RouteBehaviour.normal;

    _snapshot = _snapshot.copyWith(
      isMonitoring: true,
      safetyState: TransportSafetyState.safe,
      transportState: TransportState.unknown,
      routeBehaviour: RouteBehaviour.normal,
      decisionReason:
      "Transport monitoring active. Road vibrations are filtered from false alarms.",
      lastUpdated: DateTime.now(),
    );

    _listenToAIGuardianTelemetry();

    // IMPORTANT:
    // Do not immediately evaluate the Guardian snapshot while Flutter
    // is still building the Transport Detection screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isDisposed) return;
      if (!_snapshot.isMonitoring) return;

      _evaluateFromGuardianSnapshot(
        AIGuardianService.instance.snapshot,
      );
    });

    _notify();
  }

  void stopMonitoring() {
    if (_isDisposed) return;

    _guardianSub?.cancel();
    _guardianSub = null;

    _snapshot = _snapshot.copyWith(
      isMonitoring: false,
      transportState: TransportState.unknown,
      safetyState: TransportSafetyState.safe,
      routeBehaviour: RouteBehaviour.unknown,
      isRoadVibrationFiltered: false,
      isVoiceEmergency: false,
      voiceSpokenWords: null,
      decisionReason: "Transport monitoring is inactive.",
      lastUpdated: DateTime.now(),
    );

    _notify();
  }

  // ===========================================================================
  // SIGNAL INGESTION & PIPELINE EVALUATION
  // ===========================================================================

  void _listenToAIGuardianTelemetry() {
    _guardianSub?.cancel();

    _guardianSub = AIGuardianService.instance.stream.listen(
          (guardianSnap) {
        if (_isDisposed) return;
        if (!_snapshot.isMonitoring) return;

        // Always evaluate after the current Flutter frame.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_isDisposed) return;
          if (!_snapshot.isMonitoring) return;

          _evaluateFromGuardianSnapshot(guardianSnap);
        });
      },
      onError: (error) {
        debugPrint(
          "TransportDetectionService Guardian stream error: $error",
        );
      },
    );
  }

  void _evaluateFromGuardianSnapshot(AIGuardianSnapshot gSnap) {
    if (_isDisposed) return;
    if (!_snapshot.isMonitoring) return;

    final speedKmh = gSnap.currentSpeedKmh;
    final movementIntensity = gSnap.movementIntensity;

    final isVoiceEmergency =
        gSnap.voiceState == VoiceSignalState.keywordDetected;

    final isUnusualMovement =
        gSnap.movementState == MovementSignalState.abnormal;

    // -------------------------------------------------------------------------
    // 1. Determine Transport Context
    // -------------------------------------------------------------------------

    TransportState evaluatedTransport;

    if (speedKmh >= 12.0) {
      evaluatedTransport = TransportState.travelling;
    } else if (speedKmh >= 7.0) {
      evaluatedTransport = TransportState.possibleTransport;
    } else {
      evaluatedTransport = TransportState.stationary;
    }

    // -------------------------------------------------------------------------
    // 2. Evaluate Route Behaviour
    // -------------------------------------------------------------------------

    RouteBehaviour evaluatedRoute = _simulatedRouteBehaviour;

    if (gSnap.routeState == RouteSignalState.unusual) {
      evaluatedRoute = RouteBehaviour.unexpected;
    }

    // -------------------------------------------------------------------------
    // 3. Road Vibration Filter
    // -------------------------------------------------------------------------

    final bool isVibrationFiltered =
        evaluatedTransport == TransportState.travelling &&
            movementIntensity > 3.0;

    // -------------------------------------------------------------------------
    // 4. Transparent Multi-Signal Decision
    // -------------------------------------------------------------------------

    final decisionResult = _evaluateTransitSafetyDecision(
      transport: evaluatedTransport,
      route: evaluatedRoute,
      isVoiceEmergency: isVoiceEmergency,
      isUnusualMovement: isUnusualMovement,
      speedKmh: speedKmh,
      movementIntensity: movementIntensity,
    );

    _snapshot = _snapshot.copyWith(
      transportState: evaluatedTransport,
      routeBehaviour: evaluatedRoute,
      currentSpeedKmh: speedKmh,
      movementIntensity: movementIntensity,
      isRoadVibrationFiltered: isVibrationFiltered,
      isVoiceEmergency: isVoiceEmergency,
      voiceSpokenWords: gSnap.lastSpokenWords,
      safetyState: decisionResult.state,
      decisionReason: decisionResult.reason,
      lastUpdated: DateTime.now(),
    );

    // -------------------------------------------------------------------------
    // 5. Forward Transport Signal to central AI Guardian
    // -------------------------------------------------------------------------

    // IMPORTANT:
    // This must happen AFTER the current Flutter frame.
    // Otherwise AIGuardianService.notifyListeners() can execute while
    // TransportDetectionScreen is being built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isDisposed) return;
      if (!_snapshot.isMonitoring) return;

      _forwardToAIGuardian(evaluatedRoute);
    });

    _notify();
  }

  // ===========================================================================
  // SAFETY DECISION ENGINE
  // ===========================================================================

  /// Transparent Safety Decision Formulation.
  ({
  TransportSafetyState state,
  String reason,
  }) _evaluateTransitSafetyDecision({
    required TransportState transport,
    required RouteBehaviour route,
    required bool isVoiceEmergency,
    required bool isUnusualMovement,
    required double speedKmh,
    required double movementIntensity,
  }) {
    // CASE 5:
    // Unexpected route + emergency voice signal + unusual movement
    // -> POTENTIAL EMERGENCY

    if (route == RouteBehaviour.unexpected &&
        isVoiceEmergency &&
        isUnusualMovement) {
      return (
      state: TransportSafetyState.potentialEmergency,
      reason:
      "Multiple unusual safety signals detected (Unexpected travel route + Abnormal motion + Emergency voice keyword)!",
      );
    }

    // CASE 4:
    // Unexpected route + unusual movement
    // -> ATTENTION

    if (route == RouteBehaviour.unexpected && isUnusualMovement) {
      return (
      state: TransportSafetyState.attention,
      reason:
      "Unexpected travel route combined with sudden high-force motion observed. Evaluating surroundings.",
      );
    }

    // CASE 3:
    // Unexpected route alone
    // -> ATTENTION

    if (route == RouteBehaviour.unexpected) {
      return (
      state: TransportSafetyState.attention,
      reason:
      "Unexpected travel route detected. Monitoring continues.",
      );
    }

    // CASE 2:
    // Normal travelling + road vibration / vehicle movement
    // -> SAFE

    if (transport == TransportState.travelling) {
      return (
      state: TransportSafetyState.safe,
      reason:
      "Normal travelling (${speedKmh.toStringAsFixed(0)} km/h). Road vibrations and transit motion are filtered from false alarms.",
      );
    }

    // CASE 1:
    // Stationary or normal baseline
    // -> SAFE

    return (
    state: TransportSafetyState.safe,
    reason:
    "Normal travel baseline. All route and motion indicators are safe.",
    );
  }

  // ===========================================================================
  // SIMULATION / TEST
  // ===========================================================================

  /// Manual injection / test toggle for simulated route behavior.
  void setSimulatedRouteBehaviour(RouteBehaviour behaviour) {
    if (_isDisposed) return;

    _simulatedRouteBehaviour = behaviour;

    // Avoid synchronous state changes during widget build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isDisposed) return;
      if (!_snapshot.isMonitoring) return;

      _evaluateFromGuardianSnapshot(
        AIGuardianService.instance.snapshot,
      );
    });
  }

  // ===========================================================================
  // CENTRAL AI GUARDIAN COMMUNICATION
  // ===========================================================================

  /// Forwards route behavior to central AI Guardian.
  void _forwardToAIGuardian(RouteBehaviour route) {
    if (_isDisposed) return;
    if (!_snapshot.isMonitoring) return;

    RouteSignalState guardianRoute;

    switch (route) {
      case RouteBehaviour.normal:
        guardianRoute = RouteSignalState.normal;
        break;

      case RouteBehaviour.unexpected:
        guardianRoute = RouteSignalState.unusual;
        break;

      case RouteBehaviour.unknown:
        guardianRoute = RouteSignalState.unknown;
        break;
    }

    try {
      AIGuardianService.instance.updateRouteSignal(
        guardianRoute,
        reason: _snapshot.decisionReason,
      );
    } catch (e) {
      debugPrint(
        "TransportDetectionService → AIGuardian error: $e",
      );
    }
  }

  // ===========================================================================
  // SAFE NOTIFICATION
  // ===========================================================================

  void _notify() {
    if (_isDisposed) return;

    // Do not call notifyListeners() directly while a widget may be building.
    if (_notificationScheduled) {
      return;
    }

    _notificationScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notificationScheduled = false;

      if (_isDisposed) return;

      try {
        if (!_streamController.isClosed) {
          _streamController.add(_snapshot);
        }

        notifyListeners();
      } catch (e) {
        debugPrint(
          "TransportDetectionService notification error: $e",
        );
      }
    });
  }

  // ===========================================================================
  // DISPOSE
  // ===========================================================================

  @override
  void dispose() {
    if (_isDisposed) return;

    _isDisposed = true;

    _guardianSub?.cancel();
    _guardianSub = null;

    if (!_streamController.isClosed) {
      _streamController.close();
    }

    super.dispose();
  }
}