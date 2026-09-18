import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:url_launcher/url_launcher.dart';

class EmergencyShieldScreen extends StatefulWidget {
  final bool triggeredByShake;

  const EmergencyShieldScreen({
    super.key,
    this.triggeredByShake = false,
  });

  @override
  State<EmergencyShieldScreen> createState() => _EmergencyShieldScreenState();
}

class _EmergencyShieldScreenState extends State<EmergencyShieldScreen> {
  static const MethodChannel _smsChannel = MethodChannel('com.sheshieldai/sms');

  // Camera
  List<CameraDescription> _cameras = [];
  CameraController? _cameraController;
  int _selectedCameraIndex = 0;
  bool _isCameraInitialized = false;
  bool _isRecordingVideo = false;
  Timer? _recordingTimer;
  int _recordingSeconds = 0;

  // Speech to text
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _spokenText = "Listening for 'Help' or 'Help Me'...";
  bool _speechAvailable = false;

  // SOS state
  bool _isSendingSos = false;
  bool _sosSent = false;
  String _sosStatusText = "Shield Active: Say 'Help' or 'Help Me' to trigger SOS";

  @override
  void initState() {
    super.initState();
    _initializeAllEmergencyServices();
  }

  Future<void> _initializeAllEmergencyServices() async {
    // Request required permissions
    await [
      Permission.camera,
      Permission.microphone,
      Permission.location,
      Permission.sms,
    ].request();

    // Haptic feedback on auto-trigger
    if (widget.triggeredByShake) {
      HapticFeedback.vibrate();
    }

    // 1. Initialize Camera and automatically start video recording
    await _initCamera();

    // 2. Initialize Voice Detection and automatically start listening for "Help"
    await _initVoiceDetection();
  }

  // ==========================================
  // CAMERA & VIDEO RECORDING
  // ==========================================

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;

      // Prefer front camera for user face / personal defense or back camera
      int defaultIndex = _cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
      if (defaultIndex == -1) defaultIndex = 0;
      _selectedCameraIndex = defaultIndex;

      await _startCameraWithIndex(_selectedCameraIndex);
    } catch (e) {
      debugPrint("Camera initialization error: $e");
    }
  }

  Future<void> _startCameraWithIndex(int index) async {
    if (_cameras.isEmpty) return;

    if (_cameraController != null) {
      if (_isRecordingVideo) {
        try {
          await _cameraController!.stopVideoRecording();
        } catch (_) {}
      }
      await _cameraController!.dispose();
    }

    final controller = CameraController(
      _cameras[index],
      ResolutionPreset.medium,
      enableAudio: true,
    );

    _cameraController = controller;

    try {
      await controller.initialize();
      if (!mounted) return;

      setState(() {
        _isCameraInitialized = true;
      });

      // Automatically start video recording
      await _startAutoVideoRecording();
    } catch (e) {
      debugPrint("Failed to initialize camera controller: $e");
    }
  }

  Future<void> _startAutoVideoRecording() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (_cameraController!.value.isRecordingVideo) return;

    try {
      await _cameraController!.startVideoRecording();
      _startRecordingTimer();

      if (mounted) {
        setState(() {
          _isRecordingVideo = true;
        });
      }
    } catch (e) {
      debugPrint("Error starting video recording: $e");
    }
  }

  void _startRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingSeconds = 0;
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _recordingSeconds++;
        });
      }
    });
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    await _startCameraWithIndex(_selectedCameraIndex);
  }

  // ==========================================
  // VOICE DETECTION
  // ==========================================

  Future<void> _initVoiceDetection() async {
    try {
      _speechAvailable = await _speech.initialize(
        onStatus: (status) {
          debugPrint("Speech status: $status");
          if (status == "done" || status == "notListening") {
            // Keep speech listening alive continuously while screen is active
            if (mounted && !_sosSent) {
              _startContinuousListening();
            }
          }
        },
        onError: (error) {
          debugPrint("Speech error: ${error.errorMsg}");
          if (mounted && !_sosSent) {
            Future.delayed(const Duration(seconds: 1), () {
              if (mounted) _startContinuousListening();
            });
          }
        },
      );

      if (_speechAvailable) {
        await _startContinuousListening();
      } else {
        if (mounted) {
          setState(() {
            _spokenText = "Voice recognition initializing...";
          });
        }
      }
    } catch (e) {
      debugPrint("Voice detection error: $e");
    }
  }

  Future<void> _startContinuousListening() async {
    if (!_speechAvailable || _sosSent) return;

    setState(() {
      _isListening = true;
    });

    try {
      await _speech.listen(
        onResult: (result) {
          if (!mounted) return;

          setState(() {
            _spokenText = result.recognizedWords;
          });

          String spoken = result.recognizedWords.toLowerCase();

          // Check for emergency keywords: "help", "help me", "save me", "sos", "emergency"
          if (spoken.contains("help") ||
              spoken.contains("help me") ||
              spoken.contains("save me") ||
              spoken.contains("emergency") ||
              spoken.contains("sos") ||
              spoken.contains("please help")) {
            debugPrint("🚨 EMERGENCY VOICE KEYWORD DETECTED: $spoken");
            _triggerVoiceSOS(spoken);
          }
        },
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          cancelOnError: false,
          listenMode: stt.ListenMode.dictation,
        ),
      );
    } catch (e) {
      debugPrint("Listen failed: $e");
    }
  }

  // ==========================================
  // AUTOMATIC SOS DISPATCH
  // ==========================================

  String _cleanPhoneNumber(String contact) {
    if (contact.contains(" - ")) {
      return contact.split(" - ").last.trim();
    }
    return contact.trim();
  }

  Future<void> _triggerVoiceSOS(String detectedWord) async {
    if (_isSendingSos || _sosSent) return;

    HapticFeedback.heavyImpact();

    setState(() {
      _isSendingSos = true;
      _sosStatusText = "🚨 Triggered by voice ('$detectedWord')! Sending SOS...";
    });

    await _executeSOSDispatch();
  }

  Future<void> _executeSOSDispatch() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> contacts = prefs.getStringList("contacts") ?? [];

    if (contacts.isEmpty) {
      if (mounted) {
        setState(() {
          _isSendingSos = false;
          _sosStatusText = "No Emergency Contacts Found! Please add contacts.";
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.red,
            content: Text("No Emergency Contacts Found. Please add contacts in settings."),
          ),
        );
      }
      return;
    }

    // Get current GPS location
    Position? position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 7),
        ),
      );
    } catch (e) {
      try {
        position = await Geolocator.getLastKnownPosition();
      } catch (_) {}
    }

    String locationLink = position != null
        ? "https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}"
        : "Location unavailable";

    String message =
        "🚨 SHIELD EMERGENCY ALERT!\nHigh motion & Voice 'HELP' detected.\nI need urgent help!\n\nMy Live Location:\n$locationLink";

    int sentSuccessCount = 0;

    for (String contact in contacts) {
      String phone = _cleanPhoneNumber(contact);
      if (phone.isEmpty) continue;

      // 1. Direct native background SMS
      try {
        final bool? result = await _smsChannel.invokeMethod<bool>(
          'sendDirectSms',
          {
            'phone': phone,
            'message': message,
          },
        );
        if (result == true) {
          sentSuccessCount++;
          continue;
        }
      } catch (_) {}

      // 2. URL launcher fallback
      try {
        final Uri smsUri = Uri.parse(
          "sms:$phone?body=${Uri.encodeComponent(message)}",
        );
        if (await canLaunchUrl(smsUri)) {
          await launchUrl(smsUri);
          sentSuccessCount++;
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _isSendingSos = false;
        _sosSent = sentSuccessCount > 0;
        _sosStatusText = sentSuccessCount > 0
            ? "🚨 SOS SMS sent automatically to $sentSuccessCount contact(s)!"
            : "SOS dispatch failed. Please check permissions.";
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: sentSuccessCount > 0 ? Colors.green : Colors.red,
          content: Text(
            sentSuccessCount > 0
                ? "🚨 SOS Alert Sent Automatically to $sentSuccessCount Contact(s)!"
                : "Failed to send SOS. Please check SMS permissions.",
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _stopAndExit() async {
    _recordingTimer?.cancel();
    _speech.stop();

    if (_cameraController != null && _isRecordingVideo) {
      try {
        await _cameraController!.stopVideoRecording();
      } catch (_) {}
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _speech.stop();
    _cameraController?.dispose();
    super.dispose();
  }

  String _formatTimer(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return "$mins:$secs";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // ==========================================
            // CAMERA PREVIEW BACKGROUND
            // ==========================================
            Positioned.fill(
              child: _isCameraInitialized && _cameraController != null
                  ? CameraPreview(_cameraController!)
                  : Container(
                      color: Colors.grey.shade900,
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: Colors.red),
                            SizedBox(height: 15),
                            Text(
                              "Activating Camera & Video...",
                              style: TextStyle(color: Colors.white, fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),

            // ==========================================
            // TOP BAR: SHAKE ALERT & REC INDICATOR
            // ==========================================
            Positioned(
              top: 15,
              left: 15,
              right: 15,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Shake / Auto trigger banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: widget.triggeredByShake
                          ? Colors.red.withValues(alpha: 0.9)
                          : Colors.deepPurple.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(color: Colors.black45, blurRadius: 8),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.triggeredByShake ? Icons.vibration : Icons.shield,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.triggeredByShake
                              ? "SHAKE DETECTED"
                              : "EMERGENCY SHIELD",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Video Recording indicator
                  if (_isRecordingVideo)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.redAccent, width: 1.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.fiber_manual_record,
                            color: Colors.red,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "REC ${_formatTimer(_recordingSeconds)}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Switch camera button
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black54,
                    ),
                    icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
                    onPressed: _switchCamera,
                  ),
                ],
              ),
            ),

            // ==========================================
            // BOTTOM CONTROLS & VOICE TRANSCRIPT
            // ==========================================
            Positioned(
              bottom: 20,
              left: 15,
              right: 15,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Voice Listening & Transcript Box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: _sosSent
                            ? Colors.green
                            : (_isListening ? Colors.redAccent : Colors.grey.shade700),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              _isListening ? Icons.mic : Icons.mic_none,
                              color: _sosSent ? Colors.green : Colors.redAccent,
                              size: 24,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _sosStatusText,
                                style: TextStyle(
                                  color: _sosSent ? Colors.greenAccent : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Live Spoken Words
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade900,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            "Spoken: \"$_spokenText\"",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.amberAccent,
                              fontSize: 16,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 15),

                  // Action Buttons: Trigger SOS Now + Stop & Close
                  Row(
                    children: [
                      // Manual Instant SOS Button
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: 54,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 6,
                            ),
                            onPressed: _isSendingSos
                                ? null
                                : () => _executeSOSDispatch(),
                            icon: _isSendingSos
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.warning_amber_rounded, size: 24),
                            label: Text(
                              _sosSent ? "RESEND SOS" : "TRIGGER SOS NOW",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 10),

                      // Exit / Stop Button
                      Expanded(
                        flex: 1,
                        child: SizedBox(
                          height: 54,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.black54,
                              side: const BorderSide(color: Colors.white60, width: 1.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: _stopAndExit,
                            child: const Text(
                              "Stop / Close",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
