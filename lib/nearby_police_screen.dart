import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'nearby_police_service.dart';
import 'nearby_help_service.dart';

/// Screen displaying real nearby police stations sorted by distance from current GPS coordinates.
class NearbyPoliceScreen extends StatefulWidget {
  const NearbyPoliceScreen({super.key});

  @override
  State<NearbyPoliceScreen> createState() => _NearbyPoliceScreenState();
}

class _NearbyPoliceScreenState extends State<NearbyPoliceScreen> {
  bool _isLoading = true;
  LocationFetchStatus? _locationStatus;
  String? _errorMessage;
  Position? _currentPosition;
  String _currentAddress = "Locating your exact address...";
  List<PoliceStation> _policeStations = [];

  @override
  void initState() {
    super.initState();
    _loadNearbyPoliceStations();
  }

  Future<void> _loadNearbyPoliceStations() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _locationStatus = null;
      _errorMessage = null;
    });

    try {
      // 1. Get GPS Location safely
      final result = await NearbyPoliceService.getCurrentLocation();
      if (!result.isSuccess || result.position == null) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _locationStatus = result.status;
          _errorMessage = result.errorMessage ?? "Unable to acquire location.";
        });
        return;
      }

      final position = result.position!;
      _currentPosition = position;
      _locationStatus = LocationFetchStatus.success;

      // 2. Resolve human-readable address
      final address = await NearbyHelpService.getAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );

      // 3. Query real nearby police stations (no fake data)
      final stations = await NearbyPoliceService.fetchNearbyPoliceStations(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      if (!mounted) return;

      setState(() {
        _currentAddress = address;
        _policeStations = stations;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading nearby police stations: $e");
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _locationStatus = LocationFetchStatus.timeoutOrError;
        _errorMessage =
            "Unable to load nearby police stations. Please check your internet connection and try again.";
      });
    }
  }

  // =========================================================
  // ACTIONS: CALL, NAVIGATE, SHARE (WITH USER NOTIFICATION)
  // =========================================================

  Future<void> _handleCallStation(String phone) async {
    final success = await NearbyPoliceService.makePhoneCall(phone);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text("Could not open phone dialer for $phone."),
        ),
      );
    }
  }

  Future<void> _handleNavigateStation(PoliceStation station) async {
    final success = await NearbyPoliceService.openNavigation(
      latitude: station.latitude,
      longitude: station.longitude,
      name: station.name,
    );
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: const Text("Could not open external Google Maps navigation."),
        ),
      );
    }
  }

  Future<void> _handleShareStation(PoliceStation station) async {
    final success = await NearbyPoliceService.sharePoliceStation(station: station);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: const Text("Could not open sharing application."),
        ),
      );
    }
  }

  // =========================================================
  // MAIN BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F3FF), // Soft purple background
      appBar: AppBar(
        backgroundColor: Colors.indigo.shade800,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        title: const Text(
          "Nearby Police Stations",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: "Refresh Police Stations",
            onPressed: _loadNearbyPoliceStations,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadNearbyPoliceStations,
          color: Colors.indigo.shade800,
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    // 1. Loading State
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.indigo.shade800),
            const SizedBox(height: 18),
            const Text(
              "Finding nearby police stations...",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Querying verified OpenStreetMap police stations",
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    // 2. GPS Disabled State
    if (_locationStatus == LocationFetchStatus.serviceDisabled) {
      return _buildStateScreen(
        icon: Icons.location_disabled_rounded,
        iconColor: Colors.orange,
        title: "Please turn on Location/GPS",
        description: _errorMessage ?? "Location services are turned off on your device. Please enable GPS to locate nearby police stations.",
        primaryButtonText: "Turn on Location/GPS",
        onPrimaryPressed: () async {
          await Geolocator.openLocationSettings();
          _loadNearbyPoliceStations();
        },
        secondaryButtonText: "Retry",
        onSecondaryPressed: _loadNearbyPoliceStations,
      );
    }

    // 3. Permission Denied State
    if (_locationStatus == LocationFetchStatus.permissionDenied) {
      return _buildStateScreen(
        icon: Icons.location_off_rounded,
        iconColor: Colors.red,
        title: "Location Permission Required",
        description: "Location permission is required to find nearby police stations.",
        primaryButtonText: "Grant Location Permission",
        onPrimaryPressed: _loadNearbyPoliceStations,
        secondaryButtonText: "Retry",
        onSecondaryPressed: _loadNearbyPoliceStations,
      );
    }

    // 4. Permission Permanently Denied State
    if (_locationStatus == LocationFetchStatus.permissionDeniedForever) {
      return _buildStateScreen(
        icon: Icons.settings_suggest_rounded,
        iconColor: Colors.red.shade700,
        title: "Permission Permanently Denied",
        description: "Location permission has been permanently denied in system settings. Please open App Settings and allow Location permission for SheShield AI.",
        primaryButtonText: "Open App Settings",
        onPrimaryPressed: () async {
          await Geolocator.openAppSettings();
        },
        secondaryButtonText: "Check Permission Again",
        onSecondaryPressed: _loadNearbyPoliceStations,
      );
    }

    // 5. Error State
    if (_errorMessage != null && _locationStatus == LocationFetchStatus.timeoutOrError) {
      return _buildStateScreen(
        icon: Icons.error_outline_rounded,
        iconColor: Colors.red.shade400,
        title: "Location / Discovery Error",
        description: _errorMessage!,
        primaryButtonText: "Retry Search",
        onPrimaryPressed: _loadNearbyPoliceStations,
      );
    }

    // 6. Empty State (No stations found within radius)
    if (_policeStations.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off_rounded,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              const Text(
                "No Nearby Police Stations Found",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "No verified police stations were returned within your search radius. You can still fast-dial National Police Emergency 112.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () => _handleCallStation("112"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.phone_in_talk_rounded),
                  label: const Text("CALL POLICE 112", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _loadNearbyPoliceStations,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.indigo.shade800,
                    side: BorderSide(color: Colors.indigo.shade800, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text("RETRY SEARCH", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 7. Success State: Stations List
    final nearestStation = _policeStations.first;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      children: [
        // Emergency Support Summary Banner
        _buildEmergencySupportHeader(nearestStation),

        const SizedBox(height: 14),

        // Police Hotline Quick Bar (112 & 1091)
        _buildQuickDialHotlines(),

        const SizedBox(height: 16),

        // Section Title
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Nearest Police Stations",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Text(
              "${_policeStations.length} found",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.indigo.shade800,
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // Police Station Cards
        ..._policeStations.map((station) => _buildPoliceStationCard(station)),

        const SizedBox(height: 20),
      ],
    );
  }

  // ===========================================================================
  // WIDGET BUILDERS
  // ===========================================================================

  Widget _buildStateScreen({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required String primaryButtonText,
    required VoidCallback onPrimaryPressed,
    String? secondaryButtonText,
    VoidCallback? onSecondaryPressed,
  }) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 64, color: iconColor),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 26),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo.shade800,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: onPrimaryPressed,
                icon: const Icon(Icons.check_circle_outline, size: 20),
                label: Text(
                  primaryButtonText,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                ),
              ),
            ),
            if (secondaryButtonText != null && onSecondaryPressed != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.indigo.shade800,
                    side: BorderSide(color: Colors.indigo.shade800, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: onSecondaryPressed,
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  label: Text(
                    secondaryButtonText,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Emergency Support Header Card
  Widget _buildEmergencySupportHeader(PoliceStation nearestStation) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.indigo.shade100, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withValues(alpha: 0.08),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.local_police_rounded,
                  color: Colors.indigo.shade800,
                  size: 24,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Emergency Support",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      "Nearby police stations based on your current location",
                      style: TextStyle(fontSize: 11.5, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const Divider(height: 20, thickness: 0.8),

          // Current Location
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.my_location_rounded, size: 16, color: Colors.indigo.shade700),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Current Location: ${_currentPosition != null ? '${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}' : 'Locating...'}",
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    Text(
                      _currentAddress,
                      style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Nearest Highlight Badge
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.near_me_rounded, size: 18, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Nearest: ${nearestStation.name} (${nearestStation.distanceInKm.toStringAsFixed(1)} km away)",
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Fast Dial Hotlines Bar
  Widget _buildQuickDialHotlines() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _handleCallStation("112"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.phone_in_talk_rounded, size: 18),
            label: const Text("Police (112)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _handleCallStation("1091"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.pink.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.support_agent_rounded, size: 18),
            label: const Text("Women (1091)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
          ),
        ),
      ],
    );
  }

  /// Police Station Card with CALL, NAVIGATE and SHARE
  Widget _buildPoliceStationCard(PoliceStation station) {
    final bool hasPhone = station.phone != null && station.phone!.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
          // Station Name & Distance Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.local_police_rounded,
                  color: Colors.indigo.shade800,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      station.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      station.address,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "${station.distanceInKm.toStringAsFixed(1)} km",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo.shade900,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Phone Number Status
          Row(
            children: [
              Icon(
                Icons.phone_rounded,
                size: 14,
                color: hasPhone ? Colors.green.shade700 : Colors.grey.shade500,
              ),
              const SizedBox(width: 6),
              Text(
                hasPhone ? station.phone! : "Phone number unavailable",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: hasPhone ? FontWeight.w600 : FontWeight.normal,
                  color: hasPhone ? Colors.black87 : Colors.grey.shade600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Action Buttons: CALL, NAVIGATE & SHARE
          Row(
            children: [
              // CALL Button
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  onPressed: hasPhone
                      ? () => _handleCallStation(station.phone!)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade200,
                    disabledForegroundColor: Colors.grey.shade500,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  icon: const Icon(Icons.call_rounded, size: 15),
                  label: const Text(
                    "CALL",
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // NAVIGATE Button
              Expanded(
                flex: 4,
                child: ElevatedButton.icon(
                  onPressed: () => _handleNavigateStation(station),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo.shade800,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  icon: const Icon(Icons.directions_rounded, size: 15),
                  label: const Text(
                    "NAVIGATE",
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // SHARE Button
              Expanded(
                flex: 3,
                child: OutlinedButton.icon(
                  onPressed: () => _handleShareStation(station),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.indigo.shade800,
                    side: BorderSide(color: Colors.indigo.shade200, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  icon: const Icon(Icons.share_rounded, size: 15),
                  label: const Text(
                    "SHARE",
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
