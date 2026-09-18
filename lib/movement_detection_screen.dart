import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'ai_guardian_service.dart';

/// Movement status states for SheShield AI safety monitoring.
enum MovementStatus {
  normal,
  light,
  high,
  abnormal;

  String get label {
    switch (this) {
      case MovementStatus.normal:
        return "Normal Movement";
      case MovementStatus.light:
        return "Light Movement";
      case MovementStatus.high:
        return "High Movement";
      case MovementStatus.abnormal:
        return "Abnormal / Sudden Movement";
    }
  }

  String get emoji {
    switch (this) {
      case MovementStatus.normal:
        return "🟢";
      case MovementStatus.light:
        return "🟡";
      case MovementStatus.high:
        return "🟠";
      case MovementStatus.abnormal:
        return "🔴";
    }
  }

  Color get color {
    switch (this) {
      case MovementStatus.normal:
        return const Color(0xFF10B981); // Emerald Green
      case MovementStatus.light:
        return const Color(0xFFF59E0B); // Amber / Yellow
      case MovementStatus.high:
        return const Color(0xFFF97316); // Deep Orange
      case MovementStatus.abnormal:
        return const Color(0xFFEF4444); // Bright Red
    }
  }

  IconData get icon {
    switch (this) {
      case MovementStatus.normal:
        return Icons.check_circle_rounded;
      case MovementStatus.light:
        return Icons.directions_walk_rounded;
      case MovementStatus.high:
        return Icons.directions_run_rounded;
      case MovementStatus.abnormal:
        return Icons.warning_amber_rounded;
    }
  }

  String get description {
    switch (this) {
      case MovementStatus.normal:
        return "Phone is stable or resting safely. No significant motion detected.";
      case MovementStatus.light:
        return "Gentle handling, holding, or slight motion detected.";
      case MovementStatus.high:
        return "Rapid motion, brisk walking, or moderate physical activity detected.";
      case MovementStatus.abnormal:
        return "Abnormal multi-spike motion or violent acceleration detected!";
    }
  }
}

/// Sensitivity profile presets for movement threshold tuning.
enum SensitivityLevel {
  low("Low Sensitivity", 22.0, 18.0, 8.0, 3.5),
  balanced("Balanced (Default)", 18.5, 14.0, 6.5, 2.5),
  high("High Sensitivity", 15.0, 10.5, 5.0, 1.8);

  final String title;
  final double abnormalThreshold;
  final double highThreshold;
  final double lightThreshold;
  final double normalThreshold;

  const SensitivityLevel(
    this.title,
    this.abnormalThreshold,
    this.highThreshold,
    this.lightThreshold,
    this.normalThreshold,
  );
}

/// Movement Detection Screen for SheShield AI.
///
/// Continuously monitors phone motion using accelerometer and gyroscope sensors
/// to detect abnormal/sudden movement patterns. Exposes [MovementStatus.abnormal]
/// for the Multi-Signal Emergency Decision Engine without triggering false alarms.
class MovementDetectionScreen extends StatefulWidget {
  /// Optional callback for listening to movement status changes.
  final void Function(MovementStatus status, double intensity)? onStatusChanged;

  /// Optional callback invoked specifically when abnormal movement is verified.
  final void Function(double peakIntensity)? onAbnormalMovementDetected;

  const MovementDetectionScreen({
    super.key,
    this.onStatusChanged,
    this.onAbnormalMovementDetected,
  });

  @override
  State<MovementDetectionScreen> createState() => _MovementDetectionScreenState();
}

class _MovementDetectionScreenState extends State<MovementDetectionScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // Sensor Subscriptions
  StreamSubscription<UserAccelerometerEvent>? _userAccelSubscription;
  StreamSubscription<AccelerometerEvent>? _accelFallbackSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;

  // Monitoring State
  bool _isMonitoring = false;
  bool _isAccelAvailable = false;
  bool _isGyroAvailable = false;
  String _gyroStatusText = "Initializing...";

  // Real-time Sensor Values
  double _accelX = 0.0;
  double _accelY = 0.0;
  double _accelZ = 0.0;
  double _currentIntensity = 0.0; // Current calculated net intensity (m/s^2)
  double _smoothedIntensity = 0.0; // Smoothed intensity for stable UI display
  double _peakIntensity = 0.0; // Peak intensity recorded during session

  double _gyroX = 0.0;
  double _gyroY = 0.0;
  double _gyroZ = 0.0;
  double _gyroRotationSpeed = 0.0; // Rad/s rotational velocity

  // Movement Evaluation & Safety States
  MovementStatus _currentStatus = MovementStatus.normal;
  SensitivityLevel _selectedSensitivity = SensitivityLevel.balanced;

  // Multi-Factor Detection Buffers & Cooldown
  final List<int> _highSpikeTimestamps = [];
  final int _spikeWindowMs = 1800; // Time window to count consecutive spikes
  final int _minSpikesForAbnormal = 3; // Minimum spikes within window for abnormal
  final int _cooldownDurationMs = 3500; // Cooldown after abnormal trigger
  int _lastAbnormalTriggerTimestamp = 0;
  int _abnormalEventCount = 0;

  // Animation controller for pulsing abnormal indicator
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Auto-start monitoring when screen opens
    _startMonitoring();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isMonitoring) {
      // Re-subscribe if needed
      _subscribeToAccelerometer();
      _subscribeToGyroscope();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopMonitoring();
    _pulseController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // SENSOR SUBSCRIPTION & MONITORING CONTROL (SAFE LIFECYCLE)
  // ===========================================================================

  /// Starts listening to phone motion sensors.
  void _startMonitoring() {
    if (_isMonitoring) return;

    _highSpikeTimestamps.clear();

    setState(() {
      _isMonitoring = true;
      _currentStatus = MovementStatus.normal;
    });

    _subscribeToAccelerometer();
    _subscribeToGyroscope();
  }

  /// Subscribes to linear acceleration (UserAccelerometer) with fallback.
  void _subscribeToAccelerometer() {
    _userAccelSubscription?.cancel();
    _accelFallbackSubscription?.cancel();

    try {
      // UserAccelerometer isolates dynamic user movement by filtering gravity (9.8 m/s^2)
      _userAccelSubscription = userAccelerometerEventStream().listen(
        (UserAccelerometerEvent event) {
          if (!mounted) return;
          _processAccelerometerData(event.x, event.y, event.z, isLinear: true);
        },
        onError: (error) {
          if (kDebugMode) {
            print("UserAccelerometer unavailable, falling back to standard Accelerometer: $error");
          }
          _fallbackToStandardAccelerometer();
        },
        cancelOnError: false,
      );

      if (mounted) {
        setState(() {
          _isAccelAvailable = true;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error initializing user accelerometer: $e");
      }
      _fallbackToStandardAccelerometer();
    }
  }

  /// Fallback to standard Accelerometer stream if userAccelerometer fails.
  void _fallbackToStandardAccelerometer() {
    try {
      _accelFallbackSubscription = accelerometerEventStream().listen(
        (AccelerometerEvent event) {
          if (!mounted) return;
          _processAccelerometerData(event.x, event.y, event.z, isLinear: false);
        },
        onError: (error) {
          if (!mounted) return;
          setState(() {
            _isAccelAvailable = false;
          });
        },
        cancelOnError: false,
      );

      if (mounted) {
        setState(() {
          _isAccelAvailable = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAccelAvailable = false;
        });
      }
    }
  }

  /// Subscribes to gyroscope sensor with graceful error handling.
  void _subscribeToGyroscope() {
    _gyroSubscription?.cancel();

    try {
      _gyroSubscription = gyroscopeEventStream().listen(
        (GyroscopeEvent event) {
          if (!mounted) return;
          _processGyroscopeData(event.x, event.y, event.z);
        },
        onError: (error) {
          if (!mounted) return;
          setState(() {
            _isGyroAvailable = false;
            _gyroStatusText = "Gyroscope unavailable on this device";
          });
        },
        cancelOnError: false,
      );

      if (mounted) {
        setState(() {
          _isGyroAvailable = true;
          _gyroStatusText = "Active & Streaming";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGyroAvailable = false;
          _gyroStatusText = "Gyroscope unavailable";
        });
      }
    }
  }

  /// Safely cancels all active sensor subscriptions and clears memory.
  void _stopMonitoring() {
    _userAccelSubscription?.cancel();
    _userAccelSubscription = null;

    _accelFallbackSubscription?.cancel();
    _accelFallbackSubscription = null;

    _gyroSubscription?.cancel();
    _gyroSubscription = null;

    _highSpikeTimestamps.clear();

    if (mounted) {
      setState(() {
        _isMonitoring = false;
        _currentIntensity = 0.0;
        _smoothedIntensity = 0.0;
        _gyroRotationSpeed = 0.0;
      });
    }
  }

  // ===========================================================================
  // MOVEMENT & ABNORMALITY CALCULATION ENGINE
  // ===========================================================================

  /// Processes accelerometer events and computes 3D net movement intensity.
  void _processAccelerometerData(
    double x,
    double y,
    double z, {
    required bool isLinear,
  }) {
    // 1. Calculate 3D magnitude
    double magnitude;
    if (isLinear) {
      // UserAccelerometer: net force vector
      magnitude = sqrt(x * x + y * y + z * z);
    } else {
      // Standard Accelerometer includes Earth's gravitational acceleration (9.80665 m/s^2)
      double rawMagnitude = sqrt(x * x + y * y + z * z);
      magnitude = (rawMagnitude - 9.80665).abs();
    }

    // 2. Exponential Moving Average (EMA) smoothing for stable UI visualization
    const double smoothingFactor = 0.25;
    double newSmoothed = (smoothingFactor * magnitude) +
        ((1.0 - smoothingFactor) * _smoothedIntensity);

    // 3. Peak tracker
    double newPeak = max(_peakIntensity, magnitude);

    // 4. Evaluate movement state and multi-factor abnormal condition
    MovementStatus evaluatedStatus = _evaluateMovementState(magnitude);

    if (mounted) {
      setState(() {
        _accelX = x;
        _accelY = y;
        _accelZ = z;
        _currentIntensity = magnitude;
        _smoothedIntensity = newSmoothed;
        _peakIntensity = newPeak;
        _currentStatus = evaluatedStatus;
      });
    }

    // Notify listeners
    widget.onStatusChanged?.call(evaluatedStatus, magnitude);

    // Broadcast to central AI Guardian (without opening SOS screen)
    MovementSignalState signalState;
    switch (evaluatedStatus) {
      case MovementStatus.normal:
        signalState = MovementSignalState.normal;
        break;
      case MovementStatus.light:
        signalState = MovementSignalState.light;
        break;
      case MovementStatus.high:
        signalState = MovementSignalState.high;
        break;
      case MovementStatus.abnormal:
        signalState = MovementSignalState.abnormal;
        break;
    }
    AIGuardianService.instance.updateMovementSignal(
      state: signalState,
      intensity: magnitude,
    );
  }

  /// Processes gyroscope angular velocity data in radians/sec.
  void _processGyroscopeData(double x, double y, double z) {
    double rotationSpeed = sqrt(x * x + y * y + z * z);

    if (mounted) {
      setState(() {
        _gyroX = x;
        _gyroY = y;
        _gyroZ = z;
        _gyroRotationSpeed = rotationSpeed;
      });
    }
  }

  /// Multi-factor evaluation logic to distinguish normal motion from abnormal emergency spikes.
  ///
  /// Prevents false positives by considering:
  /// - Movement intensity threshold
  /// - Multi-spike temporal density (consecutive sudden changes in direction/force)
  /// - Gyroscope rotational velocity (if available)
  /// - Configurable cooldown duration
  MovementStatus _evaluateMovementState(double intensity) {
    final int now = DateTime.now().millisecondsSinceEpoch;
    final config = _selectedSensitivity;

    // Check if in cooldown lock from a recent verified abnormal trigger
    if (now - _lastAbnormalTriggerTimestamp < _cooldownDurationMs) {
      return MovementStatus.abnormal;
    }

    // A. Abnormal Movement Check:
    // Requires either:
    // 1. Multiple consecutive high-force spikes in the time window (e.g. struggle, violent drop)
    // 2. Extreme violent sudden spike (intensity >= 1.45 * abnormalThreshold) with high angular rate
    if (intensity >= config.abnormalThreshold) {
      _highSpikeTimestamps.add(now);

      // Clean spikes older than window
      _highSpikeTimestamps.removeWhere((ts) => now - ts > _spikeWindowMs);

      bool isMultiSpikeViolent = _highSpikeTimestamps.length >= _minSpikesForAbnormal;
      bool isExtremeViolentBurst = intensity >= (config.abnormalThreshold * 1.45);
      bool isSupportedByGyro = !_isGyroAvailable || _gyroRotationSpeed >= 3.0;

      if ((isMultiSpikeViolent || isExtremeViolentBurst) && isSupportedByGyro) {
        _lastAbnormalTriggerTimestamp = now;
        _highSpikeTimestamps.clear();
        _abnormalEventCount++;

        // Expose abnormal event (Multi-Signal Decision Engine hook)
        widget.onAbnormalMovementDetected?.call(intensity);

        if (kDebugMode) {
          print(
            "⚠️ SheShield AI: [MovementStatus.abnormal] verified! Intensity: ${intensity.toStringAsFixed(2)} m/s² | Gyro: ${_gyroRotationSpeed.toStringAsFixed(2)} rad/s",
          );
        }

        return MovementStatus.abnormal;
      }
    }

    // B. High Movement
    if (intensity >= config.highThreshold) {
      return MovementStatus.high;
    }

    // C. Light Movement
    if (intensity >= config.lightThreshold) {
      return MovementStatus.light;
    }

    // D. Normal Movement
    return MovementStatus.normal;
  }

  // ===========================================================================
  // UI BUILDERS & MATERIAL 3 DESIGN
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F3FF), // Light purple background
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        title: const Text(
          "Movement Detection",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: "Sensor Info",
            onPressed: _showInfoDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Primary Safety Status Card
              _buildPrimaryStatusCard(),

              const SizedBox(height: 16),

              // 2. Multi-Signal Engine Architecture Banner
              _buildDecisionEngineNoticeBanner(),

              const SizedBox(height: 16),

              // 3. Live Movement Intensity Gauge Card
              _buildIntensityMetricCard(),

              const SizedBox(height: 16),

              // 4. Hardware Sensors Availability Status
              _buildSensorHardwareStatusCard(),

              const SizedBox(height: 16),

              // 5. Sensitivity & Threshold Settings Card
              _buildSensitivitySelectorCard(),

              const SizedBox(height: 16),

              // 6. Real-Time Raw Sensor Vectors
              _buildRawSensorCoordinatesCard(),

              const SizedBox(height: 24),

              // 7. Start / Stop Monitoring Button
              _buildMonitoringToggleButton(),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // WIDGET COMPONENTS
  // ===========================================================================

  /// Main Status Hero Card with animated pulse for abnormal state
  Widget _buildPrimaryStatusCard() {
    final status = _isMonitoring ? _currentStatus : MovementStatus.normal;
    final statusColor = _isMonitoring ? status.color : Colors.grey.shade600;
    final isAbnormal = _isMonitoring && _currentStatus == MovementStatus.abnormal;

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: isAbnormal ? _pulseAnimation.value : 1.0,
          child: child,
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: statusColor.withValues(alpha: 0.35),
            width: isAbnormal ? 2.5 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: statusColor.withValues(alpha: isAbnormal ? 0.25 : 0.08),
              blurRadius: isAbnormal ? 20 : 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            // Top Badge Row: Active Status & Emoji
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _isMonitoring
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
                          color: _isMonitoring ? Colors.green : Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isMonitoring ? "MONITORING ACTIVE" : "MONITORING PAUSED",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _isMonitoring ? Colors.deepPurple : Colors.grey.shade700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _isMonitoring ? status.emoji : "⚪",
                  style: const TextStyle(fontSize: 22),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Large Status Icon Container
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: statusColor.withValues(alpha: 0.12),
                border: Border.all(
                  color: statusColor.withValues(alpha: 0.25),
                  width: 2,
                ),
              ),
              child: Icon(
                _isMonitoring ? status.icon : Icons.motion_photos_off_rounded,
                size: 58,
                color: statusColor,
              ),
            ),

            const SizedBox(height: 14),

            // Status Title
            Text(
              _isMonitoring ? status.label : "Monitoring Disabled",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),

            const SizedBox(height: 6),

            // Status Description
            Text(
              _isMonitoring
                  ? status.description
                  : "Tap 'Start Monitoring' below to activate motion & sensor analysis.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Notice banner regarding Multi-Signal Emergency Decision Engine
  Widget _buildDecisionEngineNoticeBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.deepPurple.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.hub_rounded,
            color: Colors.deepPurple.shade700,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Multi-Signal Decision Engine Ready",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple.shade900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Abnormal movement is isolated as a signal event (MovementStatus.abnormal) and will not directly trigger SOS without multi-signal fusion.",
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.deepPurple.shade800,
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

  /// Real-time Intensity Gauge & Metric Card
  Widget _buildIntensityMetricCard() {
    double progressRatio = (_currentIntensity / 25.0).clamp(0.0, 1.0);
    Color barColor = _currentStatus.color;

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
                "Movement Intensity",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: barColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "${_currentIntensity.toStringAsFixed(2)} m/s²",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: barColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Linear Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _isMonitoring ? progressRatio : 0.0,
              minHeight: 10,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),

          const SizedBox(height: 14),

          // Peak and Event Metrics Row
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  label: "Peak Acceleration",
                  value: "${_peakIntensity.toStringAsFixed(2)} m/s²",
                  icon: Icons.trending_up_rounded,
                  color: Colors.deepPurple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricTile(
                  label: "Abnormal Events",
                  value: "$_abnormalEventCount triggered",
                  icon: Icons.notifications_active_rounded,
                  color: _abnormalEventCount > 0 ? Colors.red : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Compact mini metric tile
  Widget _buildMetricTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// Hardware sensor health & availability card
  Widget _buildSensorHardwareStatusCard() {
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
          const Text(
            "Hardware Sensors Status",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),

          // Accelerometer Status Row
          _buildSensorStatusRow(
            sensorName: "3-Axis Accelerometer",
            subtitle: "Linear acceleration & kinetic motion",
            isAvailable: _isAccelAvailable,
            icon: Icons.speed_rounded,
          ),

          const Divider(height: 20, thickness: 0.8),

          // Gyroscope Status Row
          _buildSensorStatusRow(
            sensorName: "3-Axis Gyroscope",
            subtitle: _isGyroAvailable ? "Angular velocity & device rotation" : _gyroStatusText,
            isAvailable: _isGyroAvailable,
            icon: Icons.screen_rotation_rounded,
          ),
        ],
      ),
    );
  }

  /// Individual sensor status row
  Widget _buildSensorStatusRow({
    required String sensorName,
    required String subtitle,
    required bool isAvailable,
    required IconData icon,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: isAvailable
                ? Colors.green.withValues(alpha: 0.12)
                : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 20,
            color: isAvailable ? Colors.green.shade700 : Colors.grey.shade600,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sensorName,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11.5,
                  color: isAvailable ? Colors.grey.shade600 : Colors.orange.shade800,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: isAvailable
                ? Colors.green.withValues(alpha: 0.12)
                : Colors.amber.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            isAvailable ? "Online" : "Unavailable",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isAvailable ? Colors.green.shade700 : Colors.orange.shade900,
            ),
          ),
        ),
      ],
    );
  }

  /// Sensitivity selector segment card
  Widget _buildSensitivitySelectorCard() {
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
                "Detection Sensitivity",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(
                "Cooldown: ${_cooldownDurationMs / 1000}s",
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Sensitivity Option Buttons
          Row(
            children: SensitivityLevel.values.map((level) {
              bool isSelected = _selectedSensitivity == level;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedSensitivity = level;
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.deepPurple
                            : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? Colors.deepPurple
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            level.name.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            ">${level.abnormalThreshold} m/s²",
                            style: TextStyle(
                              fontSize: 10,
                              color: isSelected ? Colors.white70 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// Live X, Y, Z vector coordinates
  Widget _buildRawSensorCoordinatesCard() {
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
          const Text(
            "Live Sensor Vectors",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),

          // Accelerometer Coordinates
          Text(
            "Accelerometer (m/s²)",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: _buildCoordinateBox("X", _accelX)),
              const SizedBox(width: 8),
              Expanded(child: _buildCoordinateBox("Y", _accelY)),
              const SizedBox(width: 8),
              Expanded(child: _buildCoordinateBox("Z", _accelZ)),
            ],
          ),

          const SizedBox(height: 14),

          // Gyroscope Coordinates
          Text(
            "Gyroscope (rad/s)",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: _buildCoordinateBox("X", _gyroX, isAvailable: _isGyroAvailable)),
              const SizedBox(width: 8),
              Expanded(child: _buildCoordinateBox("Y", _gyroY, isAvailable: _isGyroAvailable)),
              const SizedBox(width: 8),
              Expanded(child: _buildCoordinateBox("Z", _gyroZ, isAvailable: _isGyroAvailable)),
            ],
          ),
        ],
      ),
    );
  }

  /// Helper coordinate box
  Widget _buildCoordinateBox(String axis, double value, {bool isAvailable = true}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Text(
            axis,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            isAvailable ? value.toStringAsFixed(2) : "--",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isAvailable ? Colors.black87 : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  /// Big Action Toggle Button (Start / Stop Monitoring)
  Widget _buildMonitoringToggleButton() {
    return SizedBox(
      height: 58,
      child: ElevatedButton.icon(
        onPressed: () {
          if (_isMonitoring) {
            _stopMonitoring();
          } else {
            _startMonitoring();
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: _isMonitoring ? Colors.red.shade600 : Colors.deepPurple,
          foregroundColor: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        icon: Icon(
          _isMonitoring ? Icons.stop_circle_rounded : Icons.play_circle_fill_rounded,
          size: 26,
        ),
        label: Text(
          _isMonitoring ? "STOP MONITORING" : "START MONITORING",
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  /// Information Dialog
  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.shield_rounded, color: Colors.deepPurple),
            SizedBox(width: 8),
            Text("Movement Safety", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "How SheShield Movement Detection Works:",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              SizedBox(height: 8),
              Text("• 🟢 Normal: Stable or resting state (< 2.5 m/s²)."),
              SizedBox(height: 4),
              Text("• 🟡 Light: Gentle handling or slow walk (2.5 - 6.5 m/s²)."),
              SizedBox(height: 4),
              Text("• 🟠 High: Fast movement or running (6.5 - 16.0 m/s²)."),
              SizedBox(height: 4),
              Text("• 🔴 Abnormal: Rapid high-force swings or violent sudden motion (> 18.5 m/s²)."),
              SizedBox(height: 12),
              Text(
                "Multi-Signal Ready:\nSingle accidental shakes will NOT immediately trigger SOS. Instead, abnormal events are broadcast to the SheShield Decision Engine.",
                style: TextStyle(fontSize: 12, color: Colors.black87),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Got It", style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
