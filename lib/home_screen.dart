import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'login_screen.dart';
import 'sos_screen.dart';
import 'emergency_contact_screen.dart';
import 'live_location_screen.dart';
import 'voice_detection_screen.dart';
import 'emergency_shield_screen.dart';
import 'nearby_police_screen.dart';
import 'shake_detector_service.dart';
import 'movement_detection_screen.dart';
import 'ai_guardian_screen.dart';
import 'ai_guardian_service.dart';
import 'smart_movement_detection_screen.dart';
import 'transport_detection_screen.dart';
import 'screens/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  ShakeDetectorService? _shakeDetector;

  @override
  void initState() {
    super.initState();
    _startShakeListener();
  }

  void _startShakeListener() {
    _shakeDetector = ShakeDetectorService(
      shakeThreshold: 20.0, // High-level shake threshold
      shakeCooldownMs: 3500,
      onShake: () {
        if (!mounted) return;
        _onHighLevelShakeDetected();
      },
    );
    _shakeDetector?.startListening();
  }

  void _onHighLevelShakeDetected() {
    // Automatically navigate to Emergency Voice & Video Shield Screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const EmergencyShieldScreen(
          triggeredByShake: true,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _shakeDetector?.stopListening();
    super.dispose();
  }

  // =========================
  // BUILD CARD
  // =========================
  Widget buildCard(
    BuildContext context,
    IconData icon,
    String title,
    Color color,
    VoidCallback onTap, {
    String? subtitle,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            height: 135,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 32,
                    color: color,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =========================
  // LOGOUT CONFIRMATION
  // =========================
  void showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            "Logout",
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            "Are you sure you want to logout?",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text(
                "Cancel",
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.pop(dialogContext);
                await FirebaseAuth.instance.signOut();

                if (!context.mounted) return;

                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => const LoginScreen(),
                  ),
                  (route) => false,
                );
              },
              child: const Text("Logout"),
            ),
          ],
        );
      },
    );
  }

  // =========================
  // HOME SCREEN
  // =========================
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userName = user?.displayName ?? user?.email?.split('@').first ?? "User";

    return Scaffold(
      backgroundColor: const Color(0xFFF5F3FF),
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        centerTitle: true,
        title: const Text(
          "SheShield AI",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.settings_rounded,
              color: Colors.white,
            ),
            tooltip: "Settings",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(
              Icons.logout,
              color: Colors.white,
            ),
            tooltip: "Logout",
            onPressed: () {
              showLogoutDialog(context);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Shake Active Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.deepPurple.shade700, Colors.deepPurple.shade900],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.deepPurple.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.vibration_rounded,
                      color: Colors.amberAccent,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Shake Shield Active",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          "Vigorously shake phone to auto-open Voice & Video Shield",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // AI Guardian Live Protection Banner
            ListenableBuilder(
              listenable: AIGuardianService.instance,
              builder: (context, _) {
                final snapshot = AIGuardianService.instance.snapshot;
                final isProtected = snapshot.isProtectionActive;
                final state = snapshot.state;

                Color bannerBorderColor;
                Color statusColor;
                switch (state) {
                  case GuardianState.safe:
                    bannerBorderColor = Colors.green.shade300;
                    statusColor = Colors.green.shade700;
                    break;
                  case GuardianState.attention:
                    bannerBorderColor = Colors.amber.shade400;
                    statusColor = Colors.amber.shade900;
                    break;
                  case GuardianState.potentialEmergency:
                  case GuardianState.emergency:
                    bannerBorderColor = Colors.red.shade400;
                    statusColor = Colors.red.shade700;
                    break;
                  default:
                    bannerBorderColor = Colors.deepPurple.shade100;
                    statusColor = Colors.deepPurple.shade700;
                }

                return InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AIGuardianScreen(),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: bannerBorderColor, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: statusColor.withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.shield_rounded,
                            color: statusColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    "AI Guardian",
                                    style: TextStyle(
                                      color: Colors.black87,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14.5,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(state.emoji, style: const TextStyle(fontSize: 14)),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isProtected
                                    ? "Status: ${state.label} • Tap to view dashboard"
                                    : "Protection Inactive • Tap to activate",
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: Colors.grey.shade500,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 15),

            // Profile & Greeting
            Row(
              children: [
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.deepPurple,
                  child: Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Welcome back,",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      userName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 18),

            // =========================
            // SOS BUTTON
            // =========================
            SizedBox(
              width: double.infinity,
              height: 65,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  elevation: 6,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SosScreen(),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.warning_rounded,
                  color: Colors.white,
                  size: 30,
                ),
                label: const Text(
                  "SOS EMERGENCY",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // =========================
            // ROW 1: Emergency Video & Shake Shield
            // =========================
            Row(
              children: [
                buildCard(
                  context,
                  Icons.shield_rounded,
                  "Shake & Voice Shield",
                  Colors.deepOrange,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const EmergencyShieldScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 10),
                buildCard(
                  context,
                  Icons.videocam_rounded,
                  "Emergency Video",
                  Colors.blue.shade700,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const EmergencyShieldScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 10),

            // =========================
            // ROW 2: Voice Detection & Live Location
            // =========================
            Row(
              children: [
                buildCard(
                  context,
                  Icons.record_voice_over_rounded,
                  "Voice Detection",
                  Colors.deepPurple,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const VoiceDetectionScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 10),
                buildCard(
                  context,
                  Icons.location_on_rounded,
                  "Live Location & Share",
                  Colors.green.shade700,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LiveLocationScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 10),

            // =========================
            // ROW 3: Emergency Contacts & Nearby Police Stations
            // =========================
            Row(
              children: [
                buildCard(
                  context,
                  Icons.contacts_rounded,
                  "Emergency Contacts",
                  Colors.pink.shade700,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const EmergencyContactScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 10),
                buildCard(
                  context,
                  Icons.local_police_rounded,
                  "Nearby Police & Help",
                  Colors.indigo.shade700,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const NearbyPoliceScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 10),

            // =========================
            // ROW 4: AI Guardian & Movement Detection
            // =========================
            Row(
              children: [
                buildCard(
                  context,
                  Icons.shield_rounded,
                  "AI Guardian",
                  Colors.deepPurple.shade800,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AIGuardianScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 10),
                buildCard(
                  context,
                  Icons.sensors_rounded,
                  "Movement Detection",
                  Colors.teal.shade700,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MovementDetectionScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 10),

            // =========================
            // ROW 5: Smart Movement & Transport Detection
            // =========================
            Row(
              children: [
                buildCard(
                  context,
                  Icons.directions_run_rounded,
                  "Smart Movement",
                  Colors.amber.shade800,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SmartMovementDetectionScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 10),
                buildCard(
                  context,
                  Icons.directions_car_rounded,
                  "Transport Detection",
                  Colors.cyan.shade800,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TransportDetectionScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 10),

            // =========================
            // ROW 6: App Settings Card
            // =========================
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
              borderRadius: BorderRadius.circular(20),
              child: Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: Colors.deepPurple.shade100, width: 1.2),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: [Colors.white, Colors.deepPurple.shade50.withValues(alpha: 0.5)],
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.settings_suggest_rounded,
                          size: 28,
                          color: Colors.deepPurple,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "⚙️ Settings",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepPurple,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "Manage your safety, account and app preferences",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 16,
                        color: Colors.deepPurple,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}