import 'package:flutter/foundation.dart';

/// AI Risk severity levels.
enum RiskLevel {
  safe,
  attention,
  warning,
  emergency,
}

/// Result produced by the AI Risk Engine.
class AIRiskResult {
  final int score;
  final RiskLevel level;
  final String title;
  final String message;
  final List<String> detectedSignals;
  final DateTime calculatedAt;

  const AIRiskResult({
    required this.score,
    required this.level,
    required this.title,
    required this.message,
    required this.detectedSignals,
    required this.calculatedAt,
  });

  bool get isSafe => level == RiskLevel.safe;

  bool get needsAttention =>
      level == RiskLevel.attention ||
          level == RiskLevel.warning;

  bool get isEmergency =>
      level == RiskLevel.emergency;
}

/// Central AI Risk Score Engine.
///
/// This service calculates a safety score from
/// multiple safety signals.
///
/// Score:
/// 0 - 30   = SAFE
/// 31 - 60  = ATTENTION
/// 61 - 80  = WARNING
/// 81 - 100 = EMERGENCY
class AIRiskEngine extends ChangeNotifier {
  static final AIRiskEngine instance =
  AIRiskEngine._internal();

  AIRiskEngine._internal();

  AIRiskResult _result = AIRiskResult(
    score: 0,
    level: RiskLevel.safe,
    title: "SAFE",
    message:
    "No immediate safety risk detected.",
    detectedSignals: const [],
    calculatedAt: DateTime.now(),
  );

  AIRiskResult get result => _result;

  int get riskScore => _result.score;

  RiskLevel get riskLevel => _result.level;

  // ---------------------------------------------------------------------------
  // RISK POINTS
  // ---------------------------------------------------------------------------

  static const int unexpectedRoutePoints = 30;

  static const int abnormalMovementPoints = 25;

  static const int emergencyVoicePoints = 40;

  static const int suspiciousTransportPoints = 15;

  // ---------------------------------------------------------------------------
  // CALCULATE RISK
  // ---------------------------------------------------------------------------

  AIRiskResult calculateRisk({
    required bool unexpectedRoute,
    required bool abnormalMovement,
    required bool emergencyVoice,
    required bool suspiciousTransport,

    /// When false, the result is updated but this engine
    /// does not notify its own listeners.
    ///
    /// AI Guardian uses false because Guardian itself
    /// manages UI notifications.
    bool notify = true,
  }) {
    int score = 0;

    final List<String> signals = [];

    // Unexpected route
    if (unexpectedRoute) {
      score += unexpectedRoutePoints;

      signals.add(
        "Unexpected route detected",
      );
    }

    // Abnormal movement
    if (abnormalMovement) {
      score += abnormalMovementPoints;

      signals.add(
        "Abnormal movement detected",
      );
    }

    // Emergency voice
    if (emergencyVoice) {
      score += emergencyVoicePoints;

      signals.add(
        "Emergency voice keyword detected",
      );
    }

    // Suspicious transport
    if (suspiciousTransport) {
      score += suspiciousTransportPoints;

      signals.add(
        "Unusual transport behaviour detected",
      );
    }

    // Keep score between 0 and 100.
    if (score > 100) {
      score = 100;
    }

    // -------------------------------------------------------------------------
    // DETERMINE RISK LEVEL
    // -------------------------------------------------------------------------

    final RiskLevel level;

    if (score <= 30) {
      level = RiskLevel.safe;
    } else if (score <= 60) {
      level = RiskLevel.attention;
    } else if (score <= 80) {
      level = RiskLevel.warning;
    } else {
      level = RiskLevel.emergency;
    }

    // -------------------------------------------------------------------------
    // MESSAGE
    // -------------------------------------------------------------------------

    final String title;

    final String message;

    switch (level) {
      case RiskLevel.safe:
        title = "SAFE";

        message =
        "Your current safety signals appear normal. Monitoring continues.";

        break;

      case RiskLevel.attention:
        title = "ATTENTION";

        message =
        "An unusual safety signal was detected. SheShield AI is continuing to monitor the situation.";

        break;

      case RiskLevel.warning:
        title = "WARNING";

        message =
        "Multiple unusual safety signals were detected. Please stay alert.";

        break;

      case RiskLevel.emergency:
        title = "EMERGENCY";

        message =
        "Multiple high-risk signals were detected. Emergency protection may be required.";

        break;
    }

    final AIRiskResult newResult =
    AIRiskResult(
      score: score,
      level: level,
      title: title,
      message: message,
      detectedSignals:
      List.unmodifiable(signals),
      calculatedAt: DateTime.now(),
    );

    _result = newResult;

    if (notify) {
      notifyListeners();
    }

    debugPrint(
      "SheShield AI Risk Engine → "
          "Score: $score | Level: ${level.name}",
    );

    if (signals.isNotEmpty) {
      debugPrint(
        "Detected signals: ${signals.join(", ")}",
      );
    }

    return newResult;
  }

  // ---------------------------------------------------------------------------
  // RESET
  // ---------------------------------------------------------------------------

  void resetRisk({
    bool notify = true,
  }) {
    _result = AIRiskResult(
      score: 0,
      level: RiskLevel.safe,
      title: "SAFE",
      message:
      "Safety monitoring is normal. No immediate risk detected.",
      detectedSignals: const [],
      calculatedAt: DateTime.now(),
    );

    if (notify) {
      notifyListeners();
    }

    debugPrint(
      "SheShield AI Risk Engine → Risk reset to SAFE",
    );
  }

  // ---------------------------------------------------------------------------
  // UPDATE FROM SIGNALS
  // ---------------------------------------------------------------------------

  void updateFromSignals({
    bool unexpectedRoute = false,
    bool abnormalMovement = false,
    bool emergencyVoice = false,
    bool suspiciousTransport = false,
    bool notify = true,
  }) {
    calculateRisk(
      unexpectedRoute: unexpectedRoute,
      abnormalMovement: abnormalMovement,
      emergencyVoice: emergencyVoice,
      suspiciousTransport: suspiciousTransport,
      notify: notify,
    );
  }

  // ---------------------------------------------------------------------------
  // TEXT HELPERS
  // ---------------------------------------------------------------------------

  String get riskLevelText {
    switch (_result.level) {
      case RiskLevel.safe:
        return "SAFE";

      case RiskLevel.attention:
        return "ATTENTION";

      case RiskLevel.warning:
        return "WARNING";

      case RiskLevel.emergency:
        return "EMERGENCY";
    }
  }

  String get riskDescription {
    return _result.message;
  }

  // ---------------------------------------------------------------------------
  // SAFETY CONDITIONS
  // ---------------------------------------------------------------------------

  bool get shouldTriggerEmergency {
    return _result.level ==
        RiskLevel.emergency;
  }

  bool get shouldShowWarning {
    return _result.level ==
        RiskLevel.warning ||
        _result.level ==
            RiskLevel.emergency;
  }

  bool get shouldContinueMonitoring {
    return true;
  }

  // ---------------------------------------------------------------------------
  // TEST FUNCTIONS
  // ---------------------------------------------------------------------------

  void runSafetyTest() {
    calculateRisk(
      unexpectedRoute: true,
      abnormalMovement: true,
      emergencyVoice: false,
      suspiciousTransport: true,
    );
  }

  void runEmergencyTest() {
    calculateRisk(
      unexpectedRoute: true,
      abnormalMovement: true,
      emergencyVoice: true,
      suspiciousTransport: true,
    );
  }
}