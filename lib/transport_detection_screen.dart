import 'dart:async';
import 'package:flutter/material.dart';
import 'transport_detection_service.dart';
import 'ai_guardian_screen.dart';

/// Professional Material 3 Screen for Transport Detection in SheShield AI.
///
/// Filters normal transit movements (vibrations, braking, turns, speed breakers)
/// to prevent false alarms while travelling in Auto, Bike, Car, Bus, or Train.
class TransportDetectionScreen extends StatefulWidget {
  const TransportDetectionScreen({super.key});

  @override
  State<TransportDetectionScreen> createState() =>
      _TransportDetectionScreenState();
}

class _TransportDetectionScreenState extends State<TransportDetectionScreen>
    with SingleTickerProviderStateMixin {
  final TransportDetectionService _service =
      TransportDetectionService.instance;

  late StreamSubscription<TransportDetectionSnapshot> _subscription;
  late TransportDetectionSnapshot _currentSnapshot;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();

    _currentSnapshot = _service.snapshot;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
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

    _subscription = _service.stream.listen((snapshot) {
      if (!mounted || _isDisposed) return;

      setState(() {
        _currentSnapshot = snapshot;
      });
    });

    // Start monitoring only after the first frame is completely built.
    // This prevents the AI Guardian notification from occurring
    // during the widget build phase.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isDisposed) return;

      _startMonitoringSafely();
    });
  }

  // startMonitoring() returns void, so DO NOT use await here.
  void _startMonitoringSafely() {
    if (!mounted || _isDisposed) return;

    try {
      _service.startMonitoring();
    } catch (e) {
      debugPrint(
        'Transport Detection startMonitoring error: $e',
      );
    }
  }

  @override
  void dispose() {
    _isDisposed = true;

    _subscription.cancel();

    _pulseController.dispose();

    super.dispose();
  }

  Color _getSafetyStateColor(TransportSafetyState state) {
    switch (state) {
      case TransportSafetyState.safe:
        return const Color(0xFF10B981);

      case TransportSafetyState.attention:
        return const Color(0xFFF59E0B);

      case TransportSafetyState.potentialEmergency:
        return const Color(0xFFF97316);
    }
  }

  IconData _getSafetyStateIcon(TransportSafetyState state) {
    switch (state) {
      case TransportSafetyState.safe:
        return Icons.verified_user_rounded;

      case TransportSafetyState.attention:
        return Icons.warning_amber_rounded;

      case TransportSafetyState.potentialEmergency:
        return Icons.emergency_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final safetyState = _currentSnapshot.safetyState;

    final stateColor = _getSafetyStateColor(safetyState);

    final isElevated =
        safetyState != TransportSafetyState.safe;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F3FF),

      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        title: const Text(
          "Transport Detection",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.info_outline_rounded,
            ),
            tooltip: "Transit Safety Logic",
            onPressed: _showExplanationDialog,
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
            crossAxisAlignment:
            CrossAxisAlignment.stretch,
            children: [
              _buildTransitRuleBanner(),

              const SizedBox(height: 14),

              _buildSafetyHeroCard(
                safetyState,
                stateColor,
                isElevated,
              ),

              const SizedBox(height: 14),

              _buildTransitTelemetryGrid(),

              const SizedBox(height: 14),

              _buildExplainableDecisionCard(
                stateColor,
              ),

              const SizedBox(height: 14),

              _buildRouteSimulationBar(),

              const SizedBox(height: 20),

              _buildMonitoringActionButton(),

              const SizedBox(height: 12),

              _buildAIGuardianShortcutButton(),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // WIDGET BUILDERS
  // ===========================================================================

  Widget _buildTransitRuleBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.deepPurple.withValues(
            alpha: 0.2,
          ),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.deepPurple.shade100,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.commute_rounded,
              color: Colors.deepPurple,
              size: 20,
            ),
          ),

          const SizedBox(width: 10),

          const Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  "Normal travelling motion will not trigger an emergency.",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),

                SizedBox(height: 2),

                Text(
                  "Road bumps, speed breakers, braking, and transit vibrations are filtered to prevent false alarms.",
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.black87,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyHeroCard(
      TransportSafetyState state,
      Color stateColor,
      bool isElevated,
      ) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: isElevated
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
            color: stateColor.withValues(
              alpha: 0.35,
            ),
            width: isElevated ? 2.5 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: stateColor.withValues(
                alpha: isElevated ? 0.22 : 0.08,
              ),
              blurRadius: isElevated ? 18 : 10,
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
                    color: _currentSnapshot.isMonitoring
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
                          _currentSnapshot.isMonitoring
                              ? Colors.green
                              : Colors.grey,
                        ),
                      ),

                      const SizedBox(width: 6),

                      Text(
                        _currentSnapshot.isMonitoring
                            ? "TRANSPORT MONITORING ON"
                            : "MONITORING OFF",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color:
                          _currentSnapshot.isMonitoring
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
              padding: const EdgeInsets.all(20),
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
                _getSafetyStateIcon(state),
                size: 52,
                color: stateColor,
              ),
            ),

            const SizedBox(height: 14),

            Text(
              state.label,
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

  Widget _buildTransitTelemetryGrid() {
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
            "Live Transit Telemetry",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),

        const SizedBox(height: 8),

        Row(
          children: [
            Expanded(
              child: _buildTelemetryCard(
                title: "TRANSPORT STATUS",
                status:
                _currentSnapshot.transportState.label,
                detail:
                "${_currentSnapshot.currentSpeedKmh.toStringAsFixed(0)} km/h • ${_currentSnapshot.transportState.detail}",
                icon:
                Icons.directions_car_rounded,
                isAlert: false,
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: _buildTelemetryCard(
                title: "ROUTE STATUS",
                status:
                _currentSnapshot.routeBehaviour.label,
                detail:
                _currentSnapshot.routeBehaviour.detail,
                icon: Icons.alt_route_rounded,
                isAlert:
                _currentSnapshot.routeBehaviour ==
                    RouteBehaviour.unexpected,
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              child: _buildTelemetryCard(
                title: "MOVEMENT CONTEXT",
                status:
                _currentSnapshot.isRoadVibrationFiltered
                    ? "Normal (Vibration Filter Active)"
                    : "${_currentSnapshot.movementIntensity.toStringAsFixed(1)} m/s²",
                detail:
                _currentSnapshot.isRoadVibrationFiltered
                    ? "Road bumps & engine motion absorbed"
                    : "Standard motion baseline",
                icon: Icons.vibration_rounded,
                isAlert: false,
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: _buildTelemetryCard(
                title: "VOICE SIGNAL",
                status:
                _currentSnapshot.isVoiceEmergency
                    ? "Emergency Keyword Detected"
                    : "No Emergency Signal",
                detail:
                _currentSnapshot.voiceSpokenWords !=
                    null
                    ? '"${_currentSnapshot.voiceSpokenWords}"'
                    : "Listening baseline",
                icon:
                Icons.record_voice_over_rounded,
                isAlert:
                _currentSnapshot.isVoiceEmergency,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTelemetryCard({
    required String title,
    required String status,
    required String detail,
    required IconData icon,
    bool isAlert = false,
  }) {
    final cardColor =
    isAlert ? Colors.red.shade50 : Colors.white;

    final iconColor =
    isAlert ? Colors.red : Colors.deepPurple;

    final statusColor =
    isAlert ? Colors.red.shade800 : Colors.black87;

    return Container(
      height: 115,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAlert
              ? Colors.red.shade300
              : Colors.grey.shade200,
          width: isAlert ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
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
                  fontSize: 10.5,
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
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 2),

              Text(
                detail,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExplainableDecisionCard(
      Color stateColor,
      ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.deepPurple.withValues(
            alpha: 0.15,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
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
                Icons.psychology_rounded,
                size: 20,
                color: Colors.deepPurple,
              ),

              SizedBox(width: 8),

              Text(
                "Transit Safety Decision Explanation",
                style: TextStyle(
                  fontSize: 14.5,
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
              color: stateColor.withValues(
                alpha: 0.08,
              ),
              borderRadius:
              BorderRadius.circular(12),
              border: Border.all(
                color: stateColor.withValues(
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

  Widget _buildRouteSimulationBar() {
    final isUnexpected =
        _currentSnapshot.routeBehaviour ==
            RouteBehaviour.unexpected;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Row(
        mainAxisAlignment:
        MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              const Text(
                "Simulate Route Deviation",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 2),

              Text(
                isUnexpected
                    ? "Status: Unexpected Route"
                    : "Status: Normal Route",
                style: TextStyle(
                  fontSize: 11.5,
                  color: isUnexpected
                      ? Colors.orange.shade800
                      : Colors.grey.shade600,
                ),
              ),
            ],
          ),

          Switch(
            value: isUnexpected,
            activeThumbColor: Colors.deepOrange,
            activeTrackColor:
            Colors.deepOrange.shade200,
            onChanged: (val) {
              _service.setSimulatedRouteBehaviour(
                val
                    ? RouteBehaviour.unexpected
                    : RouteBehaviour.normal,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMonitoringActionButton() {
    final isMonitoring =
        _currentSnapshot.isMonitoring;

    return SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        onPressed: () {
          if (_isDisposed) return;

          if (isMonitoring) {
            _service.stopMonitoring();
          } else {
            _startMonitoringSafely();
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: isMonitoring
              ? Colors.red.shade600
              : Colors.deepPurple,
          foregroundColor: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        icon: Icon(
          isMonitoring
              ? Icons.stop_circle_rounded
              : Icons.play_circle_fill_rounded,
          size: 24,
        ),
        label: Text(
          isMonitoring
              ? "STOP TRANSPORT MONITORING"
              : "START TRANSPORT MONITORING",
          style: const TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildAIGuardianShortcutButton() {
    return SizedBox(
      height: 50,
      child: OutlinedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
              const AIGuardianScreen(),
            ),
          );
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.deepPurple,
          side: const BorderSide(
            color: Colors.deepPurple,
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        icon: const Icon(
          Icons.shield_rounded,
          size: 20,
        ),
        label: const Text(
          "VIEW CENTRAL AI GUARDIAN",
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  void _showExplanationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(
              Icons.commute_rounded,
              color: Colors.deepPurple,
            ),

            SizedBox(width: 8),

            Text(
              "Transport Safety Logic",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "False-Alarm Prevention in Transit:",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),

              SizedBox(height: 8),

              Text(
                "• 🟢 SAFE: Normal travelling in auto, bike, car, bus, or train. Vehicle vibrations, turns, and braking are safely filtered.",
              ),

              SizedBox(height: 4),

              Text(
                "• 🟡 ATTENTION: Unexpected route deviation detected. System raises attention level while continuing monitoring.",
              ),

              SizedBox(height: 4),

              Text(
                "• 🟠 POTENTIAL EMERGENCY: Unexpected route combined with emergency voice keyword and violent abnormal movement.",
              ),

              SizedBox(height: 12),

              Text(
                "Zero False Alarms:\nPhone or vehicle movement alone will NEVER trigger an SOS.",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx),
            child: const Text(
              "Got It",
              style: TextStyle(
                color: Colors.deepPurple,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}