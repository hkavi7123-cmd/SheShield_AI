import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'ai_risk_engine.dart';

/// Overall safety states determined by the AI Guardian multi-signal engine.
enum GuardianState {
  protectionInactive(
    label: "Protection Inactive",
    emoji: "⚪",
    description: "AI Guardian monitoring is currently paused.",
  ),
  safe(
    label: "Safe",
    emoji: "🟢",
    description: "All incoming safety signals are normal and verified.",
  ),
  attention(
    label: "Attention",
    emoji: "🟡",
    description: "Single caution signal observed. Evaluating context.",
  ),
  potentialEmergency(
    label: "Potential Emergency",
    emoji: "🟠",
    description: "Multiple correlated warning signals detected.",
  ),
  emergency(
    label: "Emergency",
    emoji: "🔴",
    description:
    "High-severity emergency signal confirmed. Immediate response ready.",
  ),
  protectionInterrupted(
    label: "Protection Interrupted",
    emoji: "⚠️",
    description:
    "Monitoring feed or sensor heartbeat was temporarily interrupted.",
  );

  final String label;
  final String emoji;
  final String description;

  const GuardianState({
    required this.label,
    required this.emoji,
    required this.description,
  });
}

/// Voice detection signal states.
enum VoiceSignalState {
  normal("Normal", "No emergency phrases"),
  listening("Listening", "Voice detection active"),
  keywordDetected(
    "Emergency Word Detected",
    "Detected 'Help' / 'SOS' / 'Emergency'",
  );

  final String label;
  final String detail;

  const VoiceSignalState(this.label, this.detail);
}

/// Movement signal states.
enum MovementSignalState {
  normal("Normal", "Device is stable or resting"),
  light("Light Movement", "Gentle handling / motion"),
  high("High Movement", "Fast physical movement / running"),
  abnormal(
    "Abnormal Movement",
    "Violent sudden acceleration / multi-spike motion",
  );

  final String label;
  final String detail;

  const MovementSignalState(this.label, this.detail);
}

/// GPS & Location signal states.
enum LocationSignalState {
  active("Active", "GPS coordinates streaming accurately"),
  searching("Searching", "Acquiring GPS fix..."),
  permissionDenied("Permission Denied", "Location access disabled"),
  unavailable("Unavailable", "GPS hardware unreachable");

  final String label;
  final String detail;

  const LocationSignalState(this.label, this.detail);
}

/// Travel & Route behaviour states.
enum RouteSignalState {
  normal("Normal Route", "Expected route & pace"),
  unusual("Unusual Deviation", "Sudden route or speed anomaly"),
  stationary("Stationary", "User is stationary"),
  unknown("Calibrating", "Establishing baseline");

  final String label;
  final String detail;

  const RouteSignalState(this.label, this.detail);
}

/// User manual action signals.
enum UserActionSignalState {
  none,
  manualSosTriggered,
  manualSosCancelled,
  safeConfirmed,
}

/// Network connectivity states.
enum NetworkSignalState {
  connected("Connected", "Internet connection active"),
  disconnected("Offline", "No cellular / Wi-Fi connection"),
  weak("Weak Signal", "Unstable network connection");

  final String label;
  final String detail;

  const NetworkSignalState(this.label, this.detail);
}

/// Battery health states.
enum BatterySignalState {
  good("Good", "Battery > 50%"),
  normal("Normal", "Battery 20% - 50%"),
  low("Low Battery", "Battery < 20% (System info only)"),
  charging("Charging", "Device plugged into power"),
  unknown("Available", "Battery operating normally");

  final String label;
  final String detail;

  const BatterySignalState(this.label, this.detail);
}

/// Immutable snapshot representing the entire AI Guardian safety telemetry.
class AIGuardianSnapshot {
  final GuardianState state;
  final bool isProtectionActive;
  final DateTime lastHeartbeat;
  final DateTime lastDecisionTime;
  final String decisionReason;

  // ---------------------------------------------------------------------------
  // AI RISK SCORE
  // ---------------------------------------------------------------------------

  final int riskScore;
  final RiskLevel riskLevel;

  // ---------------------------------------------------------------------------
  // SIGNAL TELEMETRY
  // ---------------------------------------------------------------------------

  final VoiceSignalState voiceState;
  final String? lastSpokenWords;

  final MovementSignalState movementState;
  final double movementIntensity;

  final LocationSignalState locationState;
  final double? latitude;
  final double? longitude;
  final String? currentAddress;

  final RouteSignalState routeState;
  final double currentSpeedKmh;

  final NetworkSignalState networkState;
  final BatterySignalState batteryState;

  final UserActionSignalState userActionState;
  final int emergencySpikeCount;

  const AIGuardianSnapshot({
    required this.state,
    required this.isProtectionActive,
    required this.lastHeartbeat,
    required this.lastDecisionTime,
    required this.decisionReason,

    required this.riskScore,
    required this.riskLevel,

    required this.voiceState,
    this.lastSpokenWords,
    required this.movementState,
    required this.movementIntensity,
    required this.locationState,
    this.latitude,
    this.longitude,
    this.currentAddress,
    required this.routeState,
    required this.currentSpeedKmh,
    required this.networkState,
    required this.batteryState,
    required this.userActionState,
    required this.emergencySpikeCount,
  });

  factory AIGuardianSnapshot.initial() {
    final now = DateTime.now();

    return AIGuardianSnapshot(
      state: GuardianState.protectionInactive,
      isProtectionActive: false,
      lastHeartbeat: now,
      lastDecisionTime: now,
      decisionReason: "Protection is currently inactive.",

      riskScore: 0,
      riskLevel: RiskLevel.safe,

      voiceState: VoiceSignalState.normal,
      lastSpokenWords: null,

      movementState: MovementSignalState.normal,
      movementIntensity: 0.0,

      locationState: LocationSignalState.searching,
      latitude: null,
      longitude: null,
      currentAddress: "Location pending...",

      routeState: RouteSignalState.unknown,
      currentSpeedKmh: 0.0,

      networkState: NetworkSignalState.connected,
      batteryState: BatterySignalState.good,

      userActionState: UserActionSignalState.none,
      emergencySpikeCount: 0,
    );
  }

  AIGuardianSnapshot copyWith({
    GuardianState? state,
    bool? isProtectionActive,
    DateTime? lastHeartbeat,
    DateTime? lastDecisionTime,
    String? decisionReason,

    int? riskScore,
    RiskLevel? riskLevel,

    VoiceSignalState? voiceState,
    String? lastSpokenWords,

    MovementSignalState? movementState,
    double? movementIntensity,

    LocationSignalState? locationState,
    double? latitude,
    double? longitude,
    String? currentAddress,

    RouteSignalState? routeState,
    double? currentSpeedKmh,

    NetworkSignalState? networkState,
    BatterySignalState? batteryState,

    UserActionSignalState? userActionState,
    int? emergencySpikeCount,
  }) {
    return AIGuardianSnapshot(
      state: state ?? this.state,
      isProtectionActive:
      isProtectionActive ?? this.isProtectionActive,
      lastHeartbeat:
      lastHeartbeat ?? this.lastHeartbeat,
      lastDecisionTime:
      lastDecisionTime ?? this.lastDecisionTime,
      decisionReason:
      decisionReason ?? this.decisionReason,

      riskScore:
      riskScore ?? this.riskScore,
      riskLevel:
      riskLevel ?? this.riskLevel,

      voiceState:
      voiceState ?? this.voiceState,
      lastSpokenWords:
      lastSpokenWords ?? this.lastSpokenWords,

      movementState:
      movementState ?? this.movementState,
      movementIntensity:
      movementIntensity ?? this.movementIntensity,

      locationState:
      locationState ?? this.locationState,
      latitude:
      latitude ?? this.latitude,
      longitude:
      longitude ?? this.longitude,
      currentAddress:
      currentAddress ?? this.currentAddress,

      routeState:
      routeState ?? this.routeState,
      currentSpeedKmh:
      currentSpeedKmh ?? this.currentSpeedKmh,

      networkState:
      networkState ?? this.networkState,
      batteryState:
      batteryState ?? this.batteryState,

      userActionState:
      userActionState ?? this.userActionState,
      emergencySpikeCount:
      emergencySpikeCount ?? this.emergencySpikeCount,
    );
  }

  /// Converts the safety telemetry to a clean Firestore map.
  Map<String, dynamic> toFirestoreMap(String userId) {
    return {
      'userId': userId,

      'protectionStatus':
      isProtectionActive ? 'ACTIVE' : 'INACTIVE',

      'guardianState':
      state.name,

      // AI Risk Score
      'riskScore':
      riskScore,

      'riskLevel':
      riskLevel.name,

      'lastHeartbeat':
      Timestamp.fromDate(lastHeartbeat),

      'decisionReason':
      decisionReason,

      'lastKnownLocation': {
        'latitude': latitude,
        'longitude': longitude,
        'address': currentAddress,
        'speedKmh': currentSpeedKmh,
      },

      'voiceStatus':
      voiceState.name,

      'lastSpokenWords':
      lastSpokenWords,

      'movementStatus':
      movementState.name,

      'movementIntensity':
      movementIntensity,

      'routeStatus':
      routeState.name,

      'networkStatus':
      networkState.name,

      'batteryStatus':
      batteryState.name,

      'updatedAt':
      FieldValue.serverTimestamp(),
    };
  }
}

/// Central Singleton Service managing the AI Guardian Multi-Signal Decision Engine.
class AIGuardianService extends ChangeNotifier {
  // ===========================================================================
  // SINGLETON
  // ===========================================================================

  static final AIGuardianService instance =
  AIGuardianService._internal();

  AIGuardianService._internal();

  // ===========================================================================
  // INTERNAL STATE
  // ===========================================================================

  AIGuardianSnapshot _snapshot =
  AIGuardianSnapshot.initial();

  AIGuardianSnapshot get snapshot =>
      _snapshot;

  final StreamController<AIGuardianSnapshot>
  _streamController =
  StreamController<AIGuardianSnapshot>.broadcast();

  Stream<AIGuardianSnapshot> get stream =>
      _streamController.stream;

  // ===========================================================================
  // AI RISK ENGINE
  // ===========================================================================

  final AIRiskEngine _riskEngine =
      AIRiskEngine.instance;

  // ===========================================================================
  // BACKGROUND TIMERS & SUBSCRIPTIONS
  // ===========================================================================

  Timer? _heartbeatTimer;
  Timer? _deescalationTimer;

  StreamSubscription<Position>?
  _positionSubscription;

  StreamSubscription<UserAccelerometerEvent>?
  _sensorSubscription;

  DateTime _lastVoiceKeywordTimestamp =
  DateTime.fromMillisecondsSinceEpoch(0);

  DateTime _lastAbnormalMovementTimestamp =
  DateTime.fromMillisecondsSinceEpoch(0);

  // ===========================================================================
  // CONFIGURATION
  // ===========================================================================

  static const int _voiceWindowSeconds = 12;

  static const int _movementWindowSeconds = 8;

  static const int _heartbeatIntervalSeconds = 3;

  static const int _heartbeatTimeoutThresholdSeconds = 14;

  // ===========================================================================
  // PROTECTION LIFECYCLE
  // ===========================================================================

  /// Activates AI Guardian Protection Mode.
  Future<void> startProtection() async {
    if (_snapshot.isProtectionActive) return;

    final now = DateTime.now();

    _riskEngine.resetRisk(
      notify: false,
    );

    _snapshot = _snapshot.copyWith(
      isProtectionActive: true,
      lastHeartbeat: now,
      lastDecisionTime: now,

      state: GuardianState.safe,

      decisionReason:
      "Protection initialized. Signals verified safe.",

      riskScore: 0,
      riskLevel: RiskLevel.safe,

      userActionState:
      UserActionSignalState.none,
    );

    _startHeartbeatTimer();

    _startLocationTelemetry();

    _startSensorTelemetry();

    _notify();

    _syncToFirestore();

    if (kDebugMode) {
      print(
        "🛡️ AI Guardian: Protection started successfully.",
      );
    }
  }

  /// Deactivates AI Guardian Protection Mode.
  void stopProtection() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    _deescalationTimer?.cancel();
    _deescalationTimer = null;

    _positionSubscription?.cancel();
    _positionSubscription = null;

    _sensorSubscription?.cancel();
    _sensorSubscription = null;

    _riskEngine.resetRisk(
      notify: false,
    );

    final now = DateTime.now();

    _snapshot = _snapshot.copyWith(
      isProtectionActive: false,

      state:
      GuardianState.protectionInactive,

      lastHeartbeat: now,

      lastDecisionTime: now,

      decisionReason:
      "Protection stopped by user.",

      riskScore: 0,

      riskLevel:
      RiskLevel.safe,

      userActionState:
      UserActionSignalState.none,

      voiceState:
      VoiceSignalState.normal,

      movementState:
      MovementSignalState.normal,

      movementIntensity:
      0.0,

      currentSpeedKmh:
      0.0,
    );

    _notify();

    _syncToFirestore();

    if (kDebugMode) {
      print(
        "🛡️ AI Guardian: Protection stopped.",
      );
    }
  }

  // ===========================================================================
  // HEARTBEAT
  // ===========================================================================

  void _startHeartbeatTimer() {
    _heartbeatTimer?.cancel();

    _heartbeatTimer = Timer.periodic(
      const Duration(
        seconds: _heartbeatIntervalSeconds,
      ),
          (timer) {
        _tickHeartbeat();
      },
    );
  }

  void _tickHeartbeat() {
    if (!_snapshot.isProtectionActive) {
      return;
    }

    final now = DateTime.now();

    final secondsSinceHeartbeat =
        now
            .difference(
          _snapshot.lastHeartbeat,
        )
            .inSeconds;

    if (secondsSinceHeartbeat >
        _heartbeatTimeoutThresholdSeconds &&
        _snapshot.state !=
            GuardianState.emergency) {
      _snapshot = _snapshot.copyWith(
        state:
        GuardianState.protectionInterrupted,

        decisionReason:
        "Monitoring heartbeat signal lost ($secondsSinceHeartbeat s ago).",
      );

      _notify();

      return;
    }

    _snapshot =
        _snapshot.copyWith(
          lastHeartbeat: now,
        );

    _evaluateDecisionEngine();

    _notify();
  }

  // ===========================================================================
  // VOICE SIGNAL
  // ===========================================================================

  void updateVoiceSignal({
    required VoiceSignalState state,
    String? recognizedWords,
  }) {
    final now = DateTime.now();

    if (state ==
        VoiceSignalState.keywordDetected) {
      _lastVoiceKeywordTimestamp =
          now;
    }

    _snapshot = _snapshot.copyWith(
      voiceState: state,

      lastSpokenWords:
      recognizedWords ??
          _snapshot.lastSpokenWords,

      lastHeartbeat: now,
    );

    _evaluateDecisionEngine();

    _notify();
  }

  // ===========================================================================
  // MOVEMENT SIGNAL
  // ===========================================================================

  void updateMovementSignal({
    required MovementSignalState state,
    double intensity = 0.0,
  }) {
    final now = DateTime.now();

    if (state ==
        MovementSignalState.abnormal) {
      _lastAbnormalMovementTimestamp =
          now;
    }

    _snapshot = _snapshot.copyWith(
      movementState: state,

      movementIntensity:
      intensity,

      lastHeartbeat: now,
    );

    _evaluateDecisionEngine();

    _notify();
  }

  // ===========================================================================
  // LOCATION SIGNAL
  // ===========================================================================

  void updateLocationSignal({
    required double latitude,
    required double longitude,
    String? address,
    double speedKmh = 0.0,
    LocationSignalState state =
        LocationSignalState.active,
  }) {
    final now = DateTime.now();

    _snapshot = _snapshot.copyWith(
      latitude: latitude,

      longitude: longitude,

      currentAddress:
      address ??
          _snapshot.currentAddress,

      currentSpeedKmh:
      speedKmh,

      locationState:
      state,

      lastHeartbeat:
      now,
    );

    _evaluateRoutePattern(
      latitude,
      longitude,
      speedKmh,
    );

    _evaluateDecisionEngine();

    _notify();
  }

  // ===========================================================================
  // ROUTE SIGNAL
  // ===========================================================================

  void updateRouteSignal(
      RouteSignalState state, {
        String? reason,
      }) {
    _snapshot = _snapshot.copyWith(
      routeState:
      state,

      decisionReason:
      reason ??
          _snapshot.decisionReason,
    );

    _evaluateDecisionEngine();

    // Transport Detection can call this while
    // Flutter is building a widget.
    //
    // Therefore notification is postponed.
    _notifySafely();
  }

  // ===========================================================================
  // MANUAL SOS
  // ===========================================================================

  void triggerManualSos({
    String? reason,
  }) {
    final now = DateTime.now();

    final AIRiskResult riskResult =
    _riskEngine.calculateRisk(
      unexpectedRoute:
      _snapshot.routeState ==
          RouteSignalState.unusual,

      abnormalMovement:
      _snapshot.movementState ==
          MovementSignalState.abnormal,

      emergencyVoice:
      _snapshot.voiceState ==
          VoiceSignalState.keywordDetected,

      suspiciousTransport:
      _isSuspiciousTransport(),

      notify: false,
    );

    _snapshot = _snapshot.copyWith(
      state:
      GuardianState.emergency,

      userActionState:
      UserActionSignalState.manualSosTriggered,

      decisionReason:
      reason ??
          "Manual SOS was triggered by the user.",

      emergencySpikeCount:
      _snapshot.emergencySpikeCount + 1,

      lastDecisionTime:
      now,

      lastHeartbeat:
      now,

      riskScore: 100,

      riskLevel:
      RiskLevel.emergency,
    );

    debugPrint(
      "Manual SOS → Previous calculated risk: ${riskResult.score}",
    );

    _notify();

    _syncToFirestore();
  }

  // ===========================================================================
  // CANCEL SOS
  // ===========================================================================

  void cancelManualSos() {
    final now = DateTime.now();

    _snapshot = _snapshot.copyWith(
      userActionState:
      UserActionSignalState.manualSosCancelled,

      decisionReason:
      "Manual SOS was resolved/cancelled by the user.",

      lastDecisionTime:
      now,

      lastHeartbeat:
      now,
    );

    _evaluateDecisionEngine();

    _notify();

    _syncToFirestore();
  }

  // ===========================================================================
  // SYSTEM HEALTH
  // ===========================================================================

  void updateSystemHealth({
    NetworkSignalState? network,
    BatterySignalState? battery,
  }) {
    _snapshot = _snapshot.copyWith(
      networkState:
      network ??
          _snapshot.networkState,

      batteryState:
      battery ??
          _snapshot.batteryState,
    );

    _notify();
  }

  // ===========================================================================
  // LOCATION TELEMETRY
  // ===========================================================================

  void _startLocationTelemetry() {
    _positionSubscription?.cancel();

    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings:
          const LocationSettings(
            accuracy:
            LocationAccuracy.high,

            distanceFilter: 5,
          ),
        ).listen(
              (Position position) {
            updateLocationSignal(
              latitude:
              position.latitude,

              longitude:
              position.longitude,

              speedKmh:
              position.speed * 3.6,

              state:
              LocationSignalState.active,
            );
          },
          onError: (e) {
            _snapshot =
                _snapshot.copyWith(
                  locationState:
                  LocationSignalState.unavailable,
                );

            _notify();
          },
        );
  }

  // ===========================================================================
  // SENSOR TELEMETRY
  // ===========================================================================

  void _startSensorTelemetry() {
    _sensorSubscription?.cancel();

    try {
      _sensorSubscription =
          userAccelerometerEventStream()
              .listen(
                (UserAccelerometerEvent event) {
              final double magnitude =
              sqrt(
                event.x * event.x +
                    event.y * event.y +
                    event.z * event.z,
              );

              MovementSignalState
              evaluatedMovement;

              if (magnitude >= 18.5) {
                evaluatedMovement =
                    MovementSignalState.abnormal;
              } else if (magnitude >= 14.0) {
                evaluatedMovement =
                    MovementSignalState.high;
              } else if (magnitude >= 3.0) {
                evaluatedMovement =
                    MovementSignalState.light;
              } else {
                evaluatedMovement =
                    MovementSignalState.normal;
              }

              updateMovementSignal(
                state:
                evaluatedMovement,

                intensity:
                magnitude,
              );
            },
            onError: (_) {},
          );
    } catch (_) {}
  }

  // ===========================================================================
  // ROUTE PATTERN
  // ===========================================================================

  void _evaluateRoutePattern(
      double lat,
      double lng,
      double speedKmh,
      ) {
    RouteSignalState route;

    if (speedKmh > 120.0) {
      route =
          RouteSignalState.unusual;
    } else if (speedKmh < 0.5) {
      route =
          RouteSignalState.stationary;
    } else {
      route =
          RouteSignalState.normal;
    }

    _snapshot =
        _snapshot.copyWith(
          routeState:
          route,
        );
  }

  // ===========================================================================
  // AI RISK SCORE
  // ===========================================================================

  bool _isSuspiciousTransport() {
    return _snapshot.currentSpeedKmh >= 7.0 &&
        _snapshot.routeState ==
            RouteSignalState.unusual;
  }

  void _updateRiskScore() {
    final AIRiskResult riskResult =
    _riskEngine.calculateRisk(
      unexpectedRoute:
      _snapshot.routeState ==
          RouteSignalState.unusual,

      abnormalMovement:
      _snapshot.movementState ==
          MovementSignalState.abnormal,

      emergencyVoice:
      _snapshot.voiceState ==
          VoiceSignalState.keywordDetected,

      suspiciousTransport:
      _isSuspiciousTransport(),

      notify: false,
    );

    _snapshot = _snapshot.copyWith(
      riskScore:
      riskResult.score,

      riskLevel:
      riskResult.level,
    );
  }

  // ===========================================================================
  // CORE MULTI-SIGNAL DECISION ENGINE
  // ===========================================================================

  void _evaluateDecisionEngine() {
    if (!_snapshot.isProtectionActive) {
      _snapshot = _snapshot.copyWith(
        state:
        GuardianState.protectionInactive,

        decisionReason:
        "AI Guardian protection is currently inactive.",
      );

      return;
    }

    // Always update AI Risk Score first.
    _updateRiskScore();

    // -------------------------------------------------------------------------
    // MANUAL SOS HAS HIGHEST PRIORITY
    // -------------------------------------------------------------------------

    if (_snapshot.userActionState ==
        UserActionSignalState.manualSosTriggered) {
      _snapshot = _snapshot.copyWith(
        state:
        GuardianState.emergency,

        riskScore: 100,

        riskLevel:
        RiskLevel.emergency,

        decisionReason:
        "Manual SOS triggered by user action.",
      );

      return;
    }

    final now = DateTime.now();

    final bool hasRecentVoiceEmergency =
        now
            .difference(
          _lastVoiceKeywordTimestamp,
        )
            .inSeconds <=
            _voiceWindowSeconds;

    final bool hasRecentAbnormalMovement =
        now
            .difference(
          _lastAbnormalMovementTimestamp,
        )
            .inSeconds <=
            _movementWindowSeconds;

    final bool hasUnusualRoute =
        _snapshot.routeState ==
            RouteSignalState.unusual;

    final bool hasHighMovement =
        _snapshot.movementState ==
            MovementSignalState.high;

    GuardianState nextState =
        GuardianState.safe;

    String nextReason =
        "All incoming signals (Voice, Movement, GPS, Route) are normal.";

    // -------------------------------------------------------------------------
    // MULTI-SIGNAL CORRELATION
    // -------------------------------------------------------------------------

    if (hasRecentVoiceEmergency &&
        hasRecentAbnormalMovement &&
        hasUnusualRoute) {
      nextState =
          GuardianState.emergency;

      nextReason =
      "Multi-signal emergency confirmed (Voice trigger + Abnormal motion + Route anomaly).";
    } else if (hasRecentVoiceEmergency &&
        hasRecentAbnormalMovement) {
      nextState =
          GuardianState.potentialEmergency;

      nextReason =
      "Correlated signals detected: Emergency voice keyword + Abnormal sudden movement.";
    } else if (hasUnusualRoute &&
        hasRecentAbnormalMovement) {
      nextState =
          GuardianState.potentialEmergency;

      nextReason =
      "Correlated signals detected: Unusual route/speed anomaly + Abnormal sudden movement.";
    } else if (hasRecentVoiceEmergency &&
        hasUnusualRoute) {
      nextState =
          GuardianState.potentialEmergency;

      nextReason =
      "Correlated signals detected: Emergency voice keyword + Route anomaly.";
    } else if (hasRecentVoiceEmergency) {
      nextState =
          GuardianState.attention;

      nextReason =
      "Emergency keyword captured. Monitoring for secondary movement/route confirmation.";
    } else if (hasRecentAbnormalMovement) {
      nextState =
          GuardianState.attention;

      nextReason =
      "Sudden motion spike observed. Evaluating environment for secondary signals.";
    } else if (hasUnusualRoute ||
        hasHighMovement) {
      nextState =
          GuardianState.attention;

      nextReason =
      "Single attention signal: ${hasUnusualRoute ? 'Unusual route deviation' : 'High movement activity'}.";
    } else {
      nextState =
          GuardianState.safe;

      nextReason =
      "All environmental signals verified in safe baseline.";
    }

    _snapshot = _snapshot.copyWith(
      state:
      nextState,

      decisionReason:
      nextReason,

      lastDecisionTime:
      now,
    );
  }

  // ===========================================================================
  // FIRESTORE SYNC
  // ===========================================================================

  Future<void> _syncToFirestore() async {
    try {
      final user =
          FirebaseAuth.instance.currentUser;

      if (user == null) {
        return;
      }

      final docRef =
      FirebaseFirestore.instance
          .collection(
        'guardian_sessions',
      )
          .doc(
        user.uid,
      );

      await docRef.set(
        _snapshot.toFirestoreMap(
          user.uid,
        ),
        SetOptions(
          merge: true,
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        print(
          "Firestore guardian sync error: $e",
        );
      }
    }
  }

  // ===========================================================================
  // NORMAL NOTIFICATION
  // ===========================================================================

  void _notify() {
    if (_streamController.isClosed) {
      return;
    }

    // Stream update.
    _streamController.add(
      _snapshot,
    );

    // Delay ChangeNotifier notification until
    // after current Flutter frame.
    WidgetsBinding.instance.addPostFrameCallback(
          (_) {
        if (_streamController.isClosed) {
          return;
        }

        try {
          notifyListeners();
        } catch (e) {
          debugPrint(
            "AI Guardian notification error: $e",
          );
        }
      },
    );
  }

  // ===========================================================================
  // SAFE NOTIFICATION
  // ===========================================================================

  void _notifySafely() {
    if (_streamController.isClosed) {
      return;
    }

    // Send latest snapshot through stream.
    _streamController.add(
      _snapshot,
    );

    // Delay ChangeNotifier notification.
    WidgetsBinding.instance.addPostFrameCallback(
          (_) {
        if (_streamController.isClosed) {
          return;
        }

        try {
          notifyListeners();
        } catch (e) {
          debugPrint(
            "AI Guardian safe notification error: $e",
          );
        }
      },
    );
  }

  // ===========================================================================
  // DISPOSE
  // ===========================================================================

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    _deescalationTimer?.cancel();
    _deescalationTimer = null;

    _positionSubscription?.cancel();
    _positionSubscription = null;

    _sensorSubscription?.cancel();
    _sensorSubscription = null;

    if (!_streamController.isClosed) {
      _streamController.close();
    }

    super.dispose();
  }
}