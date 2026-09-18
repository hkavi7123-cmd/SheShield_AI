import 'dart:async';
import 'package:flutter/material.dart';
import 'smart_movement_detection_service.dart';
import 'ai_guardian_screen.dart';

/// Professional Smart Movement Detection Screen for SheShield AI.
///
/// Multi-stage sensor validation:
/// Movement detected -> Check duration -> Check GPS -> Check voice -> AI decision
class SmartMovementDetectionScreen extends StatefulWidget {
  const SmartMovementDetectionScreen({super.key});

  @override
  State<SmartMovementDetectionScreen> createState() =>
      _SmartMovementDetectionScreenState();
}

class _SmartMovementDetectionScreenState
    extends State<SmartMovementDetectionScreen>
    with SingleTickerProviderStateMixin {
  final SmartMovementDetectionService _service =
      SmartMovementDetectionService.instance;
  late StreamSubscription<SmartMovementSnapshot> _subscription;
  late SmartMovementSnapshot _currentSnapshot;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _currentSnapshot = _service.snapshot;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _subscription = _service.stream.listen((snapshot) {
      if (!mounted) return;
      setState(() {
        _currentSnapshot = snapshot;
      });
    });

    // Auto-start monitoring when screen is opened
    _service.startMonitoring();
  }

  @override
  void dispose() {
    _subscription.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Color _getDecisionColor(MovementDecision decision) {
    switch (decision) {
      case MovementDecision.safe:
        return const Color(0xFF10B981); // Emerald Green
      case MovementDecision.attention:
        return const Color(0xFFF59E0B); // Amber
      case MovementDecision.potentialEmergency:
        return const Color(0xFFF97316); // Deep Orange
    }
  }

  IconData _getDecisionIcon(MovementDecision decision) {
    switch (decision) {
      case MovementDecision.safe:
        return Icons.verified_user_rounded;
      case MovementDecision.attention:
        return Icons.warning_amber_rounded;
      case MovementDecision.potentialEmergency:
        return Icons.emergency_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final decision = _currentSnapshot.decision;
    final decisionColor = _getDecisionColor(decision);
    final isElevated = decision != MovementDecision.safe;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F3FF), // Light purple background
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        title: const Text(
          "Smart Movement Detection",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: "How it works",
            onPressed: _showExplanationDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Core Safety Rule Notice Banner
              _buildSafetyRuleBanner(),

              const SizedBox(height: 14),

              // 2. Primary Decision Hero Card
              _buildDecisionHeroCard(decision, decisionColor, isElevated),

              const SizedBox(height: 14),

              // 3. Movement & Duration Analysis Card
              _buildMovementDurationAnalysisCard(),

              const SizedBox(height: 14),

              // 4. Supporting Context Checks Grid (Sensors, GPS, Voice)
              _buildSupportingContextGrid(),

              const SizedBox(height: 14),

              // 5. Transparent Explainable Decision Breakdown
              _buildExplainableDecisionBreakdown(decisionColor),

              const SizedBox(height: 20),

              // 6. Action Control Button (Start / Stop Monitoring)
              _buildMonitoringActionButton(),

              const SizedBox(height: 12),

              // 7. Shortcut to central AI Guardian
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

  /// Important Safety Rule Disclaimer Banner
  Widget _buildSafetyRuleBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.deepPurple.withValues(alpha: 0.2),
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
              Icons.shield_outlined,
              color: Colors.deepPurple,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Phone shake alone will not trigger an SOS.",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  "Movement is verified across duration, GPS, and voice signals before evaluating safety.",
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

  /// Decision Hero Card
  Widget _buildDecisionHeroCard(
    MovementDecision decision,
    Color decisionColor,
    bool isElevated,
  ) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: isElevated ? _pulseAnimation.value : 1.0,
          child: child,
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: decisionColor.withValues(alpha: 0.35),
            width: isElevated ? 2.5 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: decisionColor.withValues(alpha: isElevated ? 0.22 : 0.08),
              blurRadius: isElevated ? 18 : 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: _currentSnapshot.isMonitoring
                        ? Colors.deepPurple.withValues(alpha: 0.1)
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _currentSnapshot.isMonitoring
                              ? Colors.green
                              : Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _currentSnapshot.isMonitoring
                            ? "SMART MONITORING ON"
                            : "MONITORING OFF",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _currentSnapshot.isMonitoring
                              ? Colors.deepPurple
                              : Colors.grey.shade700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  decision.emoji,
                  style: const TextStyle(fontSize: 24),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: decisionColor.withValues(alpha: 0.12),
                border: Border.all(
                  color: decisionColor.withValues(alpha: 0.25),
                  width: 2,
                ),
              ),
              child: Icon(
                _getDecisionIcon(decision),
                size: 52,
                color: decisionColor,
              ),
            ),

            const SizedBox(height: 14),

            Text(
              decision.label.toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: decisionColor,
                letterSpacing: 0.5,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              decision.description,
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

  /// Movement & Duration Analysis Card
  Widget _buildMovementDurationAnalysisCard() {
    double intensityRatio =
        (_currentSnapshot.currentIntensity / 25.0).clamp(0.0, 1.0);
    double durationSeconds = _currentSnapshot.sustainedDurationMs / 1000.0;
    double durationRatio = (durationSeconds / 4.0).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Movement & Duration Analysis",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _currentSnapshot.movementState.label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Intensity Gauge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Instantaneous Intensity",
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
              Text(
                "${_currentSnapshot.currentIntensity.toStringAsFixed(1)} m/s²",
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _currentSnapshot.isMonitoring ? intensityRatio : 0.0,
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                _getDecisionColor(_currentSnapshot.decision),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Sustained Duration Gauge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Sustained Movement Duration",
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
              Text(
                "${durationSeconds.toStringAsFixed(1)}s (Observed)",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: durationSeconds > 2.0
                      ? Colors.orange.shade800
                      : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _currentSnapshot.isMonitoring ? durationRatio : 0.0,
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                durationSeconds >= 2.5
                    ? Colors.deepOrange
                    : Colors.deepPurple.shade400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Supporting Context Grid (Sensors, GPS, Voice)
  Widget _buildSupportingContextGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Text(
            "Multi-Signal Context Verification",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Row 1: Accelerometer & Gyroscope
        Row(
          children: [
            Expanded(
              child: _buildContextTile(
                title: "ACCELEROMETER",
                status: _currentSnapshot.isAccelAvailable ? "Active" : "Unavailable",
                detail: "Peak: ${_currentSnapshot.peakIntensity.toStringAsFixed(1)} m/s²",
                icon: Icons.speed_rounded,
                isOk: _currentSnapshot.isAccelAvailable,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildContextTile(
                title: "GYROSCOPE",
                status: _currentSnapshot.isGyroAvailable ? "Active" : "Unavailable",
                detail: _currentSnapshot.gyroStatusText,
                icon: Icons.screen_rotation_rounded,
                isOk: _currentSnapshot.isGyroAvailable,
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // Row 2: GPS Check & Voice Check
        Row(
          children: [
            Expanded(
              child: _buildContextTile(
                title: "GPS SIGNAL",
                status: _currentSnapshot.isGpsAvailable ? "Connected" : "Standby",
                detail: _currentSnapshot.gpsStatusText,
                icon: Icons.location_on_rounded,
                isOk: _currentSnapshot.isGpsAvailable,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildContextTile(
                title: "VOICE SIGNAL",
                status: _currentSnapshot.isVoiceKeywordPresent ? "Triggered" : "Normal",
                detail: _currentSnapshot.voiceStatusText,
                icon: Icons.mic_rounded,
                isOk: !_currentSnapshot.isVoiceKeywordPresent,
                isAlert: _currentSnapshot.isVoiceKeywordPresent,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildContextTile({
    required String title,
    required String status,
    required String detail,
    required IconData icon,
    bool isOk = true,
    bool isAlert = false,
  }) {
    Color iconColor = isAlert
        ? Colors.red
        : (isOk ? Colors.deepPurple : Colors.orange.shade800);

    return Container(
      height: 105,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isAlert ? Colors.red.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAlert ? Colors.red.shade300 : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
              Icon(icon, size: 17, color: iconColor),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                status,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isAlert ? Colors.red.shade800 : Colors.black87,
                ),
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

  /// Transparent Explainable Decision Breakdown
  Widget _buildExplainableDecisionBreakdown(Color decisionColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.deepPurple.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.psychology_alt_rounded, size: 20, color: Colors.deepPurple),
              SizedBox(width: 8),
              Text(
                "Smart Decision Explanation",
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
              color: decisionColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: decisionColor.withValues(alpha: 0.2),
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

  /// Action Control Button (Start / Stop Monitoring)
  Widget _buildMonitoringActionButton() {
    final isMonitoring = _currentSnapshot.isMonitoring;

    return SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        onPressed: () {
          if (isMonitoring) {
            _service.stopMonitoring();
          } else {
            _service.startMonitoring();
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isMonitoring ? Colors.red.shade600 : Colors.deepPurple,
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
          isMonitoring ? "STOP MONITORING" : "START MONITORING",
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  /// Shortcut button to central AI Guardian
  Widget _buildAIGuardianShortcutButton() {
    return SizedBox(
      height: 50,
      child: OutlinedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AIGuardianScreen(),
            ),
          );
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.deepPurple,
          side: const BorderSide(color: Colors.deepPurple, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        icon: const Icon(Icons.shield_rounded, size: 20),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.directions_run_rounded, color: Colors.deepPurple),
            SizedBox(width: 8),
            Text(
              "Smart Movement Logic",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Multi-Stage Validation Pipeline:",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              SizedBox(height: 8),
              Text("1. Movement Detected (via sensors_plus)"),
              SizedBox(height: 4),
              Text("2. Duration Check: Brief shakes (< 2.5s) are classified SAFE."),
              SizedBox(height: 4),
              Text("3. GPS Check: Verifies travel speed and position continuity."),
              SizedBox(height: 4),
              Text("4. Voice Check: Ingests verified emergency speech keywords."),
              SizedBox(height: 4),
              Text("5. AI Decision: Combines all signals without single-sensor false alarms."),
              SizedBox(height: 12),
              Text(
                "Safety Principle:\nPhone shaking alone will NEVER directly trigger an SOS.",
                style: TextStyle(fontSize: 12, color: Colors.black87),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
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
