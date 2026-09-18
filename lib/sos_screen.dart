import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'emergency_contact.dart';
import 'nearby_help_screen.dart';
import 'nearby_help_service.dart';
import 'ai_guardian_service.dart';
import 'services/settings_service.dart';
import 'screens/emergency_escape_screen.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  late int countdown;
  Timer? timer;
  bool isSending = false;
  bool isSent = false;
  String statusMessage = "SOS will activate automatically";
  bool _navigatedToEscapeMode = false;
  Position? _capturedPosition;
  String _capturedAddress = "";

  @override
  void initState() {
    super.initState();
    countdown = SettingsService.instance.sosCountdown;
    startCountdown();
  }

  Future<void> sendSOS() async {
    if (isSending) return;

    timer?.cancel();

    // Broadcast Manual SOS to AI Guardian
    AIGuardianService.instance.triggerManualSos(
      reason: "Manual SOS triggered from SOS screen.",
    );

    setState(() {
      isSending = true;
      statusMessage = "Accessing GPS location and sending emergency SOS...";
    });

    final prefs = await SharedPreferences.getInstance();
    List<String> rawContacts = prefs.getStringList("contacts") ?? [];

    // Request permissions for SMS and Location
    try {
      await [Permission.sms, Permission.location].request();
    } catch (_) {}

    // Get current location
    Position? position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
    } catch (e) {
      try {
        position = await Geolocator.getLastKnownPosition();
      } catch (_) {}
    }

    String address = "";
    if (position != null) {
      _capturedPosition = position;
      address = await NearbyHelpService.getAddressFromCoordinates(position.latitude, position.longitude);
      _capturedAddress = address;
    }

    if (rawContacts.isEmpty) {
      if (mounted) {
        setState(() {
          isSending = false;
          statusMessage = "No Emergency Contacts Found. Entering Escape Mode...";
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            content: const Text("No Emergency Contacts Found. Launching Emergency Escape Mode."),
            duration: const Duration(seconds: 3),
          ),
        );

        _autoOpenEscapeMode(contactsCount: 0);
      }
      return;
    }

    final customMsg = SettingsService.instance.emergencyMessage;
    final String message = position != null
        ? NearbyHelpService.formatEmergencyMessage(
            lat: position.latitude,
            lng: position.longitude,
            address: address,
            customNote: customMsg.isNotEmpty ? customMsg : "🚨 IMMEDIATE SOS! I am in grave danger and need urgent emergency assistance.",
          )
        : (customMsg.isNotEmpty ? "$customMsg\n📍 Location unavailable." : "🚨 SOS ALERT!\nI am in danger and need immediate help.\nLocation unavailable.");

    int successCount = 0;

    for (String raw in rawContacts) {
      final contact = EmergencyContact.fromJson(raw);
      if (contact.phone.isEmpty) continue;

      final sent = await NearbyHelpService.sendEmergencySms(
        phone: contact.phone,
        message: message,
      );
      if (sent) successCount++;
    }

    if (mounted) {
      setState(() {
        isSending = false;
        isSent = successCount > 0;
        statusMessage = successCount > 0
            ? "🚨 SOS Sent automatically to $successCount contact(s)!"
            : "SOS dispatched. Entering Emergency Escape Mode...";
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: successCount > 0 ? Colors.green : Colors.orange.shade800,
          content: Text(
            successCount > 0
                ? "🚨 SOS Alert Sent to $successCount contact(s)!"
                : "SOS activated. Opening Emergency Escape Mode...",
          ),
          duration: const Duration(seconds: 3),
        ),
      );

      // Transition to Emergency Escape Mode
      _autoOpenEscapeMode(contactsCount: successCount);
    }
  }

  void _autoOpenEscapeMode({required int contactsCount}) {
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (!mounted || _navigatedToEscapeMode) return;
      _navigateToEscapeScreen(contactsCount: contactsCount, replaceRoute: true);
    });
  }

  void _navigateToEscapeScreen({int? contactsCount, bool replaceRoute = false}) {
    if (_navigatedToEscapeMode && replaceRoute) return;
    _navigatedToEscapeMode = true;
    timer?.cancel();

    final escapeScreen = EmergencyEscapeScreen(
      initialContactsNotifiedCount: contactsCount ?? (isSent ? 1 : 0),
      initialPosition: _capturedPosition,
      initialAddress: _capturedAddress,
    );

    if (replaceRoute) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => escapeScreen),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => escapeScreen),
      );
    }
  }

  void startCountdown() {
    timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (countdown > 1) {
        setState(() {
          countdown--;
        });
      } else {
        timer.cancel();
        setState(() {
          countdown = 0;
        });
        await sendSOS();
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red.shade50,
      appBar: AppBar(
        title: const Text("SOS Emergency"),
        backgroundColor: Colors.red.shade800,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSent ? Icons.check_circle_rounded : Icons.warning_rounded,
                size: 100,
                color: isSent ? Colors.green : Colors.red,
              ),
              const SizedBox(height: 15),
              Text(
                isSent ? "SOS Alert Sent!" : "Emergency Alert",
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              if (!isSent && !isSending && countdown > 0)
                Text(
                  "$countdown",
                  style: const TextStyle(
                    fontSize: 70,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              if (isSending) ...[
                const SizedBox(height: 16),
                const CircularProgressIndicator(color: Colors.red),
                const SizedBox(height: 16),
              ],
              const SizedBox(height: 12),
              Text(
                statusMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSent ? FontWeight.bold : FontWeight.normal,
                  color: isSent ? Colors.green.shade800 : Colors.black87,
                ),
              ),
              const SizedBox(height: 24),

              // Emergency Escape Mode Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB71C1C),
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    timer?.cancel();
                    _navigateToEscapeScreen(replaceRoute: false);
                  },
                  icon: const Icon(Icons.directions_run_rounded, size: 24),
                  label: const Text(
                    "🏃 Open Emergency Escape Mode",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              if (!isSent && !isSending) ...[
                // Send immediately button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      timer?.cancel();
                      sendSOS();
                    },
                    icon: const Icon(Icons.send_rounded),
                    label: const Text(
                      "Send SOS Immediately",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // 112 Police Emergency Fast Dial
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade900,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => NearbyHelpService.makePhoneCall("112"),
                  icon: const Icon(Icons.phone_in_talk),
                  label: const Text(
                    "Call Police Emergency (112)",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // View Nearby Police Stations button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.deepPurple,
                    side: const BorderSide(color: Colors.deepPurple, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    timer?.cancel();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const NearbyHelpScreen()),
                    );
                  },
                  icon: const Icon(Icons.local_police_rounded),
                  label: const Text(
                    "Nearby Police Stations & Safe Points",
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Cancel / Go back button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton(
                  onPressed: () {
                    timer?.cancel();
                    AIGuardianService.instance.cancelManualSos();
                    Navigator.pop(context);
                  },
                  child: Text(
                    isSent ? "Back to Home" : "Cancel SOS",
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}