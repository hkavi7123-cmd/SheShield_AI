import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Service to detect high-level shaking of the device.
class ShakeDetectorService {
  final VoidCallback onShake;

  /// Threshold for high-level shaking (m/s^2).
  /// Normal walking/gentle movement is 0-5.
  /// High-level shaking spikes over 20-25 m/s^2.
  final double shakeThreshold;

  /// Minimum time between shake triggers (in ms) to prevent duplicate events.
  final int shakeCooldownMs;

  /// Minimum number of high acceleration spikes required within [spikeWindowMs].
  final int minSpikes;
  final int spikeWindowMs;

  StreamSubscription? _streamSubscription;
  int _lastShakeTimestamp = 0;
  final List<int> _spikeTimestamps = [];

  ShakeDetectorService({
    required this.onShake,
    this.shakeThreshold = 20.0,
    this.shakeCooldownMs = 3000,
    this.minSpikes = 2,
    this.spikeWindowMs = 800,
  });

  /// Starts listening to phone accelerometer motion.
  void startListening() {
    stopListening();

    try {
      _streamSubscription = userAccelerometerEventStream().listen(
        (UserAccelerometerEvent event) {
          _processAcceleration(event.x, event.y, event.z);
        },
        onError: (error) {
          // Fallback to standard accelerometer stream if userAccelerometer fails
          _streamSubscription = accelerometerEventStream().listen(
            (AccelerometerEvent event) {
              // Accelerometer includes 9.8m/s^2 gravity, calculate net magnitude
              double magnitude =
                  sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
              double netMagnitude = (magnitude - 9.8).abs();
              _processAcceleration(event.x, event.y, netMagnitude);
            },
          );
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print("Error starting shake sensor: $e");
      }
    }
  }

  void _processAcceleration(double x, double y, double z) {
    double totalAcceleration = sqrt(x * x + y * y + z * z);
    int now = DateTime.now().millisecondsSinceEpoch;

    // Check if in cooldown period
    if (now - _lastShakeTimestamp < shakeCooldownMs) {
      return;
    }

    if (totalAcceleration >= shakeThreshold) {
      // Record spike
      _spikeTimestamps.add(now);

      // Remove spikes outside window
      _spikeTimestamps.removeWhere((ts) => now - ts > spikeWindowMs);

      // If we reached required number of high-force spikes in the window or one violent spike (> 30.0)
      if (_spikeTimestamps.length >= minSpikes || totalAcceleration >= (shakeThreshold * 1.5)) {
        _lastShakeTimestamp = now;
        _spikeTimestamps.clear();
        onShake();
      }
    }
  }

  /// Stops listening to accelerometer events.
  void stopListening() {
    _streamSubscription?.cancel();
    _streamSubscription = null;
    _spikeTimestamps.clear();
  }
}
