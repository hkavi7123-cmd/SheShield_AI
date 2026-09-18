import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

/// Status of location acquisition for police discovery
enum LocationFetchStatus {
  success,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  timeoutOrError,
}

/// Result object returned by location acquisition
class LocationFetchResult {
  final LocationFetchStatus status;
  final Position? position;
  final String? errorMessage;

  const LocationFetchResult({
    required this.status,
    this.position,
    this.errorMessage,
  });

  bool get isSuccess => status == LocationFetchStatus.success && position != null;
}

/// Data model representing a verified police station.
class PoliceStation {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double distanceInKm;
  final String? phone;
  final String? placeId;

  PoliceStation({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.distanceInKm,
    this.phone,
    this.placeId,
  });

  factory PoliceStation.fromJson({
    required Map<String, dynamic> json,
    required double userLat,
    required double userLng,
  }) {
    final double lat = (json['lat'] as num).toDouble();
    final double lng = (json['lon'] ?? json['lng'] as num).toDouble();
    final tags = json['tags'] as Map<String, dynamic>? ?? {};

    final String name = tags['name'] ??
        tags['name:en'] ??
        json['display_name']?.toString().split(',').first ??
        "Local Police Station";

    // Format address parts cleanly
    List<String> addressParts = [];
    if (tags['addr:street'] != null && tags['addr:street'].toString().trim().isNotEmpty) {
      addressParts.add(tags['addr:street'].toString().trim());
    }
    if (tags['addr:suburb'] != null && tags['addr:suburb'].toString().trim().isNotEmpty) {
      addressParts.add(tags['addr:suburb'].toString().trim());
    }
    if (tags['addr:city'] != null && tags['addr:city'].toString().trim().isNotEmpty) {
      addressParts.add(tags['addr:city'].toString().trim());
    }
    if (tags['addr:postcode'] != null && tags['addr:postcode'].toString().trim().isNotEmpty) {
      addressParts.add(tags['addr:postcode'].toString().trim());
    }

    String address = addressParts.isNotEmpty
        ? addressParts.join(", ")
        : (json['display_name'] ?? "Coordinates: ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}");

    // Phone parsing
    String? phone = tags['phone'] ??
        tags['contact:phone'] ??
        tags['emergency:phone'] ??
        (tags['country'] == 'IN' ? '112' : null);

    final double distanceInMeters = Geolocator.distanceBetween(
      userLat,
      userLng,
      lat,
      lng,
    );

    return PoliceStation(
      id: json['id']?.toString() ?? "${lat}_$lng",
      name: name,
      address: address,
      latitude: lat,
      longitude: lng,
      distanceInKm: distanceInMeters / 1000.0,
      phone: phone,
      placeId: json['place_id']?.toString(),
    );
  }
}

/// Service handling nearby police station discovery and emergency routing.
class NearbyPoliceService {
  // ===========================================================================
  // LOCATION PERMISSION & CURRENT COORDINATES (SAFE RETRIEVAL)
  // ===========================================================================

  /// Obtains current GPS position with full permission & service verification.
  static Future<LocationFetchResult> getCurrentLocation() async {
    try {
      // 1. Verify if Location Services (GPS) are turned on
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const LocationFetchResult(
          status: LocationFetchStatus.serviceDisabled,
          errorMessage: "Location / GPS is disabled. Please turn on Location/GPS to find nearby police stations.",
        );
      }

      // 2. Verify and request location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        return const LocationFetchResult(
          status: LocationFetchStatus.permissionDenied,
          errorMessage: "Location permission is required to find nearby police stations.",
        );
      }

      if (permission == LocationPermission.deniedForever) {
        return const LocationFetchResult(
          status: LocationFetchStatus.permissionDeniedForever,
          errorMessage: "Location permission is permanently denied. Please enable it in App Settings.",
        );
      }

      // 3. Acquire GPS Position safely with timeout
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        );
      } catch (e) {
        debugPrint("High accuracy GPS timeout, trying last known position: $e");
        position = await Geolocator.getLastKnownPosition();
      }

      if (position == null) {
        // Fallback attempt with medium accuracy
        try {
          position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 5),
            ),
          );
        } catch (_) {}
      }

      if (position != null) {
        return LocationFetchResult(
          status: LocationFetchStatus.success,
          position: position,
        );
      } else {
        return const LocationFetchResult(
          status: LocationFetchStatus.timeoutOrError,
          errorMessage: "Unable to lock GPS coordinates. Please ensure you have a clear sky view and retry.",
        );
      }
    } catch (e) {
      debugPrint("Error in getCurrentLocation: $e");
      return LocationFetchResult(
        status: LocationFetchStatus.timeoutOrError,
        errorMessage: "An unexpected error occurred while accessing GPS: ${e.toString()}",
      );
    }
  }

  // ===========================================================================
  // REAL NEARBY POLICE STATION DISCOVERY ENGINE (NO FAKE DATA)
  // ===========================================================================

  /// Fetches real nearby police stations around [latitude], [longitude] within [radiusKm].
  ///
  /// Queries Overpass OpenStreetMap API with a Nominatim fallback. Returns an empty
  /// list if no verified stations are located within the radius.
  static Future<List<PoliceStation>> fetchNearbyPoliceStations({
    required double latitude,
    required double longitude,
    double radiusKm = 12.0,
  }) async {
    final int radiusMeters = (radiusKm * 1000).toInt();

    // 1. Try Overpass OpenStreetMap API
    try {
      final overpassUrl = Uri.parse("https://overpass-api.de/api/interpreter");
      final query =
          '[out:json][timeout:10];(node["amenity"="police"](around:$radiusMeters,$latitude,$longitude);way["amenity"="police"](around:$radiusMeters,$latitude,$longitude););out center 25;';

      final response = await http
          .post(overpassUrl, body: query)
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final elements = data['elements'] as List? ?? [];

        if (elements.isNotEmpty) {
          List<PoliceStation> stations = [];
          for (var element in elements) {
            double? lat = (element['lat'] as num?)?.toDouble() ??
                (element['center']?['lat'] as num?)?.toDouble();
            double? lng = (element['lon'] as num?)?.toDouble() ??
                (element['center']?['lon'] as num?)?.toDouble();

            if (lat != null && lng != null) {
              element['lat'] = lat;
              element['lon'] = lng;
              stations.add(
                PoliceStation.fromJson(
                  json: element,
                  userLat: latitude,
                  userLng: longitude,
                ),
              );
            }
          }

          if (stations.isNotEmpty) {
            // Sort by distance ascending
            stations.sort((a, b) => a.distanceInKm.compareTo(b.distanceInKm));
            return stations;
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("Overpass police query failed, trying Nominatim fallback: $e");
      }
    }

    // 2. Nominatim Search Fallback
    try {
      final nominatimUrl = Uri.parse(
        "https://nominatim.openstreetmap.org/search?q=police+station&format=json&lat=$latitude&lon=$longitude&limit=20&addressdetails=1",
      );

      final response = await http.get(
        nominatimUrl,
        headers: {'User-Agent': 'SheShieldAI/1.0 (Emergency Police Search)'},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final List results = json.decode(utf8.decode(response.bodyBytes));
        List<PoliceStation> stations = [];

        for (var item in results) {
          stations.add(
            PoliceStation.fromJson(
              json: item,
              userLat: latitude,
              userLng: longitude,
            ),
          );
        }

        if (stations.isNotEmpty) {
          stations.sort((a, b) => a.distanceInKm.compareTo(b.distanceInKm));
          return stations;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("Nominatim police query error: $e");
      }
    }

    // Return empty list if no real stations are found (no fake data)
    return [];
  }

  // ===========================================================================
  // CALL, NAVIGATION & SHARE ACTIONS (SAFE URL LAUNCHING)
  // ===========================================================================

  /// Safely opens the phone dialer with the station's phone number without auto-calling.
  static Future<bool> makePhoneCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleanPhone.isEmpty) return false;

    final Uri callUri = Uri.parse("tel:$cleanPhone");
    try {
      if (await canLaunchUrl(callUri)) {
        await launchUrl(callUri, mode: LaunchMode.externalApplication);
        return true;
      } else {
        // Direct attempt for Android intent
        return await launchUrl(callUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint("Error making phone call: $e");
      return false;
    }
  }

  /// Opens turn-by-turn navigation in external maps (Google Maps).
  static Future<bool> openNavigation({
    required double latitude,
    required double longitude,
    required String name,
  }) async {
    final encodedName = Uri.encodeComponent(name);
    final List<Uri> uris = [
      Uri.parse("https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude&destination_place_id=$encodedName"),
      Uri.parse("google.navigation:q=$latitude,$longitude"),
      Uri.parse("https://maps.google.com/?q=$latitude,$longitude"),
      Uri.parse("geo:$latitude,$longitude?q=$latitude,$longitude($encodedName)"),
    ];

    for (final uri in uris) {
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return true;
        }
      } catch (_) {}
    }

    // Try last fallback directly
    try {
      final fallbackUri = Uri.parse("https://maps.google.com/?q=$latitude,$longitude");
      return await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint("Error opening navigation: $e");
      return false;
    }
  }

  /// Shares verified police station information and map link via external sharing/SMS.
  static Future<bool> sharePoliceStation({
    required PoliceStation station,
  }) async {
    final mapUrl = "https://maps.google.com/?q=${station.latitude},${station.longitude}";
    final buffer = StringBuffer();
    buffer.writeln("🚨 POLICE STATION INFORMATION - SheShield AI");
    buffer.writeln("🏛️ Station: ${station.name}");
    buffer.writeln("📍 Address: ${station.address}");
    buffer.writeln("📏 Approx Distance: ${station.distanceInKm.toStringAsFixed(1)} km away");
    if (station.phone != null && station.phone!.isNotEmpty) {
      buffer.writeln("📞 Phone: ${station.phone}");
    }
    buffer.writeln("🗺️ Google Maps Directions:");
    buffer.writeln(mapUrl);

    final text = buffer.toString();
    final Uri shareUri = Uri.parse("sms:?body=${Uri.encodeComponent(text)}");

    try {
      if (await canLaunchUrl(shareUri)) {
        await launchUrl(shareUri, mode: LaunchMode.externalApplication);
        return true;
      } else {
        return await launchUrl(shareUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint("Error sharing police station info: $e");
      return false;
    }
  }
}
