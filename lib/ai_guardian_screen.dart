import 'dart:async';
import 'package:flutter/material.dart';
import 'ai_guardian_service.dart';
import 'ai_risk_engine.dart';
import 'sos_screen.dart';
import 'voice_detection_screen.dart';
import 'movement_detection_screen.dart';
import 'live_location_screen.dart';

/// Professional AI Guardian Safety Dashboard.
///
/// Central safety monitoring interface for SheShield AI.
/// Displays real-time multi-signal telemetry and AI Risk Score.
class AIGuardianScreen extends StatefulWidget {
  const AIGuardianScreen({super.key});

  @override
  State<AIGuardianScreen> createState() => _AIGuardianScreenState();
}

class _AIGuardianScreenState extends State<AIGuardianScreen>
    with SingleTickerProviderStateMixin {
  final AIGuardianService _guardianService =
      AIGuardianService.instance;

  late StreamSubscription<AIGuardianSnapshot> _guardianSub;
  late AIGuardianSnapshot _currentSnapshot;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _currentSnapshot = _guardianService.snapshot;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(
      begin: 0.96,
      end: 1.04,
    ).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    // Real-time AI Guardian updates
    _guardianSub = _guardianService.stream.listen(
          (snapshot) {
        if (!mounted) return;

        setState(() {
          _currentSnapshot = snapshot;
        });
      },
    );
  }

  @override
  void dispose() {
    _guardianSub.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // STATE HELPERS
  // ===========================================================================

  Color _getStateColor(GuardianState state) {
    switch (state) {
      case GuardianState.safe:
        return const Color(0xFF10B981);

      case GuardianState.attention:
        return const Color(0xFFF59E0B);

      case GuardianState.potentialEmergency:
        return const Color(0xFFF97316);

      case GuardianState.emergency:
        return const Color(0xFFEF4444);

      case GuardianState.protectionInterrupted:
        return const Color(0xFFD97706);

      case GuardianState.protectionInactive:
        return Colors.grey.shade600;
    }
  }

  IconData _getStateIcon(GuardianState state) {
    switch (state) {
      case GuardianState.safe:
        return Icons.verified_user_rounded;

      case GuardianState.attention:
        return Icons.info_rounded;

      case GuardianState.potentialEmergency:
        return Icons.warning_amber_rounded;

      case GuardianState.emergency:
        return Icons.emergency_rounded;

      case GuardianState.protectionInterrupted:
        return Icons.sync_problem_rounded;

      case GuardianState.protectionInactive:
        return Icons.shield_outlined;
    }
  }

  Color _getRiskColor(RiskLevel level) {
    switch (level) {
      case RiskLevel.safe:
        return const Color(0xFF10B981);

      case RiskLevel.attention:
        return const Color(0xFFF59E0B);

      case RiskLevel.warning:
        return const Color(0xFFF97316);

      case RiskLevel.emergency:
        return const Color(0xFFEF4444);
    }
  }

  String _getRiskLevelText(RiskLevel level) {
    switch (level) {
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

  String _getRiskDescription(RiskLevel level) {
    switch (level) {
      case RiskLevel.safe:
        return "Current safety signals are within the normal range.";

      case RiskLevel.attention:
        return "A caution signal was detected. AI Guardian is continuing to monitor.";

      case RiskLevel.warning:
        return "Multiple unusual signals were detected. Please stay alert.";

      case RiskLevel.emergency:
        return "High-risk signals detected. Emergency protection may be required.";
    }
  }

  String _formatTime(DateTime dt) {
    final hour =
    dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);

    final minute = dt.minute.toString().padLeft(2, '0');
    final second = dt.second.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? "PM" : "AM";

    return "$hour:$minute:$second $period";
  }

  // ===========================================================================
  // MAIN BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final state = _currentSnapshot.state;
    final stateColor = _getStateColor(state);

    final isCritical =
        state == GuardianState.emergency ||
            state == GuardianState.potentialEmergency ||
            state == GuardianState.attention;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F3FF),

      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,

        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shield_rounded,
              size: 22,
            ),
            SizedBox(width: 8),
            Text(
              "AI Guardian",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),

        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: "Test / Simulate Signals",
            onPressed: _showSimulationBottomSheet,
          ),
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: "Guardian Architecture",
            onPressed: _showArchitectureDialog,
          ),
        ],
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Primary Guardian Status
              _buildHeroStatusCard(
                state,
                stateColor,
                isCritical,
              ),

              const SizedBox(height: 14),

              // 2. Heartbeat
              _buildHeartbeatBar(stateColor),

              const SizedBox(height: 14),

              // 3. NEW AI RISK SCORE
              _buildRiskScoreCard(),

              const SizedBox(height: 14),

              // 4. Signal Telemetry
              _buildSignalTelemetryGrid(),

              const SizedBox(height: 14),

              // 5. Decision Insights
              _buildDecisionInsightsCard(stateColor),

              const SizedBox(height: 20),

              // 6. Start / Stop Protection
              _buildProtectionActionButton(),

              const SizedBox(height: 12),

              // 7. Manual SOS
              _buildManualSosTriggerButton(),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // HERO STATUS CARD
  // ===========================================================================

  Widget _buildHeroStatusCard(
      GuardianState state,
      Color stateColor,
      bool isCritical,
      ) {
    return AnimatedBuilder(
      animation: _pulseAnimation,

      builder: (context, child) {
        return Transform.scale(
          scale: isCritical
              ? _pulseAnimation.value
              : 1.0,

          child: child,
        );
      },

      child: Container(
        padding: const EdgeInsets.all(20),

        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),

          border: Border.all(
            color: stateColor.withValues(alpha: 0.35),
            width: isCritical ? 2.5 : 1.5,
          ),

          boxShadow: [
            BoxShadow(
              color: stateColor.withValues(
                alpha: isCritical ? 0.22 : 0.08,
              ),
              blurRadius: isCritical ? 18 : 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),

        child: Column(
          children: [
            Row(
              mainAxisAlignment:
              MainAxisAlignment.spaceBetween,

              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),

                  decoration: BoxDecoration(
                    color:
                    _currentSnapshot.isProtectionActive
                        ? Colors.deepPurple.withValues(
                      alpha: 0.1,
                    )
                        : Colors.grey.shade200,

                    borderRadius:
                    BorderRadius.circular(20),
                  ),

                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,

                        decoration: BoxDecoration(
                          shape: BoxShape.circle,

                          color:
                          _currentSnapshot
                              .isProtectionActive
                              ? Colors.green
                              : Colors.grey,
                        ),
                      ),

                      const SizedBox(width: 6),

                      Text(
                        _currentSnapshot.isProtectionActive
                            ? "PROTECTION ACTIVE"
                            : "PROTECTION INACTIVE",

                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,

                          color:
                          _currentSnapshot
                              .isProtectionActive
                              ? Colors.deepPurple
                              : Colors.grey.shade700,

                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),

                Text(
                  state.emoji,
                  style: const TextStyle(
                    fontSize: 24,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(22),

              decoration: BoxDecoration(
                shape: BoxShape.circle,

                color: stateColor.withValues(
                  alpha: 0.12,
                ),

                border: Border.all(
                  color: stateColor.withValues(
                    alpha: 0.25,
                  ),
                  width: 2,
                ),
              ),

              child: Icon(
                _getStateIcon(state),
                size: 56,
                color: stateColor,
              ),
            ),

            const SizedBox(height: 14),

            Text(
              state.label.toUpperCase(),

              textAlign: TextAlign.center,

              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: stateColor,
                letterSpacing: 0.5,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              state.description,

              textAlign: TextAlign.center,

              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // HEARTBEAT BAR
  // ===========================================================================

  Widget _buildHeartbeatBar(Color stateColor) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 10,
      ),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),

      child: Row(
        mainAxisAlignment:
        MainAxisAlignment.spaceBetween,

        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,

                decoration: BoxDecoration(
                  shape: BoxShape.circle,

                  color:
                  _currentSnapshot
                      .isProtectionActive
                      ? Colors.green
                      : Colors.grey.shade400,
                ),
              ),

              const SizedBox(width: 8),

              Text(
                _currentSnapshot.isProtectionActive
                    ? "Heartbeat: Active"
                    : "Heartbeat: Paused",

                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),

          Text(
            "Last Update: ${_formatTime(_currentSnapshot.lastHeartbeat)}",

            style: TextStyle(
              fontSize: 11.5,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // AI RISK SCORE CARD
  // ===========================================================================

  Widget _buildRiskScoreCard() {
    final int score = _currentSnapshot.riskScore;
    final RiskLevel level = _currentSnapshot.riskLevel;

    final Color riskColor = _getRiskColor(level);
    final String levelText = _getRiskLevelText(level);

    return Container(
      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),

        border: Border.all(
          color: riskColor.withValues(alpha: 0.25),
          width: 1.5,
        ),

        boxShadow: [
          BoxShadow(
            color: riskColor.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,

        children: [
          // Header
          Row(
            mainAxisAlignment:
            MainAxisAlignment.spaceBetween,

            children: [
              const Row(
                children: [
                  Icon(
                    Icons.analytics_rounded,
                    color: Colors.deepPurple,
                    size: 20,
                  ),

                  SizedBox(width: 8),

                  Text(
                    "AI Risk Score",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),

              Container(
                padding:
                const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),

                decoration: BoxDecoration(
                  color: riskColor.withValues(
                    alpha: 0.12,
                  ),

                  borderRadius:
                  BorderRadius.circular(20),
                ),

                child: Text(
                  levelText,

                  style: TextStyle(
                    color: riskColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Score + Description
          Row(
            crossAxisAlignment:
            CrossAxisAlignment.center,

            children: [
              // Score Circle
              Container(
                width: 82,
                height: 82,

                decoration: BoxDecoration(
                  shape: BoxShape.circle,

                  color: riskColor.withValues(
                    alpha: 0.10,
                  ),

                  border: Border.all(
                    color: riskColor.withValues(
                      alpha: 0.35,
                    ),
                    width: 3,
                  ),
                ),

                child: Center(
                  child: Column(
                    mainAxisAlignment:
                    MainAxisAlignment.center,

                    children: [
                      Text(
                        "$score",

                        style: TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.bold,
                          color: riskColor,
                        ),
                      ),

                      Text(
                        "/ 100",

                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // Description
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,

                  children: [
                    Text(
                      levelText,

                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: riskColor,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      _getRiskDescription(level),

                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Progress Bar
          ClipRRect(
            borderRadius:
            BorderRadius.circular(10),

            child: LinearProgressIndicator(
              value: score.clamp(0, 100) / 100,
              minHeight: 8,

              backgroundColor:
              Colors.grey.shade200,

              valueColor:
              AlwaysStoppedAnimation<Color>(
                riskColor,
              ),
            ),
          ),

          const SizedBox(height: 7),

          // Scale Labels
          Row(
            mainAxisAlignment:
            MainAxisAlignment.spaceBetween,

            children: [
              Text(
                "0",
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade500,
                ),
              ),

              Text(
                "Risk level: $levelText",

                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: riskColor,
                ),
              ),

              Text(
                "100",
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SIGNAL TELEMETRY
  // ===========================================================================

  Widget _buildSignalTelemetryGrid() {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,

      children: [
        const Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 4,
            vertical: 2,
          ),

          child: Text(
            "Safety Signal Telemetry",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Voice + Movement
        Row(
          children: [
            Expanded(
              child: _buildSignalCard(
                title: "VOICE",

                status:
                _currentSnapshot.voiceState.label,

                detail:
                _currentSnapshot.lastSpokenWords !=
                    null
                    ? '"${_currentSnapshot.lastSpokenWords}"'
                    : _currentSnapshot
                    .voiceState
                    .detail,

                icon:
                Icons.record_voice_over_rounded,

                isWarning:
                _currentSnapshot.voiceState ==
                    VoiceSignalState.keywordDetected,

                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                      const VoiceDetectionScreen(),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: _buildSignalCard(
                title: "MOVEMENT",

                status:
                _currentSnapshot
                    .movementState
                    .label,

                detail:
                "${_currentSnapshot.movementIntensity.toStringAsFixed(1)} m/s²",

                icon:
                Icons.sensors_rounded,

                isWarning:
                _currentSnapshot.movementState ==
                    MovementSignalState.abnormal,

                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                      const MovementDetectionScreen(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // Location + Route
        Row(
          children: [
            Expanded(
              child: _buildSignalCard(
                title: "LOCATION",

                status:
                _currentSnapshot
                    .locationState
                    .label,

                detail:
                _currentSnapshot
                    .currentAddress ??
                    "Locating...",

                icon:
                Icons.location_on_rounded,

                isWarning:
                _currentSnapshot
                    .locationState ==
                    LocationSignalState.unavailable,

                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                      const LiveLocationScreen(),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: _buildSignalCard(
                title: "ROUTE",

                status:
                _currentSnapshot
                    .routeState
                    .label,

                detail:
                "${_currentSnapshot.currentSpeedKmh.toStringAsFixed(0)} km/h",

                icon:
                Icons.alt_route_rounded,

                isWarning:
                _currentSnapshot.routeState ==
                    RouteSignalState.unusual,
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // Network + Battery
        Row(
          children: [
            Expanded(
              child: _buildSignalCard(
                title: "NETWORK",

                status:
                _currentSnapshot
                    .networkState
                    .label,

                detail:
                _currentSnapshot
                    .networkState
                    .detail,

                icon:
                Icons.wifi_rounded,

                isWarning:
                _currentSnapshot.networkState ==
                    NetworkSignalState.disconnected,
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: _buildSignalCard(
                title: "BATTERY",

                status:
                _currentSnapshot
                    .batteryState
                    .label,

                detail:
                _currentSnapshot
                    .batteryState
                    .detail,

                icon:
                Icons.battery_charging_full_rounded,

                isWarning:
                _currentSnapshot.batteryState ==
                    BatterySignalState.low,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ===========================================================================
  // INDIVIDUAL SIGNAL CARD
  // ===========================================================================

  Widget _buildSignalCard({
    required String title,
    required String status,
    required String detail,
    required IconData icon,
    bool isWarning = false,
    VoidCallback? onTap,
  }) {
    final Color cardColor =
    isWarning
        ? Colors.red.shade50
        : Colors.white;

    final Color iconColor =
    isWarning
        ? Colors.red
        : Colors.deepPurple;

    final Color statusColor =
    isWarning
        ? Colors.red.shade700
        : Colors.black87;

    return InkWell(
      onTap: onTap,
      borderRadius:
      BorderRadius.circular(16),

      child: Container(
        height: 120,
        padding: const EdgeInsets.all(12),

        decoration: BoxDecoration(
          color: cardColor,
          borderRadius:
          BorderRadius.circular(16),

          border: Border.all(
            color:
            isWarning
                ? Colors.red.withValues(
              alpha: 0.4,
            )
                : Colors.grey.shade200,

            width:
            isWarning
                ? 1.5
                : 1.0,
          ),

          boxShadow: [
            BoxShadow(
              color:
              Colors.black.withValues(
                alpha: 0.03,
              ),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),

        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,

          mainAxisAlignment:
          MainAxisAlignment.spaceBetween,

          children: [
            Row(
              mainAxisAlignment:
              MainAxisAlignment.spaceBetween,

              children: [
                Text(
                  title,

                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                    letterSpacing: 0.5,
                  ),
                ),

                Icon(
                  icon,
                  size: 18,
                  color: iconColor,
                ),
              ],
            ),

            Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,

              children: [
                Text(
                  status,

                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),

                  maxLines: 1,
                  overflow:
                  TextOverflow.ellipsis,
                ),

                const SizedBox(height: 2),

                Text(
                  detail,

                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),

                  maxLines: 1,
                  overflow:
                  TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // DECISION INSIGHTS
  // ===========================================================================

  Widget _buildDecisionInsightsCard(
      Color stateColor,
      ) {
    return Container(
      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(20),

        border: Border.all(
          color: Colors.deepPurple.withValues(
            alpha: 0.15,
          ),
        ),

        boxShadow: [
          BoxShadow(
            color:
            Colors.black.withValues(
              alpha: 0.03,
            ),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,

        children: [
          const Row(
            children: [
              Icon(
                Icons.hub_rounded,
                size: 18,
                color: Colors.deepPurple,
              ),

              SizedBox(width: 8),

              Text(
                "Multi-Signal Decision Insights",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),

            decoration: BoxDecoration(
              color:
              stateColor.withValues(
                alpha: 0.08,
              ),

              borderRadius:
              BorderRadius.circular(12),

              border: Border.all(
                color:
                stateColor.withValues(
                  alpha: 0.2,
                ),
              ),
            ),

            child: Text(
              _currentSnapshot.decisionReason,

              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade900,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // PROTECTION BUTTON
  // ===========================================================================

  Widget _buildProtectionActionButton() {
    final isActive =
        _currentSnapshot.isProtectionActive;

    return SizedBox(
      height: 56,

      child: ElevatedButton.icon(
        onPressed: () {
          if (isActive) {
            _guardianService.stopProtection();
          } else {
            _guardianService.startProtection();
          }
        },

        style: ElevatedButton.styleFrom(
          backgroundColor:
          isActive
              ? Colors.deepOrange.shade600
              : Colors.deepPurple,

          foregroundColor: Colors.white,

          elevation: 4,

          shape:
          RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(18),
          ),
        ),

        icon: Icon(
          isActive
              ? Icons.stop_circle_rounded
              : Icons.security_rounded,
          size: 24,
        ),

        label: Text(
          isActive
              ? "STOP PROTECTION"
              : "START PROTECTION",

          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // MANUAL SOS
  // ===========================================================================

  Widget _buildManualSosTriggerButton() {
    return SizedBox(
      height: 52,

      child: OutlinedButton.icon(
        onPressed: () {
          _guardianService.triggerManualSos();

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
              const SosScreen(),
            ),
          );
        },

        style: OutlinedButton.styleFrom(
          foregroundColor:
          Colors.red.shade700,

          side: BorderSide(
            color: Colors.red.shade400,
            width: 1.5,
          ),

          shape:
          RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(18),
          ),
        ),

        icon: const Icon(
          Icons.warning_rounded,
          size: 22,
        ),

        label: const Text(
          "TRIGGER MANUAL SOS",

          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // SIMULATION BOTTOM SHEET
  // ===========================================================================

  void _showSimulationBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,

      shape:
      const RoundedRectangleBorder(
        borderRadius:
        BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),

      builder: (ctx) {
        return StatefulBuilder(
          builder:
              (context, setModalState) {
            return Padding(
              padding:
              const EdgeInsets.all(20),

              child: Column(
                mainAxisSize:
                MainAxisSize.min,

                crossAxisAlignment:
                CrossAxisAlignment.start,

                children: [
                  Row(
                    mainAxisAlignment:
                    MainAxisAlignment
                        .spaceBetween,

                    children: [
                      const Expanded(
                        child: Text(
                          "Simulate Signals & Verify Decision",

                          style: TextStyle(
                            fontSize: 16,
                            fontWeight:
                            FontWeight.bold,
                            color:
                            Colors.deepPurple,
                          ),
                        ),
                      ),

                      IconButton(
                        icon:
                        const Icon(
                          Icons.close,
                        ),
                        onPressed:
                            () =>
                            Navigator.pop(
                              ctx,
                            ),
                      ),
                    ],
                  ),

                  const Text(
                    "Inject simulated signals to test multi-signal fusion in real time:",

                    style: TextStyle(
                      fontSize: 12.5,
                      color:
                      Colors.black54,
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Normal
                  _buildSimButton(
                    title:
                    "🟢 Reset All Signals to Normal",

                    subtitle:
                    "Safe baseline",

                    onTap: () {
                      _guardianService
                          .updateVoiceSignal(
                        state:
                        VoiceSignalState
                            .normal,
                        recognizedWords:
                        null,
                      );

                      _guardianService
                          .updateMovementSignal(
                        state:
                        MovementSignalState
                            .normal,
                        intensity:
                        1.2,
                      );

                      _guardianService
                          .updateRouteSignal(
                        RouteSignalState
                            .normal,
                      );

                      _guardianService
                          .cancelManualSos();

                      Navigator.pop(ctx);
                    },
                  ),

                  // High Movement
                  _buildSimButton(
                    title:
                    "🟡 High Movement Only",

                    subtitle:
                    "Yields ATTENTION state (no emergency)",

                    onTap: () {
                      _guardianService
                          .updateMovementSignal(
                        state:
                        MovementSignalState
                            .high,
                        intensity:
                        15.0,
                      );

                      Navigator.pop(ctx);
                    },
                  ),

                  // Voice + Movement
                  _buildSimButton(
                    title:
                    "🟠 Voice Keyword + Abnormal Movement",

                    subtitle:
                    "Yields POTENTIAL EMERGENCY",

                    onTap: () {
                      _guardianService
                          .updateVoiceSignal(
                        state:
                        VoiceSignalState
                            .keywordDetected,
                        recognizedWords:
                        "help me please",
                      );

                      _guardianService
                          .updateMovementSignal(
                        state:
                        MovementSignalState
                            .abnormal,
                        intensity:
                        24.5,
                      );

                      Navigator.pop(ctx);
                    },
                  ),

                  // Route + Movement
                  _buildSimButton(
                    title:
                    "🟠 Unusual Route + Abnormal Movement",

                    subtitle:
                    "Yields POTENTIAL EMERGENCY",

                    onTap: () {
                      _guardianService
                          .updateRouteSignal(
                        RouteSignalState
                            .unusual,

                        reason:
                        "Sudden high speed deviation off established route.",
                      );

                      _guardianService
                          .updateMovementSignal(
                        state:
                        MovementSignalState
                            .abnormal,
                        intensity:
                        22.0,
                      );

                      Navigator.pop(ctx);
                    },
                  ),

                  // Manual SOS
                  _buildSimButton(
                    title:
                    "🔴 Manual SOS Event",

                    subtitle:
                    "Yields EMERGENCY",

                    onTap: () {
                      _guardianService
                          .triggerManualSos(
                        reason:
                        "Simulated SOS button tap.",
                      );

                      Navigator.pop(ctx);
                    },
                  ),

                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // SIMULATION BUTTON
  // ===========================================================================

  Widget _buildSimButton({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding:
      const EdgeInsets.only(
        bottom: 8,
      ),

      child: InkWell(
        onTap: onTap,

        borderRadius:
        BorderRadius.circular(12),

        child: Container(
          width: double.infinity,
          padding:
          const EdgeInsets.all(12),

          decoration: BoxDecoration(
            color:
            const Color(0xFFF9FAFB),

            borderRadius:
            BorderRadius.circular(12),

            border: Border.all(
              color:
              Colors.grey.shade300,
            ),
          ),

          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,

            children: [
              Text(
                title,

                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight:
                  FontWeight.bold,
                  color:
                  Colors.black87,
                ),
              ),

              const SizedBox(height: 2),

              Text(
                subtitle,

                style: TextStyle(
                  fontSize: 11.5,
                  color:
                  Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // ARCHITECTURE DIALOG
  // ===========================================================================

  void _showArchitectureDialog() {
    showDialog(
      context: context,

      builder: (ctx) {
        return AlertDialog(
          shape:
          RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(20),
          ),

          title: const Row(
            children: [
              Icon(
                Icons.shield_rounded,
                color:
                Colors.deepPurple,
              ),

              SizedBox(width: 8),

              Text(
                "AI Guardian Engine",

                style: TextStyle(
                  fontWeight:
                  FontWeight.bold,
                ),
              ),
            ],
          ),

          content:
          const SingleChildScrollView(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,

              mainAxisSize:
              MainAxisSize.min,

              children: [
                Text(
                  "Multi-Signal Safety Architecture:",

                  style: TextStyle(
                    fontWeight:
                    FontWeight.bold,
                    fontSize: 13,
                  ),
                ),

                SizedBox(height: 8),

                Text(
                  "• 🟢 SAFE: Normal movement, stable GPS, no voice trigger.",
                ),

                SizedBox(height: 4),

                Text(
                  "• 🟡 ATTENTION: Single isolated signal anomaly (e.g. brisk movement or route deviation).",
                ),

                SizedBox(height: 4),

                Text(
                  "• 🟠 POTENTIAL EMERGENCY: Correlated signals (e.g., unusual route + abnormal violent motion).",
                ),

                SizedBox(height: 4),

                Text(
                  "• 🔴 EMERGENCY: Manual SOS or multi-confirmed emergency.",
                ),

                SizedBox(height: 4),

                Text(
                  "• ⚠️ PROTECTION INTERRUPTED: Sensor stream loss or heartbeat timeout.",
                ),

                SizedBox(height: 12),

                Text(
                  "Objective & Neutral:\nNo false alarms or speculative threat claims. The system transparently correlates multiple sensor feeds.",

                  style: TextStyle(
                    fontSize: 12,
                    color:
                    Colors.black87,
                  ),
                ),
              ],
            ),
          ),

          actions: [
            TextButton(
              onPressed:
                  () =>
                  Navigator.pop(ctx),

              child: const Text(
                "Got It",

                style: TextStyle(
                  color:
                  Colors.deepPurple,
                  fontWeight:
                  FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}