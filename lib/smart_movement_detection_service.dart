import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'ai_guardian_service.dart';

/// Physical motion classification states.
enum MovementState {
  normal("Normal Movement", "Phone is steady or resting safely"),
  increased("Increased Movement", "Moderate motion / brisk handling"),
  excessive("Excessive Shaking", "High frequency shaking detected"),
  unusual("Unusual Movement", "Violent sudden multi-directional motion");

  final String label;
  final String detail;
  const MovementState(this.label, this.detail);
}

/// Safety decision formulated by combining movement, duration, GPS, and voice.
enum MovementDecision {
  safe(
    label: "Safe",
    emoji: "🟢",
    description: "Movement is normal or verified as brief temporary handling.",
  ),
  attention(
    label: "Attention",
    emoji: "🟡",
    description: "Continuous elevated motion detected. Evaluating surrounding context.",
  ),
  potentialEmergency(
    label: "Potential Emergency",
    emoji: "🟠",
    description: "Sustained abnormal movement supported by secondary emergency signals.",
  );

  final String label;
  final String emoji;
  final String description;

  const MovementDecision({
    required this.label,
    required this.emoji,
    required this.description,
  });
}

/// Real-time snapshot of Smart Movement Detection telemetry.
class SmartMovementSnapshot {
  final bool isMonitoring;
  final MovementState movementState;
  final MovementDecision decision;
  final double currentIntensity;
  final double peakIntensity;
  final int sustainedDurationMs;
  final bool isAccelAvailable;
  final bool isGyroAvailable;
  final String gyroStatusText;
  final bool isGpsAvailable;
  final String gpsStatusText;
  final bool isVoiceKeywordPresent;
  final String voiceStatusText;
  final String decisionReason;
  final DateTime lastEvaluated;

  const SmartMovementSnapshot({
    required this.isMonitoring,
    required this.movementState,
    required this.decision,
    required this.currentIntensity,
    required this.peakIntensity,
    required this.sustainedDurationMs,
    required this.isAccelAvailable,
    required this.isGyroAvailable,
    required this.gyroStatusText,
    required this.isGpsAvailable,
    required this.gpsStatusText,
    required this.isVoiceKeywordPresent,
    required this.voiceStatusText,
    required this.decisionReason,
    required this.lastEvaluated,
  });

  factory SmartMovementSnapshot.initial() {
    return SmartMovementSnapshot(
      isMonitoring: false,
      movementState: MovementState.normal,
      decision: MovementDecision.safe,
      currentIntensity: 0.0,
      peakIntensity: 0.0,
      sustainedDurationMs: 0,
      isAccelAvailable: false,
      isGyroAvailable: false,
      gyroStatusText: "Checking...",
      isGpsAvailable: false,
      gpsStatusText: "GPS idle",
      isVoiceKeywordPresent: false,
      voiceStatusText: "No emergency phrases",
      decisionReason: "Monitoring is currently inactive. Tap 'Start Monitoring' to begin.",
      lastEvaluated: DateTime.now(),
    );
  }

  SmartMovementSnapshot copyWith({
    bool? isMonitoring,
    MovementState? movementState,
    MovementDecision? decision,
    double? currentIntensity,
    double? peakIntensity,
    int? sustainedDurationMs,
    bool? isAccelAvailable,
    bool? isGyroAvailable,
    String? gyroStatusText,
    bool? isGpsAvailable,
    String? gpsStatusText,
    bool? isVoiceKeywordPresent,
    String? voiceStatusText,
    String? decisionReason,
    DateTime? lastEvaluated,
  }) {
    return SmartMovementSnapshot(
      isMonitoring: isMonitoring ?? this.isMonitoring,
      movementState: movementState ?? this.movementState,
      decision: decision ?? this.decision,
      currentIntensity: currentIntensity ?? this.currentIntensity,
      peakIntensity: peakIntensity ?? this.peakIntensity,
      sustainedDurationMs: sustainedDurationMs ?? this.sustainedDurationMs,
      isAccelAvailable: isAccelAvailable ?? this.isAccelAvailable,
      isGyroAvailable: isGyroAvailable ?? this.isGyroAvailable,
      gyroStatusText: gyroStatusText ?? this.gyroStatusText,
      isGpsAvailable: isGpsAvailable ?? this.isGpsAvailable,
      gpsStatusText: gpsStatusText ?? this.gpsStatusText,
      isVoiceKeywordPresent: isVoiceKeywordPresent ?? this.isVoiceKeywordPresent,
      voiceStatusText: voiceStatusText ?? this.voiceStatusText,
      decisionReason: decisionReason ?? this.decisionReason,
      lastEvaluated: lastEvaluated ?? this.lastEvaluated,
    );
  }
}

/// Service implementing the multi-stage Smart Movement Detection pipeline.
///
/// Flow:
/// Movement detected -> Check duration -> Check GPS -> Check voice -> AI decision
class SmartMovementDetectionService extends ChangeNotifier {
  static final SmartMovementDetectionService instance =
      SmartMovementDetectionService._internal();

  SmartMovementDetectionService._internal();

  SmartMovementSnapshot _snapshot = SmartMovementSnapshot.initial();
  SmartMovementSnapshot get snapshot => _snapshot;

  final StreamController<SmartMovementSnapshot> _streamController =
      StreamController<SmartMovementSnapshot>.broadcast();
  Stream<SmartMovementSnapshot> get stream => _streamController.stream;

  // Sensor Subscriptions
  StreamSubscription<UserAccelerometerEvent>? _userAccelSub;
  StreamSubscription<AccelerometerEvent>? _accelFallbackSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;

  // Duration & State Buffers
  int? _unusualMovementStartMs;
  int _lastNormalTimestampMs = 0;
  double _peakSessionIntensity = 0.0;

  // Thresholds
  static const double _unusualThreshold = 18.0;
  static const double _excessiveThreshold = 12.5;
  static const double _increasedThreshold = 4.0;
  static const int _sustainedDurationThresholdMs = 2500; // 2.5s for sustained check

  // ===========================================================================
  // MONITORING CONTROL
  // ===========================================================================

  void startMonitoring() {
    if (_snapshot.isMonitoring) return;

    _unusualMovementStartMs = null;
    _peakSessionIntensity = 0.0;
    _lastNormalTimestampMs = DateTime.now().millisecondsSinceEpoch;

    _snapshot = _snapshot.copyWith(
      isMonitoring: true,
      decision: MovementDecision.safe,
      movementState: MovementState.normal,
      currentIntensity: 0.0,
      peakIntensity: 0.0,
      sustainedDurationMs: 0,
      decisionReason: "Monitoring initialized. Phone shake alone will not trigger an SOS.",
      lastEvaluated: DateTime.now(),
    );

    _subscribeToAccelerometer();
    _subscribeToGyroscope();
    _checkGpsContext();
    _checkVoiceContext();

    _notify();
  }

  void stopMonitoring() {
    _userAccelSub?.cancel();
    _userAccelSub = null;

    _accelFallbackSub?.cancel();
    _accelFallbackSub = null;

    _gyroSub?.cancel();
    _gyroSub = null;

    _unusualMovementStartMs = null;

    _snapshot = _snapshot.copyWith(
      isMonitoring: false,
      decision: MovementDecision.safe,
      movementState: MovementState.normal,
      currentIntensity: 0.0,
      sustainedDurationMs: 0,
      decisionReason: "Monitoring stopped by user.",
      lastEvaluated: DateTime.now(),
    );

    _notify();
  }

  // ===========================================================================
  // SENSOR SUBSCRIPTIONS
  // ===========================================================================

  void _subscribeToAccelerometer() {
    _userAccelSub?.cancel();
    _accelFallbackSub?.cancel();

    try {
      _userAccelSub = userAccelerometerEventStream().listen(
        (UserAccelerometerEvent event) {
          _processAcceleration(event.x, event.y, event.z, isLinear: true);
        },
        onError: (e) {
          _fallbackToAccelerometer();
        },
      );
      _snapshot = _snapshot.copyWith(isAccelAvailable: true);
    } catch (_) {
      _fallbackToAccelerometer();
    }
  }

  void _fallbackToAccelerometer() {
    try {
      _accelFallbackSub = accelerometerEventStream().listen(
        (AccelerometerEvent event) {
          double rawMag = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
          double netMag = (rawMag - 9.80665).abs();
          _processAcceleration(event.x, event.y, netMag, isLinear: false);
        },
        onError: (_) {
          _snapshot = _snapshot.copyWith(isAccelAvailable: false);
          _notify();
        },
      );
      _snapshot = _snapshot.copyWith(isAccelAvailable: true);
    } catch (_) {
      _snapshot = _snapshot.copyWith(isAccelAvailable: false);
      _notify();
    }
  }

  void _subscribeToGyroscope() {
    _gyroSub?.cancel();
    try {
      _gyroSub = gyroscopeEventStream().listen(
        (GyroscopeEvent event) {
          _snapshot = _snapshot.copyWith(
            isGyroAvailable: true,
            gyroStatusText: "Active & Streaming",
          );
        },
        onError: (_) {
          _snapshot = _snapshot.copyWith(
            isGyroAvailable: false,
            gyroStatusText: "Gyroscope unavailable on this device",
          );
          _notify();
        },
      );
      _snapshot = _snapshot.copyWith(
        isGyroAvailable: true,
        gyroStatusText: "Active & Streaming",
      );
    } catch (_) {
      _snapshot = _snapshot.copyWith(
        isGyroAvailable: false,
        gyroStatusText: "Gyroscope unavailable",
      );
      _notify();
    }
  }

  // ===========================================================================
  // SIGNAL INGESTION & PIPELINE EVALUATION
  // ===========================================================================

  /// Stage 1 & 2: Movement Detection & Duration Check
  void _processAcceleration(
    double x,
    double y,
    double z, {
    required bool isLinear,
  }) {
    double magnitude = isLinear ? sqrt(x * x + y * y + z * z) : z;
    _peakSessionIntensity = max(_peakSessionIntensity, magnitude);

    final nowMs = DateTime.now().millisecondsSinceEpoch;

    // Classify instantaneous movement
    MovementState state;
    if (magnitude >= _unusualThreshold) {
      state = MovementState.unusual;
    } else if (magnitude >= _excessiveThreshold) {
      state = MovementState.excessive;
    } else if (magnitude >= _increasedThreshold) {
      state = MovementState.increased;
    } else {
      state = MovementState.normal;
    }

    // Duration Check: Observe whether elevated movement is continuous or temporary
    int durationMs = 0;
    if (state == MovementState.excessive || state == MovementState.unusual) {
      _unusualMovementStartMs ??= nowMs;
      durationMs = nowMs - _unusualMovementStartMs!;
    } else {
      // If motion returns to normal, evaluate if buffer should reset
      if (nowMs - _lastNormalTimestampMs > 1200) {
        _unusualMovementStartMs = null;
        durationMs = 0;
      }
      _lastNormalTimestampMs = nowMs;
    }

    // Stage 3 & 4: Check GPS and Voice from existing services
    final bool gpsAvailable = _checkGpsContext();
    final bool voiceKeyword = _checkVoiceContext();

    // Stage 5: Formulate Smart Multi-Stage Decision
    final decisionResult = _evaluateSmartDecision(
      state: state,
      magnitude: magnitude,
      durationMs: durationMs,
      isGpsAvailable: gpsAvailable,
      isVoiceEmergency: voiceKeyword,
    );

    _snapshot = _snapshot.copyWith(
      movementState: state,
      currentIntensity: magnitude,
      peakIntensity: _peakSessionIntensity,
      sustainedDurationMs: durationMs,
      decision: decisionResult.decision,
      decisionReason: decisionResult.reason,
      lastEvaluated: DateTime.now(),
    );

    // Forward supporting state to existing AI Guardian
    _forwardToAIGuardian(state, magnitude);

    _notify();
  }

  /// Stage 3: GPS Supporting Check
  bool _checkGpsContext() {
    try {
      final guardianSnapshot = AIGuardianService.instance.snapshot;
      bool isGpsActive = guardianSnapshot.locationState == LocationSignalState.active;
      String gpsText = isGpsActive
          ? "GPS Active (${guardianSnapshot.currentSpeedKmh.toStringAsFixed(0)} km/h)"
          : "GPS Standby / Searching";

      _snapshot = _snapshot.copyWith(
        isGpsAvailable: isGpsActive,
        gpsStatusText: gpsText,
      );
      return isGpsActive;
    } catch (_) {
      return false;
    }
  }

  /// Stage 4: Voice Supporting Check
  bool _checkVoiceContext() {
    try {
      final guardianSnapshot = AIGuardianService.instance.snapshot;
      bool isVoiceEmergency =
          guardianSnapshot.voiceState == VoiceSignalState.keywordDetected;
      String voiceText = isVoiceEmergency
          ? 'Emergency keyword active ("${guardianSnapshot.lastSpokenWords ?? 'help'}")'
          : "No emergency keywords heard";

      _snapshot = _snapshot.copyWith(
        isVoiceKeywordPresent: isVoiceEmergency,
        voiceStatusText: voiceText,
      );
      return isVoiceEmergency;
    } catch (_) {
      return false;
    }
  }

  /// Stage 5: Multi-Stage Explainable Decision Formulation
  ({MovementDecision decision, String reason}) _evaluateSmartDecision({
    required MovementState state,
    required double magnitude,
    required int durationMs,
    required bool isGpsAvailable,
    required bool isVoiceEmergency,
  }) {
    // Rule 1: Normal or slight movement -> SAFE
    if (state == MovementState.normal || state == MovementState.increased) {
      return (
        decision: MovementDecision.safe,
        reason: "Normal movement baseline. No abnormal shaking or force detected.",
      );
    }

    // Rule 2: Excessive / Unusual motion but short duration (< 2.5s) -> SAFE (Temporary handling)
    if (durationMs < _sustainedDurationThresholdMs) {
      double seconds = durationMs / 1000.0;
      return (
        decision: MovementDecision.safe,
        reason:
            "Brief temporary movement (${seconds.toStringAsFixed(1)}s). Phone shake alone does NOT trigger emergency.",
      );
    }

    // Rule 3: Sustained unusual movement + Supporting Emergency Voice Signal -> POTENTIAL EMERGENCY
    if (isVoiceEmergency) {
      return (
        decision: MovementDecision.potentialEmergency,
        reason:
            "Sustained unusual movement (${(durationMs / 1000).toStringAsFixed(1)}s) corroborated with emergency voice keyword!",
      );
    }

    // Rule 4: Sustained excessive shaking without emergency voice -> ATTENTION
    return (
      decision: MovementDecision.attention,
      reason:
          "Continuous shaking / unusual movement sustained for ${(durationMs / 1000).toStringAsFixed(1)}s. Monitoring for secondary indicators.",
    );
  }

  /// Forwards movement state to existing AI Guardian system
  void _forwardToAIGuardian(MovementState state, double magnitude) {
    MovementSignalState guardianSignal;
    switch (state) {
      case MovementState.normal:
        guardianSignal = MovementSignalState.normal;
        break;
      case MovementState.increased:
        guardianSignal = MovementSignalState.light;
        break;
      case MovementState.excessive:
        guardianSignal = MovementSignalState.high;
        break;
      case MovementState.unusual:
        guardianSignal = MovementSignalState.abnormal;
        break;
    }

    AIGuardianService.instance.updateMovementSignal(
      state: guardianSignal,
      intensity: magnitude,
    );
  }

  void _notify() {
    _streamController.add(_snapshot);
    notifyListeners();
  }

  @override
  void dispose() {
    stopMonitoring();
    _streamController.close();
    super.dispose();
  }
}
