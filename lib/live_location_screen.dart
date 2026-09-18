import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'emergency_contact.dart';
import 'nearby_help_screen.dart';
import 'nearby_help_service.dart';
import 'ai_guardian_service.dart';

/// Represents the possible states of location acquisition
enum LocationStateStatus {
  loading,
  active,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  error,
}

class LiveLocationScreen extends StatefulWidget {
  const LiveLocationScreen({super.key});

  @override
  State<LiveLocationScreen> createState() => _LiveLocationScreenState();
}

class _LiveLocationScreenState extends State<LiveLocationScreen> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  String _currentAddress = "Locating your exact address...";
  String _errorMessage = "";
  LocationStateStatus _status = LocationStateStatus.loading;
  bool _isBroadcasting = false;
  StreamSubscription<Position>? _positionStreamSub;
  bool _mapFailed = false;

  @override
  void initState() {
    super.initState();
    _initLiveLocationTracking();
  }

  @override
  void dispose() {
    _positionStreamSub?.cancel();
    _positionStreamSub = null;
    _mapController?.dispose();
    _mapController = null;
    super.dispose();
  }

  // =========================================================
  // LOCATION INITIALIZATION & SAFE PERMISSION HANDLING
  // =========================================================
  Future<void> _initLiveLocationTracking() async {
    if (!mounted) return;

    setState(() {
      _status = LocationStateStatus.loading;
      _errorMessage = "";
      _mapFailed = false;
    });

    // Cancel existing stream before starting a new one
    await _positionStreamSub?.cancel();
    _positionStreamSub = null;

    try {
      // 1. Check if GPS / Location services are enabled on the device
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _status = LocationStateStatus.serviceDisabled;
          _errorMessage = "Location / GPS is turned off. Please turn on Location/GPS to use Live Location.";
        });
        return;
      }

      // 2. Check and request location permissions safely
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        setState(() {
          _status = LocationStateStatus.permissionDenied;
          _errorMessage = "Location permission is required to use Live Location.";
        });
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _status = LocationStateStatus.permissionDeniedForever;
          _errorMessage = "Location permission is permanently denied. Please enable it in App Settings.";
        });
        return;
      }

      // 3. Obtain initial GPS Position safely
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        );
      } catch (e) {
        debugPrint("getCurrentPosition timeout or error: $e, trying last known position...");
        position = await Geolocator.getLastKnownPosition();
      }

      if (position == null) {
        // One more fallback attempt with lower accuracy
        try {
          position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 5),
            ),
          );
        } catch (_) {}
      }

      if (position == null) {
        if (!mounted) return;
        setState(() {
          _status = LocationStateStatus.error;
          _errorMessage = "Unable to lock GPS signal. Please check your sky view or network connection and retry.";
        });
        return;
      }

      // 4. Update position & UI
      await _updatePosition(position);

      if (!mounted) return;
      setState(() {
        _status = LocationStateStatus.active;
      });

      // 5. Start real-time continuous position stream
      _positionStreamSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 4, // update every 4 meters
        ),
      ).listen(
        (Position newPos) {
          _updatePosition(newPos);
        },
        onError: (err) {
          debugPrint("Location stream error: $err");
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint("Error initializing live location: $e");
      if (mounted) {
        setState(() {
          _status = LocationStateStatus.error;
          _errorMessage = "An unexpected error occurred: ${e.toString()}";
        });
      }
    }
  }

  Future<void> _updatePosition(Position pos) async {
    _currentPosition = pos;

    // Reverse geocode to human-readable address
    final address = await NearbyHelpService.getAddressFromCoordinates(pos.latitude, pos.longitude);

    // Broadcast telemetry to central AI Guardian
    AIGuardianService.instance.updateLocationSignal(
      latitude: pos.latitude,
      longitude: pos.longitude,
      address: address,
      speedKmh: pos.speed >= 0 ? pos.speed * 3.6 : 0.0,
      state: LocationSignalState.active,
    );

    if (mounted) {
      setState(() {
        _currentAddress = address;
      });

      if (_mapController != null) {
        try {
          _mapController!.animateCamera(
            CameraUpdate.newLatLng(
              LatLng(pos.latitude, pos.longitude),
            ),
          );
        } catch (e) {
          debugPrint("Error animating map camera: $e");
        }
      }
    }
  }

  // =========================================================
  // URL LAUNCHER HELPER (SAFE LAUNCH)
  // =========================================================
  Future<void> _safeLaunchUrl(Uri uri, {String? errorMessage}) async {
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback without canLaunch check (some Android intent filters require direct launch)
        final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!launched && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red,
              content: Text(errorMessage ?? "Could not open external app."),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Launch URL error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text(errorMessage ?? "Error launching application: $e"),
          ),
        );
      }
    }
  }

  // =========================================================
  // SHARE LIVE LOCATION VIA SMS / CONTACTS
  // =========================================================
  Future<void> _shareLocationToContacts() async {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text("GPS location not available yet. Please wait..."),
        ),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList("contacts") ?? [];

    if (!mounted) return;

    final message = NearbyHelpService.formatEmergencyMessage(
      lat: _currentPosition!.latitude,
      lng: _currentPosition!.longitude,
      address: _currentAddress,
      customNote: "LIVE LOCATION SHARE: Here is my current real-time GPS location.",
    );

    if (rawList.isEmpty) {
      // If no contacts are saved, open the device SMS app directly with the pre-filled message
      final Uri smsUri = Uri.parse("sms:?body=${Uri.encodeComponent(message)}");
      await _safeLaunchUrl(
        smsUri,
        errorMessage: "No emergency contacts configured. Could not open SMS app.",
      );
      return;
    }

    setState(() => _isBroadcasting = true);

    try {
      int sentCount = 0;
      for (String item in rawList) {
        final contact = EmergencyContact.fromJson(item);
        if (contact.phone.isNotEmpty) {
          final sent = await NearbyHelpService.sendEmergencySms(
            phone: contact.phone,
            message: message,
          );
          if (sent) sentCount++;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: sentCount > 0 ? Colors.green : Colors.orange,
            content: Text(
              sentCount > 0
                  ? "🚨 Live Location sent to $sentCount contact(s) via SMS!"
                  : "Opened SMS app to send Live Location.",
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error sharing location: $e");
    } finally {
      if (mounted) setState(() => _isBroadcasting = false);
    }
  }

  // =========================================================
  // SHARE LIVE LOCATION VIA WHATSAPP
  // =========================================================
  Future<void> _shareViaWhatsApp() async {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text("Location not ready yet. Please wait..."),
        ),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList("contacts") ?? [];

    final message = NearbyHelpService.formatEmergencyMessage(
      lat: _currentPosition!.latitude,
      lng: _currentPosition!.longitude,
      address: _currentAddress,
      customNote: "LIVE LOCATION UPDATE from SheShield AI",
    );

    if (rawList.isNotEmpty) {
      final primary = EmergencyContact.fromJson(rawList.first);
      await NearbyHelpService.sendEmergencyWhatsApp(
        phone: primary.phone,
        message: message,
      );
    } else {
      await NearbyHelpService.sendEmergencyWhatsApp(
        phone: "",
        message: message,
      );
    }
  }

  // =========================================================
  // OPEN IN GOOGLE MAPS APP
  // =========================================================
  Future<void> _openInGoogleMaps() async {
    if (_currentPosition == null) return;
    final lat = _currentPosition!.latitude;
    final lng = _currentPosition!.longitude;
    final Uri mapsUri = Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lng");
    await _safeLaunchUrl(mapsUri, errorMessage: "Could not open Google Maps app.");
  }

  // =========================================================
  // COPY LOCATION LINK TO CLIPBOARD
  // =========================================================
  Future<void> _copyLocationLink() async {
    if (_currentPosition == null) return;
    final lat = _currentPosition!.latitude;
    final lng = _currentPosition!.longitude;
    final link = "https://maps.google.com/?q=$lat,$lng";

    await Clipboard.setData(ClipboardData(text: link));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.deepPurple,
          content: Text("📋 Live Google Maps link copied to clipboard!"),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // =========================================================
  // UI: ERROR & PERMISSION STATES (SAFE RECOVERY SCREENS)
  // =========================================================
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
              child: Icon(icon, size: 68, color: iconColor),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: onPrimaryPressed,
                icon: const Icon(Icons.check_circle_outline, size: 20),
                label: Text(
                  primaryButtonText,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
            if (secondaryButtonText != null && onSecondaryPressed != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.deepPurple,
                    side: const BorderSide(color: Colors.deepPurple, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: onSecondaryPressed,
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  label: Text(
                    secondaryButtonText,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // =========================================================
  // UI: MAP VIEW OR SAFE FALLBACK
  // =========================================================
  Widget _buildMapSection() {
    if (_mapFailed || _currentPosition == null) {
      return _buildMapFallbackCard();
    }

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
            ),
            zoom: 16.5,
          ),
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          zoomControlsEnabled: false,
          compassEnabled: true,
          mapToolbarEnabled: false,
          onMapCreated: (GoogleMapController controller) {
            _mapController = controller;
          },
          markers: {
            Marker(
              markerId: const MarkerId("current_location"),
              position: LatLng(
                _currentPosition!.latitude,
                _currentPosition!.longitude,
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
              infoWindow: InfoWindow(
                title: "My Live Location",
                snippet: _currentAddress,
              ),
            ),
          },
        ),

        // Map Control Floating Pill
        Positioned(
          top: 14,
          right: 14,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.my_location_rounded, color: Colors.deepPurple, size: 20),
                  tooltip: "Center on My Location",
                  onPressed: () {
                    if (_mapController != null && _currentPosition != null) {
                      _mapController!.animateCamera(
                        CameraUpdate.newLatLngZoom(
                          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                          16.5,
                        ),
                      );
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.open_in_new_rounded, color: Colors.deepPurple, size: 20),
                  tooltip: "Open in Google Maps App",
                  onPressed: _openInGoogleMaps,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMapFallbackCard() {
    return Container(
      width: double.infinity,
      color: Colors.deepPurple.shade50,
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade100,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.map_rounded, size: 48, color: Colors.deepPurple),
            ),
            const SizedBox(height: 16),
            const Text(
              "Live GPS Telemetry Active",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepPurple),
            ),
            const SizedBox(height: 6),
            Text(
              "Coordinates: ${_currentPosition?.latitude.toStringAsFixed(5)}, ${_currentPosition?.longitude.toStringAsFixed(5)}",
              style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _openInGoogleMaps,
              icon: const Icon(Icons.map_outlined),
              label: const Text("Open in Google Maps App"),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // MAIN BUILD
  // =========================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F6FA),
      appBar: AppBar(
        title: const Text(
          "Live GPS Location",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.deepPurple,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh Location",
            onPressed: _initLiveLocationTracking,
          ),
          IconButton(
            icon: const Icon(Icons.local_police_outlined),
            tooltip: "Nearby Police Stations",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NearbyHelpScreen()),
              );
            },
          ),
        ],
      ),
      body: _buildBodyContent(),
    );
  }

  Widget _buildBodyContent() {
    switch (_status) {
      case LocationStateStatus.loading:
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.deepPurple),
              SizedBox(height: 16),
              Text(
                "Acquiring Live GPS Signal...",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.deepPurple),
              ),
              SizedBox(height: 6),
              Text(
                "Connecting to satellites and safety signals...",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        );

      case LocationStateStatus.serviceDisabled:
        return _buildStateScreen(
          icon: Icons.location_disabled_rounded,
          iconColor: Colors.orange,
          title: "Location / GPS is Disabled",
          description: "Please turn on Location/GPS to enable live location tracking and safety broadcast.",
          primaryButtonText: "Turn on GPS / Location",
          onPrimaryPressed: () async {
            await Geolocator.openLocationSettings();
            _initLiveLocationTracking();
          },
          secondaryButtonText: "Retry",
          onSecondaryPressed: _initLiveLocationTracking,
        );

      case LocationStateStatus.permissionDenied:
        return _buildStateScreen(
          icon: Icons.location_off_rounded,
          iconColor: Colors.red,
          title: "Location Permission Required",
          description: "Location permission is required to use Live Location and share your coordinates during an emergency.",
          primaryButtonText: "Grant Location Permission",
          onPrimaryPressed: _initLiveLocationTracking,
          secondaryButtonText: "Retry",
          onSecondaryPressed: _initLiveLocationTracking,
        );

      case LocationStateStatus.permissionDeniedForever:
        return _buildStateScreen(
          icon: Icons.settings_suggest_rounded,
          iconColor: Colors.red.shade700,
          title: "Permission Permanently Denied",
          description: "Location permission has been permanently denied in settings. Please open App Settings and enable Location permission for SheShield AI.",
          primaryButtonText: "Open App Settings",
          onPrimaryPressed: () async {
            await Geolocator.openAppSettings();
          },
          secondaryButtonText: "Check Permission Again",
          onSecondaryPressed: _initLiveLocationTracking,
        );

      case LocationStateStatus.error:
        return _buildStateScreen(
          icon: Icons.warning_amber_rounded,
          iconColor: Colors.red,
          title: "Unable to Lock Location",
          description: _errorMessage.isNotEmpty ? _errorMessage : "Unable to acquire GPS coordinates at this time.",
          primaryButtonText: "Retry GPS Search",
          onPrimaryPressed: _initLiveLocationTracking,
        );

      case LocationStateStatus.active:
        return Column(
          children: [
            // GOOGLE MAP OR FALLBACK
            Expanded(
              child: _buildMapSection(),
            ),

            // LOCATION DETAILS & ACTION PANEL
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, -3),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: SafeArea(
                top: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status & Address
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.gps_fixed, color: Colors.green, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    "Live Location Active",
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                _currentAddress,
                                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade800),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Coordinates & Accuracy Telemetry
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Text(
                            "Lat: ${_currentPosition?.latitude.toStringAsFixed(5) ?? '--'}, Lng: ${_currentPosition?.longitude.toStringAsFixed(5) ?? '--'}",
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
                          ),
                          const Spacer(),
                          Text(
                            "Accuracy: ±${_currentPosition?.accuracy.toStringAsFixed(1) ?? '--'}m",
                            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Main Action Buttons: Share Live SOS (SMS) & WhatsApp
                    Row(
                      children: [
                        // Share to Contacts (SMS)
                        Expanded(
                          flex: 3,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: _isBroadcasting ? null : _shareLocationToContacts,
                            icon: _isBroadcasting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Icon(Icons.emergency_share_rounded),
                            label: Text(
                              _isBroadcasting ? "Sending..." : "Share Live SOS",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // WhatsApp Share
                        Expanded(
                          flex: 2,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF25D366),
                              side: const BorderSide(color: Color(0xFF25D366), width: 1.5),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: _shareViaWhatsApp,
                            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                            label: const Text(
                              "WhatsApp",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Secondary Action Buttons: Copy Link & Nearby Police
                    Row(
                      children: [
                        // Copy Map Link
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.grey.shade800,
                              side: BorderSide(color: Colors.grey.shade300),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _copyLocationLink,
                            icon: const Icon(Icons.copy_rounded, size: 16),
                            label: const Text(
                              "Copy Link",
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Nearby Police Stations Button
                        Expanded(
                          flex: 2,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.deepPurple,
                              side: const BorderSide(color: Colors.deepPurple, width: 1.5),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const NearbyHelpScreen()),
                              );
                            },
                            icon: const Icon(Icons.local_police_rounded, size: 18),
                            label: const Text(
                              "Nearby Police & Help",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
    }
  }
}