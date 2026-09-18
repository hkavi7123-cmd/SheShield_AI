import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'nearby_help_service.dart';

class NearbyHelpScreen extends StatefulWidget {
  const NearbyHelpScreen({super.key});

  @override
  State<NearbyHelpScreen> createState() => _NearbyHelpScreenState();
}

class _NearbyHelpScreenState extends State<NearbyHelpScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  GoogleMapController? _mapController;

  Position? _currentPosition;
  String _currentAddress = "Locating...";
  bool _isLoadingLocation = true;
  bool _isLoadingStations = false;
  List<EmergencyHelpPoint> _helpPoints = [];
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _getUserLocationAndHelpPoints();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _getUserLocationAndHelpPoints() async {
    setState(() {
      _isLoadingLocation = true;
      _isLoadingStations = true;
    });

    try {
      // Check and request location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        if (mounted) {
          setState(() {
            _isLoadingLocation = false;
            _isLoadingStations = false;
            _currentAddress = "Location permission denied";
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.red,
              content: Text("Location permission is required to detect nearby police stations."),
            ),
          );
        }
        return;
      }

      Position pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      _currentPosition = pos;

      // Reverse geocode to get street address
      final address = await NearbyHelpService.getAddressFromCoordinates(pos.latitude, pos.longitude);

      if (mounted) {
        setState(() {
          _currentAddress = address;
          _isLoadingLocation = false;
        });
      }

      // Fetch nearby police stations and help points
      final points = await NearbyHelpService.fetchNearbyHelpPoints(
        userLat: pos.latitude,
        userLng: pos.longitude,
      );

      if (mounted) {
        setState(() {
          _helpPoints = points;
          _isLoadingStations = false;
        });
        _buildMapMarkers(pos, points);
      }
    } catch (e) {
      debugPrint("Error fetching location & help points: $e");
      // Try last known position as fallback
      try {
        final lastPos = await Geolocator.getLastKnownPosition();
        if (lastPos != null && mounted) {
          _currentPosition = lastPos;
          final points = await NearbyHelpService.fetchNearbyHelpPoints(
            userLat: lastPos.latitude,
            userLng: lastPos.longitude,
          );
          setState(() {
            _helpPoints = points;
            _isLoadingLocation = false;
            _isLoadingStations = false;
          });
          _buildMapMarkers(lastPos, points);
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
          _isLoadingStations = false;
        });
      }
    }
  }

  void _buildMapMarkers(Position userPos, List<EmergencyHelpPoint> points) {
    final markers = <Marker>{};

    // User marker
    markers.add(
      Marker(
        markerId: const MarkerId("user_loc"),
        position: LatLng(userPos.latitude, userPos.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(
          title: "Your Live Location",
          snippet: "You are here",
        ),
      ),
    );

    // Police & Help Point markers
    for (final point in points) {
      double hue = BitmapDescriptor.hueRed;
      if (point.type == HelpPointType.hospital) {
        hue = BitmapDescriptor.hueGreen;
      } else if (point.type == HelpPointType.womenHelpline) {
        hue = BitmapDescriptor.hueRose;
      }

      markers.add(
        Marker(
          markerId: MarkerId(point.id),
          position: LatLng(point.latitude, point.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(hue),
          infoWindow: InfoWindow(
            title: point.name,
            snippet: "${point.distanceInKm.toStringAsFixed(1)} km • ${point.phone}",
          ),
          onTap: () {
            _showHelpPointDetailsBottomSheet(point);
          },
        ),
      );
    }

    setState(() {
      _markers = markers;
    });

    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(userPos.latitude, userPos.longitude),
        13.5,
      ),
    );
  }

  // =========================================================
  // ACTIONS: SEND EMERGENCY LIVE LOCATION MESSAGE
  // =========================================================
  void _sendLocationAlertToHelpPoint(EmergencyHelpPoint point) {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text("Location not ready. Please wait..."),
        ),
      );
      return;
    }

    final message = NearbyHelpService.formatEmergencyMessage(
      lat: _currentPosition!.latitude,
      lng: _currentPosition!.longitude,
      address: _currentAddress,
      customNote: "EMERGENCY ALERT dispatched for ${point.name}. Please send immediate assistance!",
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.emergency_share, color: Colors.red, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Send Emergency SOS",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        "To: ${point.name} (${point.phone})",
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                message,
                style: const TextStyle(fontSize: 13, height: 1.4, color: Colors.black87),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                // Direct SMS
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final sent = await NearbyHelpService.sendEmergencySms(
                        phone: point.phone,
                        message: message,
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: sent ? Colors.green : Colors.red,
                            content: Text(
                              sent
                                  ? "🚨 Emergency live location SMS sent to ${point.name}!"
                                  : "Failed to send SMS. Please verify permissions.",
                            ),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.sms_rounded),
                    label: const Text(
                      "Send SMS",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // WhatsApp
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await NearbyHelpService.sendEmergencyWhatsApp(
                        phone: point.phone,
                        message: message,
                      );
                    },
                    icon: const Icon(Icons.chat_bubble_rounded),
                    label: const Text(
                      "WhatsApp",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showHelpPointDetailsBottomSheet(EmergencyHelpPoint point) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    point.type == HelpPointType.hospital
                        ? Icons.local_hospital
                        : Icons.local_police,
                    color: Colors.blue.shade800,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        point.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "${point.typeLabel} • ${point.distanceInKm.toStringAsFixed(1)} km away",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 18, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    point.address,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.phone_outlined, size: 18, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  "Phone: ${point.phone}",
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                // Call
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue.shade800,
                      side: BorderSide(color: Colors.blue.shade800, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      NearbyHelpService.makePhoneCall(point.phone);
                    },
                    icon: const Icon(Icons.call),
                    label: const Text("Call"),
                  ),
                ),
                const SizedBox(width: 10),
                // Directions
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.deepPurple,
                      side: const BorderSide(color: Colors.deepPurple, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      NearbyHelpService.openDirections(
                        destinationLat: point.latitude,
                        destinationLng: point.longitude,
                        label: point.name,
                      );
                    },
                    icon: const Icon(Icons.directions),
                    label: const Text("Directions"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Send SOS
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _sendLocationAlertToHelpPoint(point);
                },
                icon: const Icon(Icons.emergency_share_rounded),
                label: const Text(
                  "Send Live Location SOS",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // BUILD HELP POINT CARD
  // =========================================================
  Widget _buildHelpPointCard(EmergencyHelpPoint point) {
    final bool isPolice = point.type == HelpPointType.police;
    final bool isWomenHelp = point.type == HelpPointType.womenHelpline;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isPolice
              ? Colors.blue.shade200
              : isWomenHelp
                  ? Colors.pink.shade200
                  : Colors.grey.shade200,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: isPolice
                      ? Colors.blue.shade100
                      : isWomenHelp
                          ? Colors.pink.shade100
                          : Colors.green.shade100,
                  child: Icon(
                    isPolice
                        ? Icons.local_police
                        : isWomenHelp
                            ? Icons.support_agent_rounded
                            : Icons.local_hospital,
                    color: isPolice
                        ? Colors.blue.shade800
                        : isWomenHelp
                            ? Colors.pink.shade800
                            : Colors.green.shade800,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              point.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              "${point.distanceInKm.toStringAsFixed(1)} km",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        point.address,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              children: [
                // Call
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black87,
                      side: BorderSide(color: Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => NearbyHelpService.makePhoneCall(point.phone),
                    icon: const Icon(Icons.call, size: 18, color: Colors.green),
                    label: const Text("Call", style: TextStyle(fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 8),
                // Directions
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black87,
                      side: BorderSide(color: Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      NearbyHelpService.openDirections(
                        destinationLat: point.latitude,
                        destinationLng: point.longitude,
                        label: point.name,
                      );
                    },
                    icon: const Icon(Icons.directions, size: 18, color: Colors.blue),
                    label: const Text("Navigate", style: TextStyle(fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 8),
                // Send SOS
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => _sendLocationAlertToHelpPoint(point),
                    icon: const Icon(Icons.emergency_share, size: 18),
                    label: const Text(
                      "Share SOS",
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // HELPLINES TAB
  // =========================================================
  Widget _buildHelplinesTab() {
    final helplines = NearbyHelpService.getEmergencyHelplines();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: helplines.length,
      itemBuilder: (context, index) {
        final item = helplines[index];
        final color = Color(int.parse(item["color"]!));

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      item["number"]!,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: item["number"]!.length > 4 ? 13 : 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item["title"]!,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item["badge"]!,
                              style: TextStyle(
                                color: color,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item["description"]!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.phone_in_talk, color: Colors.green),
                  tooltip: "Call ${item["number"]}",
                  onPressed: () => NearbyHelpService.makePhoneCall(item["number"]!),
                ),
              ],
            ),
          ),
        );
      },
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
          "Nearby Police & Help Points",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.deepPurple,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh Location & Stations",
            onPressed: _getUserLocationAndHelpPoints,
          ),
          IconButton(
            icon: const Icon(Icons.map_outlined),
            tooltip: "Search on Google Maps",
            onPressed: () {
              if (_currentPosition != null) {
                NearbyHelpService.searchPoliceOnGoogleMaps(
                  _currentPosition!.latitude,
                  _currentPosition!.longitude,
                );
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amberAccent,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.local_police_rounded), text: "Police & Safe Points"),
            Tab(icon: Icon(Icons.emergency_rounded), text: "Emergency Helplines"),
          ],
        ),
      ),
      body: _isLoadingLocation
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.deepPurple),
                  SizedBox(height: 16),
                  Text("Acquiring Live GPS Location..."),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                // TAB 1: POLICE STATIONS & MAP
                Column(
                  children: [
                    // Address Banner
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      color: Colors.deepPurple.shade50,
                      child: Row(
                        children: [
                          const Icon(Icons.my_location, color: Colors.deepPurple, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Your Current Address",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.deepPurple,
                                  ),
                                ),
                                Text(
                                  _currentAddress,
                                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Map Section (Top 40%)
                    if (_currentPosition != null)
                      SizedBox(
                        height: 220,
                        child: GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: LatLng(
                              _currentPosition!.latitude,
                              _currentPosition!.longitude,
                            ),
                            zoom: 13.5,
                          ),
                          myLocationEnabled: true,
                          myLocationButtonEnabled: true,
                          zoomControlsEnabled: false,
                          markers: _markers,
                          onMapCreated: (controller) => _mapController = controller,
                        ),
                      ),

                    // Stations List (Bottom 60%)
                    Expanded(
                      child: _isLoadingStations
                          ? const Center(
                              child: CircularProgressIndicator(color: Colors.deepPurple),
                            )
                          : _helpPoints.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.location_off, size: 48, color: Colors.grey.shade400),
                                      const SizedBox(height: 10),
                                      const Text("No nearby points found."),
                                      const SizedBox(height: 8),
                                      ElevatedButton(
                                        onPressed: _getUserLocationAndHelpPoints,
                                        child: const Text("Retry Search"),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.only(top: 8, bottom: 20),
                                  itemCount: _helpPoints.length,
                                  itemBuilder: (context, index) {
                                    return _buildHelpPointCard(_helpPoints[index]);
                                  },
                                ),
                    ),
                  ],
                ),

                // TAB 2: 24/7 HELPLINES
                _buildHelplinesTab(),
              ],
            ),
    );
  }
}
