import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../emergency_contact.dart';
import '../emergency_contact_screen.dart';
import '../home_screen.dart';
import '../nearby_help_service.dart';
import '../nearby_police_screen.dart';
import '../nearby_police_service.dart';
import '../services/emergency_escape_service.dart';
import '../ai_guardian_service.dart';

/// Screen representing the Emergency Escape Mode activated during high-risk safety situations.
class EmergencyEscapeScreen extends StatefulWidget {
  final int initialContactsNotifiedCount;
  final Position? initialPosition;
  final String? initialAddress;

  const EmergencyEscapeScreen({
    super.key,
    this.initialContactsNotifiedCount = 0,
    this.initialPosition,
    this.initialAddress,
  });

  @override
  State<EmergencyEscapeScreen> createState() => _EmergencyEscapeScreenState();
}

class _EmergencyEscapeScreenState extends State<EmergencyEscapeScreen>
    with SingleTickerProviderStateMixin {
  // State
  EmergencyEscapeState _emergencyState = EmergencyEscapeState.escapeMode;
  bool _isLoading = true;
  Position? _currentPosition;
  String _currentAddress = "Acquiring live GPS address...";
  LocationFetchStatus _locationStatus = LocationFetchStatus.success;

  // Emergency summary
  late DateTime _emergencyActivatedTime;
  int _contactsNotifiedCount = 0;
  List<EmergencyContact> _savedContacts = [];

  // Safe places discovery
  List<SafePlaceDestination> _allSafePlaces = [];
  SafePlaceCategory? _selectedFilter;
  SafePlaceDestination? _nearestDestination;

  // Animations
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _emergencyActivatedTime = DateTime.now();
    _contactsNotifiedCount = widget.initialContactsNotifiedCount;
    _currentPosition = widget.initialPosition;
    if (widget.initialAddress != null && widget.initialAddress!.isNotEmpty) {
      _currentAddress = widget.initialAddress!;
    }

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Ensure AI Guardian is in emergency state
    AIGuardianService.instance.triggerManualSos(
      reason: "Emergency Escape Mode activated.",
    );

    _initializeEscapeMode();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // INITIALIZATION & SAFE DATA LOADING
  // ===========================================================================

  Future<void> _initializeEscapeMode() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // 1. Load saved contacts
      _savedContacts = await EmergencyEscapeService.getSavedEmergencyContacts();

      // 2. Get current GPS coordinates if not already provided
      if (_currentPosition == null) {
        final locResult = await EmergencyEscapeService.getCurrentLocation();
        if (locResult.isSuccess && locResult.position != null) {
          _currentPosition = locResult.position;
          _locationStatus = LocationFetchStatus.success;
          _currentAddress = await NearbyHelpService.getAddressFromCoordinates(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          );
        } else {
          _locationStatus = locResult.status;
          _currentAddress = "Live GPS unavailable";
        }
      } else {
        _locationStatus = LocationFetchStatus.success;
        if (_currentAddress == "Acquiring live GPS address...") {
          _currentAddress = await NearbyHelpService.getAddressFromCoordinates(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          );
        }
      }

      // 3. Load nearby safe places
      if (_currentPosition != null) {
        await _loadSafePlaces();
      }
    } catch (e) {
      debugPrint("Error initializing Emergency Escape Mode: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadSafePlaces() async {
    if (_currentPosition == null) return;
    try {
      final places = await EmergencyEscapeService.fetchNearbySafePlaces(
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        filterCategory: _selectedFilter,
      );

      if (!mounted) return;
      setState(() {
        _allSafePlaces = places;
        if (places.isNotEmpty) {
          _nearestDestination = places.first;
        }
      });
    } catch (e) {
      debugPrint("Error loading safe places: $e");
    }
  }

  // ===========================================================================
  // ESCAPE ACTION HANDLERS
  // ===========================================================================

  /// 1. FIND SAFE PLACE (Filter toggling / list focus)
  void _handleFindSafePlace() {
    setState(() {
      _selectedFilter = null; // show all safe places
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Colors.deepPurple,
        content: Text("Showing all nearby verified safe points below."),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// 2. NEARBY POLICE
  void _handleNearbyPolice() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NearbyPoliceScreen()),
    );
  }

  /// 3. NEARBY HOSPITAL
  Future<void> _handleNearbyHospital() async {
    setState(() {
      _selectedFilter = SafePlaceCategory.hospital;
    });
    await _loadSafePlaces();

    if (!mounted) return;
    final hospitals = _allSafePlaces.where((p) => p.category == SafePlaceCategory.hospital).toList();

    if (hospitals.isEmpty) {
      _showHospitalUnavailableDialog();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.teal.shade800,
          content: Text("Found ${hospitals.length} hospital(s) nearby. Listed below."),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showHospitalUnavailableDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.local_hospital_rounded, color: Colors.teal.shade700),
            const SizedBox(width: 8),
            const Text("Nearby Hospital"),
          ],
        ),
        content: const Text(
          "Hospital search is currently unavailable in this exact radius. You can fast-dial Free Medical Emergency Helpline (108).",
          style: TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close"),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _handlePhoneCall("108");
            },
            icon: const Icon(Icons.phone),
            label: const Text("Call Ambulance 108"),
          ),
        ],
      ),
    );
  }

  /// 4. SHARE LIVE LOCATION
  void _handleShareLiveLocation() {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text("GPS location not locked yet. Please wait..."),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.share_location_rounded, color: Colors.green.shade800),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    "Share Live Emergency Location",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                "Current Location: ${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}",
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
              ),
              Text(
                _currentAddress,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 18),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
                  child: const Icon(Icons.sms_rounded, color: Colors.blue),
                ),
                title: const Text("Share via SMS to Contacts", style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text("Dispatches SMS with Google Maps coordinates"),
                onTap: () async {
                  Navigator.pop(ctx);
                  final success = await EmergencyEscapeService.shareEmergencyLocation(
                    latitude: _currentPosition!.latitude,
                    longitude: _currentPosition!.longitude,
                    address: _currentAddress,
                    destinationName: _nearestDestination?.name,
                  );
                  if (!success && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: Colors.red,
                        content: Text("Could not open SMS application."),
                      ),
                    );
                  }
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
                  child: const Icon(Icons.copy_rounded, color: Colors.green),
                ),
                title: const Text("Copy Live Location Link", style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text("Copy Google Maps link to clipboard"),
                onTap: () async {
                  Navigator.pop(ctx);
                  final link = EmergencyEscapeService.formatLocationShareLink(
                    _currentPosition!.latitude,
                    _currentPosition!.longitude,
                  );
                  await Clipboard.setData(ClipboardData(text: link));
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: Colors.deepPurple,
                        content: Text("📋 Location link copied to clipboard!"),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 5. CALL EMERGENCY CONTACT
  void _handleCallEmergencyContact() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.pink.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.contacts_rounded, color: Colors.pink.shade800),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        "Emergency Contacts",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const EmergencyContactScreen()),
                      ).then((_) => _initializeEscapeMode());
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text("Manage"),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_savedContacts.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.person_off_rounded, size: 40, color: Colors.grey.shade500),
                      const SizedBox(height: 8),
                      const Text(
                        "No emergency contacts added.",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Add trusted contacts to alert them during emergencies.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.pink.shade700,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const EmergencyContactScreen()),
                          ).then((_) => _initializeEscapeMode());
                        },
                        icon: const Icon(Icons.add_call),
                        label: const Text("Add Emergency Contacts"),
                      ),
                    ],
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _savedContacts.length,
                    separatorBuilder: (_, index) => const Divider(height: 1),
                    itemBuilder: (ctx, index) {
                      final contact = _savedContacts[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: Colors.pink.shade100,
                          child: Icon(Icons.person, color: Colors.pink.shade800),
                        ),
                        title: Text(contact.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("${contact.relationship} • ${contact.phone}"),
                        trailing: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _handlePhoneCall(contact.phone);
                          },
                          icon: const Icon(Icons.call, size: 16),
                          label: const Text("CALL", style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 6. NAVIGATE TO SAFETY (Launches Google Maps)
  Future<void> _handleNavigateToSafety([SafePlaceDestination? destination]) async {
    final target = destination ?? _nearestDestination;
    if (target == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text("No destination selected. Please select a safer place from the list."),
        ),
      );
      return;
    }

    final success = await EmergencyEscapeService.openNavigation(
      latitude: target.latitude,
      longitude: target.longitude,
      destinationName: target.name,
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text("Could not open external navigation for ${target.name}."),
        ),
      );
    }
  }

  /// Safe Phone Call Helper
  Future<void> _handlePhoneCall(String phone) async {
    final success = await EmergencyEscapeService.makePhoneCall(phone);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text("Could not open phone dialer for $phone."),
        ),
      );
    }
  }

  // ===========================================================================
  // RESOLVE EMERGENCY WORKFLOW
  // ===========================================================================

  void _showResolveEmergencyDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.verified_user_rounded, color: Colors.green, size: 28),
            ),
            const SizedBox(width: 10),
            const Text(
              "Are you safe now?",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: const Text(
          "Resolving this emergency will stop the active escape mode, reset AI Guardian to normal monitoring, and return to the home screen.",
          style: TextStyle(fontSize: 14, height: 1.4, color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            onPressed: () {
              Navigator.pop(dialogCtx);
              _resolveEmergencyAndExit();
            },
            child: const Text(
              "Yes, Resolve",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _resolveEmergencyAndExit() {
    // 1. Reset AI Guardian
    EmergencyEscapeService.resolveEmergency();

    // 2. Mark state as resolved
    setState(() {
      _emergencyState = EmergencyEscapeState.resolved;
    });

    // 3. Clear emergency stack and return to HomeScreen
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  // ===========================================================================
  // MAIN BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _showResolveEmergencyDialog();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF9F7FA),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: const Color(0xFFB71C1C), // High-visibility Emergency Red
          foregroundColor: Colors.white,
          elevation: 2,
          title: Row(
            children: [
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.warning_rounded,
                    color: Color(0xFFB71C1C),
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "🚨 Emergency Active",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    Text(
                      "SheShield Escape Mode",
                      style: TextStyle(fontSize: 11, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: _showResolveEmergencyDialog,
                icon: const Icon(Icons.check_circle, size: 16),
                label: const Text("Resolve", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Color(0xFFB71C1C)),
                    SizedBox(height: 16),
                    Text(
                      "Initializing Emergency Escape Mode...",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    SizedBox(height: 6),
                    Text(
                      "Acquiring GPS & nearest safe destinations",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: _initializeEscapeMode,
                color: const Color(0xFFB71C1C),
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  children: [
                    // 1. REASSURING EMERGENCY BANNER
                    _buildReassuringBanner(),

                    const SizedBox(height: 14),

                    // 2. LIVE EMERGENCY STATUS CHECKLIST
                    _buildLiveEmergencyStatusCard(),

                    const SizedBox(height: 16),

                    // 3. 6 ESCAPE OPTIONS GRID
                    _buildEscapeOptionsGrid(),

                    const SizedBox(height: 16),

                    // 4. NEAREST SAFE DESTINATION FAST-ACTION CARD
                    if (_nearestDestination != null) ...[
                      _buildNearestSafeCard(_nearestDestination!),
                      const SizedBox(height: 16),
                    ],

                    // 5. FILTER CHIPS & SAFE PLACES LIST
                    _buildSafePlacesSection(),

                    const SizedBox(height: 24),

                    // 6. RESOLVE EMERGENCY PROMINENT BUTTON
                    _buildResolveButton(),

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

  /// 1. Reassuring Banner
  Widget _buildReassuringBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.shade900, Colors.red.shade800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shield_rounded,
              color: Colors.amberAccent,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "You are not alone.",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  "Get to a safer place. Follow escape options below.",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 2. Live Emergency Status Checklist Card
  Widget _buildLiveEmergencyStatusCard() {
    final bool hasLocation = _currentPosition != null && _locationStatus == LocationFetchStatus.success;
    final String timeStr =
        "${_emergencyActivatedTime.hour.toString().padLeft(2, '0')}:${_emergencyActivatedTime.minute.toString().padLeft(2, '0')} (UTC+5:30)";

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
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
                "Live Emergency Status",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _emergencyState == EmergencyEscapeState.resolved
                          ? "RESOLVED"
                          : (_emergencyState == EmergencyEscapeState.escapeMode ? "ESCAPE ACTIVE" : "EMERGENCY ACTIVE"),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _emergencyState == EmergencyEscapeState.resolved ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 18, thickness: 0.7),

          // Status Item 1: Emergency Activated
          _buildStatusRow(
            icon: Icons.check_circle_rounded,
            color: Colors.green.shade700,
            title: "Emergency Activated",
            subtitle: "Triggered at $timeStr",
          ),

          const SizedBox(height: 8),

          // Status Item 2: Emergency Contacts Notified
          _buildStatusRow(
            icon: _contactsNotifiedCount > 0
                ? Icons.check_circle_rounded
                : (_savedContacts.isNotEmpty ? Icons.info_outline_rounded : Icons.warning_rounded),
            color: _contactsNotifiedCount > 0
                ? Colors.green.shade700
                : (_savedContacts.isNotEmpty ? Colors.blue.shade700 : Colors.amber.shade800),
            title: _contactsNotifiedCount > 0
                ? "Emergency contacts notified"
                : (_savedContacts.isNotEmpty
                    ? "${_savedContacts.length} Contact(s) ready in app"
                    : "No emergency contacts configured"),
            subtitle: _contactsNotifiedCount > 0
                ? "$_contactsNotifiedCount contact(s) alerted via SMS dispatch"
                : (_savedContacts.isNotEmpty
                    ? "Tap 'Call Emergency Contact' to reach out"
                    : "Tap 'Call Emergency Contact' to add trusted contacts"),
          ),

          const SizedBox(height: 8),

          // Status Item 3: Live Location Available
          _buildStatusRow(
            icon: hasLocation ? Icons.check_circle_rounded : Icons.location_off_rounded,
            color: hasLocation ? Colors.green.shade700 : Colors.red.shade700,
            title: hasLocation ? "Location available" : "Location unavailable",
            subtitle: hasLocation
                ? _currentAddress
                : "Turn on GPS / Location permission to enable live navigation",
          ),

          const SizedBox(height: 8),

          // Status Item 4: AI Guardian Active
          _buildStatusRow(
            icon: Icons.check_circle_rounded,
            color: Colors.green.shade700,
            title: "AI Guardian active",
            subtitle: "Telemetry set to emergency response state",
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              Text(
                subtitle,
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 3. Escape Options Grid (The 6 required buttons)
  Widget _buildEscapeOptionsGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Escape Options",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _buildOptionCard(
              icon: Icons.directions_run_rounded,
              color: Colors.deepOrange.shade700,
              title: "1. FIND SAFE PLACE",
              subtitle: "Nearby verified points",
              onTap: _handleFindSafePlace,
            ),
            const SizedBox(width: 10),
            _buildOptionCard(
              icon: Icons.local_police_rounded,
              color: Colors.indigo.shade800,
              title: "2. NEARBY POLICE",
              subtitle: "Stations & Help Desk",
              onTap: _handleNearbyPolice,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _buildOptionCard(
              icon: Icons.local_hospital_rounded,
              color: Colors.teal.shade700,
              title: "3. NEARBY HOSPITAL",
              subtitle: "Trauma & 24h Medical",
              onTap: _handleNearbyHospital,
            ),
            const SizedBox(width: 10),
            _buildOptionCard(
              icon: Icons.share_location_rounded,
              color: Colors.green.shade700,
              title: "4. SHARE LOCATION",
              subtitle: "Live GPS Link",
              onTap: _handleShareLiveLocation,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _buildOptionCard(
              icon: Icons.phone_in_talk_rounded,
              color: Colors.pink.shade700,
              title: "5. CALL CONTACT",
              subtitle: "Emergency dialer",
              onTap: _handleCallEmergencyContact,
            ),
            const SizedBox(width: 10),
            _buildOptionCard(
              icon: Icons.navigation_rounded,
              color: Colors.blue.shade900,
              title: "6. NAVIGATE SAFETY",
              subtitle: "Google Maps directions",
              onTap: () => _handleNavigateToSafety(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOptionCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 100,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.25), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.06),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey.shade400),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                subtitle,
                style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 4. Nearest Safe Destination Card
  Widget _buildNearestSafeCard(SafePlaceDestination target) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.shade300, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.near_me_rounded, size: 14, color: Colors.green),
                    const SizedBox(width: 4),
                    Text(
                      "NEAREST SAFER POINT • ${target.distanceInKm.toStringAsFixed(1)} KM",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            target.name,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 2),
          Text(
            target.address,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo.shade800,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => _handleNavigateToSafety(target),
                  icon: const Icon(Icons.directions_run_rounded, size: 18),
                  label: const Text(
                    "NAVIGATE NOW",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                  ),
                ),
              ),
              if (target.phone != null && target.phone!.isNotEmpty) ...[
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  onPressed: () => _handlePhoneCall(target.phone!),
                  icon: const Icon(Icons.call, size: 16),
                  label: const Text("CALL", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// 5. Safe Places List Section & Filter Chips
  Widget _buildSafePlacesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Nearby Safer Destinations",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            Text(
              "${_allSafePlaces.length} points",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.indigo.shade800),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip("All", null),
              const SizedBox(width: 6),
              _buildFilterChip("👮 Police", SafePlaceCategory.police),
              const SizedBox(width: 6),
              _buildFilterChip("🏥 Hospital", SafePlaceCategory.hospital),
              const SizedBox(width: 6),
              _buildFilterChip("🛡️ Women Cell", SafePlaceCategory.womenHelpline),
              const SizedBox(width: 6),
              _buildFilterChip("💊 Pharmacy", SafePlaceCategory.pharmacy),
            ],
          ),
        ),

        const SizedBox(height: 10),

        if (_allSafePlaces.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Icon(Icons.location_searching_rounded, size: 40, color: Colors.grey.shade400),
                const SizedBox(height: 10),
                const Text(
                  "No safe destinations found in this filter",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  "Try selecting 'All' or use emergency helplines below.",
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          )
        else
          ..._allSafePlaces.map((place) => _buildSafePlaceCard(place)),
      ],
    );
  }

  Widget _buildFilterChip(String label, SafePlaceCategory? category) {
    final isSelected = _selectedFilter == category;
    return FilterChip(
      selected: isSelected,
      label: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selectedColor: Colors.indigo.shade100,
      backgroundColor: Colors.white,
      checkmarkColor: Colors.indigo.shade800,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isSelected ? Colors.indigo.shade800 : Colors.grey.shade300),
      ),
      onSelected: (selected) {
        setState(() {
          _selectedFilter = selected ? category : null;
        });
        _loadSafePlaces();
      },
    );
  }

  Widget _buildSafePlaceCard(SafePlaceDestination place) {
    final bool hasPhone = place.phone != null && place.phone!.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(place.categoryEmoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.name,
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      place.address,
                      style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "${place.distanceInKm.toStringAsFixed(1)} km",
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 4,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo.shade800,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onPressed: () => _handleNavigateToSafety(place),
                  icon: const Icon(Icons.directions_run_rounded, size: 15),
                  label: const Text("NAVIGATE", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasPhone ? Colors.green.shade700 : Colors.grey.shade300,
                    foregroundColor: hasPhone ? Colors.white : Colors.grey.shade600,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onPressed: hasPhone ? () => _handlePhoneCall(place.phone!) : null,
                  icon: const Icon(Icons.call, size: 14),
                  label: const Text("CALL", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 3,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.indigo.shade800,
                    side: BorderSide(color: Colors.indigo.shade200),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onPressed: () {
                    EmergencyEscapeService.shareEmergencyLocation(
                      latitude: place.latitude,
                      longitude: place.longitude,
                      address: place.address,
                      destinationName: place.name,
                    );
                  },
                  icon: const Icon(Icons.share, size: 14),
                  label: const Text("SHARE", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 6. Resolve Button
  Widget _buildResolveButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green.shade700,
          foregroundColor: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: _showResolveEmergencyDialog,
        icon: const Icon(Icons.verified_user_rounded, size: 22),
        label: const Text(
          "I Am Safe Now (Resolve Emergency)",
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
