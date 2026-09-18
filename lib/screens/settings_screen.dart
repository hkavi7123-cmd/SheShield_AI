import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

import '../services/settings_service.dart';
import '../login_screen.dart';
import '../emergency_contact_screen.dart';
import '../live_location_screen.dart';
import '../nearby_police_screen.dart';

/// Comprehensive, modern Settings Screen for SheShield AI.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settings = SettingsService.instance;
  LocationPermission _locationPermission = LocationPermission.denied;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (mounted) {
        setState(() {
          _locationPermission = perm;
        });
      }
    } catch (_) {}
  }

  // =========================================================
  // LOGOUT CONFIRMATION
  // =========================================================
  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Colors.red),
            SizedBox(width: 10),
            Text("Logout", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          "Are you sure you want to logout of SheShield AI?",
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseAuth.instance.signOut();
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text("Logout"),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // DELETE ACCOUNT CONFIRMATION
  // =========================================================
  void _confirmDeleteAccount() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text("Delete Account", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
          ],
        ),
        content: const Text(
          "Are you sure you want to permanently delete your SheShield AI account?\n\nThis will remove your profile and emergency configurations. This action cannot be undone.",
          style: TextStyle(fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  await user.delete();
                  if (!mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              } on FirebaseAuthException catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: Colors.red,
                    content: Text(
                      e.code == 'requires-recent-login'
                          ? "Please log out and log back in to verify your identity before deleting your account."
                          : "Account deletion failed: ${e.message}",
                    ),
                    duration: const Duration(seconds: 4),
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: Colors.red,
                    content: Text("Error: ${e.toString()}"),
                  ),
                );
              }
            },
            child: const Text("Delete Permanently"),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // SOS COUNTDOWN SELECTOR DIALOG
  // =========================================================
  void _showCountdownSelector() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Select SOS Countdown", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [5, 10, 15].map((sec) {
            final isSelected = _settings.sosCountdown == sec;
            return ListTile(
              leading: Icon(
                isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: isSelected ? Colors.deepPurple : Colors.grey,
              ),
              title: Text("$sec Seconds ${sec == 5 ? '(Recommended)' : ''}"),
              onTap: () {
                _settings.setSosCountdown(sec);
                Navigator.pop(ctx);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  // =========================================================
  // EDIT EMERGENCY MESSAGE DIALOG
  // =========================================================
  void _showEditEmergencyMessageDialog() {
    final controller = TextEditingController(text: _settings.emergencyMessage);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Custom Emergency Message", style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: "Enter default emergency SOS text...",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                _settings.setEmergencyMessage(controller.text.trim());
              }
              Navigator.pop(ctx);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // THEME SELECTOR DIALOG
  // =========================================================
  void _showThemeSelector() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Select Theme", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildThemeOption(ctx, "System Default", ThemeMode.system),
            _buildThemeOption(ctx, "Light Mode", ThemeMode.light),
            _buildThemeOption(ctx, "Dark Mode", ThemeMode.dark),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption(BuildContext ctx, String label, ThemeMode mode) {
    final isSelected = _settings.themeMode == mode;
    return ListTile(
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
        color: isSelected ? Colors.deepPurple : Colors.grey,
      ),
      title: Text(label),
      onTap: () {
        _settings.setThemeMode(mode);
        Navigator.pop(ctx);
      },
    );
  }

  // =========================================================
  // LANGUAGE SELECTOR DIALOG
  // =========================================================
  void _showLanguageSelector() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Select Language", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLanguageOption(ctx, "English (Default)", 'en'),
            _buildLanguageOption(ctx, "தமிழ் (Tamil)", 'ta'),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption(BuildContext ctx, String label, String code) {
    final isSelected = _settings.language == code;
    return ListTile(
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
        color: isSelected ? Colors.deepPurple : Colors.grey,
      ),
      title: Text(label),
      onTap: () {
        _settings.setLanguage(code);
        Navigator.pop(ctx);
      },
    );
  }

  // =========================================================
  // INFO MODALS (HELP & PRIVACY)
  // =========================================================
  void _showInfoModal({
    required String title,
    required List<Widget> children,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (_, scrollCtrl) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: ListView(
            controller: scrollCtrl,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepPurple),
              ),
              const SizedBox(height: 16),
              ...children,
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================
  // MAIN BUILD
  // =========================================================
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userName = user?.displayName ?? user?.email?.split('@').first ?? "User";
    final userEmail = user?.email ?? "No email provided";
    final userPhone = user?.phoneNumber ?? "Not linked";

    return Scaffold(
      backgroundColor: const Color(0xFFF5F3FF),
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          "Settings",
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
      ),
      body: ListenableBuilder(
        listenable: _settings,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            children: [
              // Header description
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 12),
                child: Text(
                  "Manage your account, safety and app preferences",
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                ),
              ),

              // =======================================================
              // SECTION 1 — ACCOUNT
              // =======================================================
              _buildSectionCard(
                title: "Account",
                icon: Icons.person_rounded,
                children: [
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.deepPurple.shade100,
                      child: const Icon(Icons.person, color: Colors.deepPurple),
                    ),
                    title: Text(userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(userEmail, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.email_outlined, color: Colors.deepPurple),
                    title: const Text("Email"),
                    trailing: Text(userEmail, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.phone_outlined, color: Colors.deepPurple),
                    title: const Text("Phone Number"),
                    trailing: Text(userPhone, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.logout_rounded, color: Colors.red),
                    title: const Text("Logout", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                    onTap: _confirmLogout,
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // =======================================================
              // SECTION 2 — EMERGENCY SETTINGS
              // =======================================================
              _buildSectionCard(
                title: "Emergency Settings",
                icon: Icons.emergency_rounded,
                children: [
                  ListTile(
                    leading: const Icon(Icons.contacts_rounded, color: Colors.pink),
                    title: const Text("Emergency Contacts"),
                    subtitle: const Text("Manage primary contacts receiving live SOS", style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const EmergencyContactScreen()),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.timer_outlined, color: Colors.deepOrange),
                    title: const Text("SOS Countdown"),
                    subtitle: Text("${_settings.sosCountdown} seconds before auto-dispatch", style: const TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                    onTap: _showCountdownSelector,
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.verified_outlined, color: Colors.deepPurple),
                    title: const Text("SOS Confirmation"),
                    subtitle: const Text("Prompt before triggering manual emergency action", style: TextStyle(fontSize: 12)),
                    value: _settings.sosConfirmation,
                    activeThumbColor: Colors.deepPurple,
                    onChanged: (val) => _settings.setSosConfirmation(val),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.message_outlined, color: Colors.indigo),
                    title: const Text("Default Emergency Message"),
                    subtitle: Text(
                      _settings.emergencyMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: const Icon(Icons.edit_outlined, size: 18, color: Colors.deepPurple),
                    onTap: _showEditEmergencyMessageDialog,
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // =======================================================
              // SECTION 3 — SAFETY PROTECTION
              // =======================================================
              _buildSectionCard(
                title: "Safety Protection",
                icon: Icons.shield_rounded,
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.shield_outlined, color: Colors.deepPurple),
                    title: const Text("AI Guardian Engine"),
                    subtitle: const Text("Multi-signal contextual safety correlation", style: TextStyle(fontSize: 12)),
                    value: _settings.aiGuardianEnabled,
                    activeThumbColor: Colors.deepPurple,
                    onChanged: (val) => _settings.setAiGuardianEnabled(val),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.sensors_rounded, color: Colors.teal),
                    title: const Text("Movement Detection"),
                    subtitle: const Text("Kinetic struggle and violent acceleration monitoring", style: TextStyle(fontSize: 12)),
                    value: _settings.movementDetectionEnabled,
                    activeThumbColor: Colors.teal,
                    onChanged: (val) => _settings.setMovementDetectionEnabled(val),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.record_voice_over_rounded, color: Colors.blue),
                    title: const Text("Voice Detection"),
                    subtitle: const Text("Emergency keyword listener ('Help', 'SOS')", style: TextStyle(fontSize: 12)),
                    value: _settings.voiceDetectionEnabled,
                    activeThumbColor: Colors.blue,
                    onChanged: (val) => _settings.setVoiceDetectionEnabled(val),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.directions_car_rounded, color: Colors.cyan),
                    title: const Text("Transport Detection"),
                    subtitle: const Text("Transit vibration filter & unexpected route monitor", style: TextStyle(fontSize: 12)),
                    value: _settings.transportDetectionEnabled,
                    activeThumbColor: Colors.cyan,
                    onChanged: (val) => _settings.setTransportDetectionEnabled(val),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.gpp_good_rounded, color: Colors.green),
                    title: const Text("Protection Mode"),
                    subtitle: Text(
                      _settings.protectionMode ? "Active background monitoring" : "Paused",
                      style: TextStyle(fontSize: 12, color: _settings.protectionMode ? Colors.green : Colors.grey),
                    ),
                    value: _settings.protectionMode,
                    activeThumbColor: Colors.green,
                    onChanged: (val) => _settings.setProtectionMode(val),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // =======================================================
              // SECTION 4 — LOCATION & SHARING
              // =======================================================
              _buildSectionCard(
                title: "Location & Sharing",
                icon: Icons.location_on_rounded,
                children: [
                  ListTile(
                    leading: const Icon(Icons.my_location_rounded, color: Colors.green),
                    title: const Text("Live GPS Location"),
                    subtitle: const Text("View and broadcast real-time coordinates", style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LiveLocationScreen()),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.security_outlined, color: Colors.indigo),
                    title: const Text("Location Permission"),
                    subtitle: Text(
                      _locationPermission == LocationPermission.always || _locationPermission == LocationPermission.whileInUse
                          ? "Granted"
                          : _locationPermission == LocationPermission.deniedForever
                              ? "Permanently Denied"
                              : "Denied",
                      style: TextStyle(
                        fontSize: 12,
                        color: _locationPermission == LocationPermission.always || _locationPermission == LocationPermission.whileInUse
                            ? Colors.green
                            : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    trailing: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () async {
                        await Geolocator.openAppSettings();
                        _checkPermissions();
                      },
                      child: const Text("Manage", style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.share_location_rounded, color: Colors.deepPurple),
                    title: const Text("Location Sharing"),
                    subtitle: const Text("Attach live Google Maps links to emergency dispatches", style: TextStyle(fontSize: 12)),
                    value: _settings.locationSharing,
                    activeThumbColor: Colors.deepPurple,
                    onChanged: (val) => _settings.setLocationSharing(val),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.fmd_good_outlined, color: Colors.orange),
                    title: const Text("Safe Zone Geofencing"),
                    subtitle: const Text("Custom perimeter safety tracking", style: TextStyle(fontSize: 12)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text("Coming Soon", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber.shade900)),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // =======================================================
              // SECTION 5 — NEARBY HELP
              // =======================================================
              _buildSectionCard(
                title: "Nearby Help",
                icon: Icons.local_police_rounded,
                children: [
                  ListTile(
                    leading: const Icon(Icons.local_police_outlined, color: Colors.indigo),
                    title: const Text("Nearby Police & Help Points"),
                    subtitle: const Text("Locate verified police stations and emergency helplines", style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const NearbyPoliceScreen()),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.info_outline_rounded, color: Colors.deepPurple),
                    title: const Text("Emergency Information Guide"),
                    subtitle: const Text("How contacts, police dispatch, and SOS work", style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                    onTap: () {
                      _showInfoModal(
                        title: "Emergency Information Guide",
                        children: const [
                          Text("• 🚨 SOS Emergency: Dispatches urgent SMS with live GPS link to your saved contacts and provides instant 112 police dialer.", style: TextStyle(fontSize: 13, height: 1.4)),
                          SizedBox(height: 8),
                          Text("• 📍 Live Location: Reverse geocodes your address and shares real-time location link via SMS/WhatsApp.", style: TextStyle(fontSize: 13, height: 1.4)),
                          SizedBox(height: 8),
                          Text("• 🏛️ Nearby Police: Searches real-time OpenStreetMap police stations within 12km without simulated data.", style: TextStyle(fontSize: 13, height: 1.4)),
                          SizedBox(height: 8),
                          Text("• 🛡️ AI Guardian: Central decision fusion that correlates voice keywords, kinetic struggle, and unusual route deviations without false alarms.", style: TextStyle(fontSize: 13, height: 1.4)),
                        ],
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // =======================================================
              // SECTION 6 — NOTIFICATIONS
              // =======================================================
              _buildSectionCard(
                title: "Notifications",
                icon: Icons.notifications_active_rounded,
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.health_and_safety_outlined, color: Colors.deepPurple),
                    title: const Text("Safety Alerts"),
                    subtitle: const Text("Heartbeat and system safety status updates", style: TextStyle(fontSize: 12)),
                    value: _settings.safetyAlerts,
                    activeThumbColor: Colors.deepPurple,
                    onChanged: (val) => _settings.setSafetyAlerts(val),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.warning_amber_rounded, color: Colors.red),
                    title: const Text("Emergency Alerts"),
                    subtitle: const Text("High priority emergency notifications", style: TextStyle(fontSize: 12)),
                    value: _settings.emergencyAlerts,
                    activeThumbColor: Colors.red,
                    onChanged: (val) => _settings.setEmergencyAlerts(val),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.vibration_rounded, color: Colors.teal),
                    title: const Text("Movement Alerts"),
                    subtitle: const Text("Sudden acceleration and abnormal kinetic spikes", style: TextStyle(fontSize: 12)),
                    value: _settings.movementAlerts,
                    activeThumbColor: Colors.teal,
                    onChanged: (val) => _settings.setMovementAlerts(val),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.record_voice_over_outlined, color: Colors.blue),
                    title: const Text("Voice Alerts"),
                    subtitle: const Text("Trigger notifications when distress keywords are detected", style: TextStyle(fontSize: 12)),
                    value: _settings.voiceAlerts,
                    activeThumbColor: Colors.blue,
                    onChanged: (val) => _settings.setVoiceAlerts(val),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.groups_outlined, color: Colors.orange),
                    title: const Text("Community Alerts"),
                    subtitle: const Text("Nearby safety notices and emergency broadcasts", style: TextStyle(fontSize: 12)),
                    value: _settings.communityAlerts,
                    activeThumbColor: Colors.orange,
                    onChanged: (val) => _settings.setCommunityAlerts(val),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // =======================================================
              // SECTION 7 — PRIVACY & SECURITY
              // =======================================================
              _buildSectionCard(
                title: "Privacy & Security",
                icon: Icons.lock_outline_rounded,
                children: [
                  ListTile(
                    leading: const Icon(Icons.security_rounded, color: Colors.indigo),
                    title: const Text("App Permissions"),
                    subtitle: const Text("Location, Microphone, Camera, Sensors status", style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                    onTap: () {
                      _showInfoModal(
                        title: "App Permissions",
                        children: [
                          _buildPermissionRow("Location (GPS)", "Real-time coordinate tracking & police discovery", true),
                          const Divider(),
                          _buildPermissionRow("Microphone", "Emergency voice keyword recognition ('Help', 'SOS')", true),
                          const Divider(),
                          _buildPermissionRow("Camera", "Emergency Video & Shield recording", true),
                          const Divider(),
                          _buildPermissionRow("Motion Sensors", "3-Axis Accelerometer and Gyroscope motion telemetry", true),
                          const Divider(),
                          _buildPermissionRow("SMS & Phone", "Direct emergency SMS dispatch and helpline dialer", true),
                          const SizedBox(height: 12),
                          Center(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => Geolocator.openAppSettings(),
                              child: const Text("Open System App Settings"),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined, color: Colors.deepPurple),
                    title: const Text("Privacy Information"),
                    subtitle: const Text("How your personal data is protected", style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                    onTap: () {
                      _showInfoModal(
                        title: "Privacy Information",
                        children: const [
                          Text("SheShield AI is engineered with a privacy-first architecture:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          SizedBox(height: 8),
                          Text("1. On-Device Sensor Processing: Motion and accelerometer signals are evaluated entirely locally on your phone.", style: TextStyle(fontSize: 12.5, height: 1.35)),
                          SizedBox(height: 6),
                          Text("2. Location Privacy: GPS coordinates are only shared externally when you trigger an SOS, broadcast live location, or search nearby help.", style: TextStyle(fontSize: 12.5, height: 1.35)),
                          SizedBox(height: 6),
                          Text("3. No Background Recording Selling: Voice detection strictly looks for emergency triggers and does not store conversational audio.", style: TextStyle(fontSize: 12.5, height: 1.35)),
                        ],
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.data_usage_rounded, color: Colors.teal),
                    title: const Text("Data Usage"),
                    subtitle: const Text("Summary of account & telemetry usage", style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                    onTap: () {
                      _showInfoModal(
                        title: "Data Usage Breakdown",
                        children: const [
                          Text("• Account Data: Email and display name stored securely in Firebase Authentication.", style: TextStyle(fontSize: 12.5, height: 1.35)),
                          SizedBox(height: 6),
                          Text("• Emergency Contacts: Stored securely in your device local storage (SharedPreferences).", style: TextStyle(fontSize: 12.5, height: 1.35)),
                          SizedBox(height: 6),
                          Text("• Safety Telemetry: Minimal status updates synced to Firestore when AI Guardian session is active.", style: TextStyle(fontSize: 12.5, height: 1.35)),
                        ],
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.delete_forever_rounded, color: Colors.red),
                    title: const Text("Delete Account", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    subtitle: const Text("Permanently remove your account and stored data", style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                    onTap: _confirmDeleteAccount,
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // =======================================================
              // SECTION 8 — APPEARANCE
              // =======================================================
              _buildSectionCard(
                title: "Appearance",
                icon: Icons.palette_outlined,
                children: [
                  ListTile(
                    leading: const Icon(Icons.brightness_6_outlined, color: Colors.deepPurple),
                    title: const Text("Theme"),
                    subtitle: Text(
                      _settings.themeMode == ThemeMode.light
                          ? "Light Mode"
                          : _settings.themeMode == ThemeMode.dark
                              ? "Dark Mode"
                              : "System Default",
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                    onTap: _showThemeSelector,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.language_rounded, color: Colors.blue),
                    title: const Text("Language"),
                    subtitle: Text(
                      _settings.language == 'ta' ? "தமிழ் (Tamil)" : "English (Default)",
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                    onTap: _showLanguageSelector,
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // =======================================================
              // SECTION 9 — SOUND & VIBRATION
              // =======================================================
              _buildSectionCard(
                title: "Sound & Vibration",
                icon: Icons.volume_up_outlined,
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.notifications_active_outlined, color: Colors.deepPurple),
                    title: const Text("Alert Sound"),
                    subtitle: const Text("Play audible tone on status transitions", style: TextStyle(fontSize: 12)),
                    value: _settings.alertSound,
                    activeThumbColor: Colors.deepPurple,
                    onChanged: (val) => _settings.setAlertSound(val),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.vibration_rounded, color: Colors.indigo),
                    title: const Text("Haptic Vibration"),
                    subtitle: const Text("Vibrate device during alerts & countdown", style: TextStyle(fontSize: 12)),
                    value: _settings.vibration,
                    activeThumbColor: Colors.indigo,
                    onChanged: (val) => _settings.setVibration(val),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.campaign_outlined, color: Colors.red),
                    title: const Text("SOS Emergency Siren"),
                    subtitle: const Text("Sound high-volume alarm when SOS triggers", style: TextStyle(fontSize: 12)),
                    value: _settings.sosSound,
                    activeThumbColor: Colors.red,
                    onChanged: (val) => _settings.setSosSound(val),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // =======================================================
              // SECTION 10 — HELP & SUPPORT
              // =======================================================
              _buildSectionCard(
                title: "Help & Support",
                icon: Icons.help_outline_rounded,
                children: [
                  ListTile(
                    leading: const Icon(Icons.psychology_outlined, color: Colors.deepPurple),
                    title: const Text("How SheShield AI Works"),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                    onTap: () {
                      _showInfoModal(
                        title: "How SheShield AI Works",
                        children: const [
                          Text("• SOS Emergency: Instant multi-channel SMS alert + live map link to contacts and 112 hotline.", style: TextStyle(fontSize: 13, height: 1.4)),
                          SizedBox(height: 8),
                          Text("• Live GPS Location: Real-time coordinate acquisition with safe fallback and direct sharing.", style: TextStyle(fontSize: 13, height: 1.4)),
                          SizedBox(height: 8),
                          Text("• Movement Detection: Continuous kinetic analysis for struggle, assault, and falls.", style: TextStyle(fontSize: 13, height: 1.4)),
                          SizedBox(height: 8),
                          Text("• Transport Detection: Distinguishes vehicular movement from emergencies without false triggers.", style: TextStyle(fontSize: 13, height: 1.4)),
                          SizedBox(height: 8),
                          Text("• AI Guardian: Central multi-signal fusion engine connecting voice, sensors, and location.", style: TextStyle(fontSize: 13, height: 1.4)),
                        ],
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.menu_book_outlined, color: Colors.green),
                    title: const Text("Safety Guide"),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                    onTap: () {
                      _showInfoModal(
                        title: "Safety Best Practices",
                        children: const [
                          Text("1. Save at least 2 verified emergency contacts.", style: TextStyle(fontSize: 13, height: 1.4)),
                          SizedBox(height: 6),
                          Text("2. Keep Location (GPS) turned ON in phone quick settings for instant live tracking.", style: TextStyle(fontSize: 13, height: 1.4)),
                          SizedBox(height: 6),
                          Text("3. Enable 'Shake Shield' so you can vigorously shake your phone to activate the shield in danger.", style: TextStyle(fontSize: 13, height: 1.4)),
                          SizedBox(height: 6),
                          Text("4. Keep AI Guardian in 'Protection Active' mode while travelling alone at night.", style: TextStyle(fontSize: 13, height: 1.4)),
                        ],
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.build_outlined, color: Colors.orange),
                    title: const Text("Troubleshooting"),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                    onTap: () {
                      _showInfoModal(
                        title: "Troubleshooting Guide",
                        children: const [
                          Text("• GPS Not Locking: Ensure phone Location is enabled and test with clear sky view.", style: TextStyle(fontSize: 13, height: 1.4)),
                          SizedBox(height: 6),
                          Text("• Permissions Denied: Open App Permissions in Settings and tap 'Manage' to grant access.", style: TextStyle(fontSize: 13, height: 1.4)),
                          SizedBox(height: 6),
                          Text("• Voice Recognition: Ensure Microphone permission is granted and speak clearly.", style: TextStyle(fontSize: 13, height: 1.4)),
                          SizedBox(height: 6),
                          Text("• Nearby Police Empty: If no stations are within 12km, use the 'CALL POLICE 112' direct button.", style: TextStyle(fontSize: 13, height: 1.4)),
                        ],
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.support_agent_outlined, color: Colors.blue),
                    title: const Text("Contact Support"),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                    onTap: () {
                      _showInfoModal(
                        title: "SheShield AI Support",
                        children: const [
                          Text("Need assistance or have feedback?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          SizedBox(height: 8),
                          Text("Email Support: support@sheshieldai.org", style: TextStyle(fontSize: 13)),
                          SizedBox(height: 4),
                          Text("Emergency Helpline: 112 (National Police Emergency)", style: TextStyle(fontSize: 13, color: Colors.red, fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Text("Women Helpline: 1091 (24/7 Women SOS)", style: TextStyle(fontSize: 13, color: Colors.pink, fontWeight: FontWeight.bold)),
                        ],
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // =======================================================
              // SECTION 11 — ABOUT
              // =======================================================
              _buildSectionCard(
                title: "About",
                icon: Icons.info_outline_rounded,
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.shield_rounded, color: Colors.deepPurple, size: 24),
                    ),
                    title: const Text("SheShield AI", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: const Text("Your Personal AI Safety Companion\nVersion 1.0.0+1 • Build 2026", style: TextStyle(fontSize: 12, height: 1.3)),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Text(
                      "Built with Flutter, Firebase, OpenStreetMap & On-Device AI Guardian Fusion Engine.\nDesigned to protect and empower women with intelligent, reliable, zero-false-alarm safety technology.",
                      style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700, height: 1.4),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  // =========================================================
  // HELPER WIDGETS
  // =========================================================

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
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
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 14, bottom: 6),
            child: Row(
              children: [
                Icon(icon, size: 18, color: Colors.deepPurple),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildPermissionRow(String name, String description, bool isEssential) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_rounded, color: Colors.green.shade700, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text(description, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
