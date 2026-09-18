import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'emergency_contact.dart';
import 'nearby_help_service.dart';

class EmergencyContactScreen extends StatefulWidget {
  const EmergencyContactScreen({super.key});

  @override
  State<EmergencyContactScreen> createState() => _EmergencyContactScreenState();
}

class _EmergencyContactScreenState extends State<EmergencyContactScreen> {
  static const int maxContacts = 10;

  List<EmergencyContact> contacts = [];
  bool isLoading = true;
  bool isBroadcasting = false;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  String selectedRelationship = "Family";
  bool isPrimaryContact = false;

  final List<String> relationshipOptions = [
    "Family",
    "Parent / Guardian",
    "Partner / Spouse",
    "Friend",
    "Police / Authority",
    "Doctor / Hospital",
    "Neighbor",
    "Other",
  ];

  @override
  void initState() {
    super.initState();
    loadContacts();
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  // =========================================================
  // STORAGE (SharedPreferences)
  // =========================================================
  Future<void> loadContacts() async {
    setState(() => isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList("contacts") ?? [];

    List<EmergencyContact> loaded = [];
    for (String item in rawList) {
      if (loaded.length >= maxContacts) break; // Ensure maximum of 10
      try {
        loaded.add(EmergencyContact.fromJson(item));
      } catch (_) {
        if (item.contains(" - ")) {
          final parts = item.split(" - ");
          loaded.add(EmergencyContact(name: parts.first, phone: parts.last));
        } else {
          loaded.add(EmergencyContact(name: "Contact", phone: item));
        }
      }
    }

    if (mounted) {
      setState(() {
        contacts = loaded;
        isLoading = false;
      });
    }
  }

  Future<void> saveContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = contacts.take(maxContacts).map((c) => c.toJson()).toList();
    await prefs.setStringList("contacts", rawList);
  }

  // =========================================================
  // ADD / EDIT / DELETE CONTACTS (1 to 10 limit)
  // =========================================================
  void _openAddOrEditContactDialog({EmergencyContact? existingContact, int? editIndex}) {
    if (existingContact == null && contacts.length >= maxContacts) {
      _showLimitReachedDialog();
      return;
    }

    if (existingContact != null) {
      nameController.text = existingContact.name;
      phoneController.text = existingContact.phone;
      selectedRelationship = existingContact.relationship;
      isPrimaryContact = existingContact.isPrimary;
    } else {
      nameController.clear();
      phoneController.clear();
      selectedRelationship = "Family";
      isPrimaryContact = contacts.isEmpty; // First contact is primary by default
    }

    final int targetSlotNumber = editIndex != null ? (editIndex + 1) : (contacts.length + 1);

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      existingContact != null ? Icons.edit_note : Icons.person_add_alt_1,
                      color: Colors.deepPurple,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          existingContact != null
                              ? "Edit Contact #$targetSlotNumber"
                              : "Add Emergency Contact",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                        ),
                        Text(
                          "Slot $targetSlotNumber of $maxContacts",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.deepPurple.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: "Full Name",
                        hintText: "e.g. Mom, Brother, Officer Roy",
                        prefixIcon: const Icon(Icons.person_outline, color: Colors.deepPurple),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: "Phone Number",
                        hintText: "10-digit mobile number",
                        prefixIcon: const Icon(Icons.phone_outlined, color: Colors.deepPurple),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: selectedRelationship,
                      decoration: InputDecoration(
                        labelText: "Relationship",
                        prefixIcon: const Icon(Icons.category_outlined, color: Colors.deepPurple),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      items: relationshipOptions.map((opt) {
                        return DropdownMenuItem(value: opt, child: Text(opt));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedRelationship = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isPrimaryContact ? Colors.deepPurple.shade50 : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isPrimaryContact ? Colors.deepPurple.shade300 : Colors.grey.shade300,
                        ),
                      ),
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          "Set as Primary Contact",
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        subtitle: const Text(
                          "First priority for rapid SOS calls & alerts",
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        value: isPrimaryContact,
                        activeThumbColor: Colors.deepPurple,
                        onChanged: (val) {
                          setDialogState(() => isPrimaryContact = val);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  onPressed: () {
                    final name = nameController.text.trim();
                    final phone = phoneController.text.trim().replaceAll(' ', '').replaceAll('-', '');

                    if (name.isEmpty || phone.isEmpty) {
                      _showSnackBar("Please enter both Name and Phone Number", Colors.red);
                      return;
                    }

                    if (phone.length < 7) {
                      _showSnackBar("Please enter a valid phone number (at least 7 digits)", Colors.red);
                      return;
                    }

                    // Check for duplicate phone numbers in other slots
                    final duplicate = contacts.asMap().entries.any((entry) {
                      if (existingContact != null && editIndex != null && entry.key == editIndex) {
                        return false;
                      }
                      return entry.value.phone.replaceAll(' ', '').replaceAll('-', '') == phone;
                    });

                    if (duplicate) {
                      _showSnackBar("A contact with this phone number already exists", Colors.orange.shade800);
                      return;
                    }

                    setState(() {
                      if (isPrimaryContact) {
                        // Unset primary from others
                        contacts = contacts.map((c) => c.copyWith(isPrimary: false)).toList();
                      }

                      if (existingContact != null && editIndex != null) {
                        contacts[editIndex] = existingContact.copyWith(
                          name: name,
                          phone: phone,
                          relationship: selectedRelationship,
                          isPrimary: isPrimaryContact,
                        );
                      } else {
                        contacts.add(
                          EmergencyContact(
                            name: name,
                            phone: phone,
                            relationship: selectedRelationship,
                            isPrimary: isPrimaryContact,
                          ),
                        );
                      }
                    });

                    saveContacts();
                    Navigator.pop(dialogCtx);

                    _showSnackBar(
                      existingContact != null
                          ? "Contact #$targetSlotNumber updated!"
                          : "Contact #$targetSlotNumber added! (${contacts.length}/$maxContacts configured)",
                      Colors.green,
                    );
                  },
                  child: Text(existingContact != null ? "Save Changes" : "Add Contact"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showLimitReachedDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orange, size: 28),
            SizedBox(width: 10),
            Text("Contact Limit Reached", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          "You can configure between 1 and 10 emergency contacts maximum for safety broadcast. You currently have all 10 slots filled.\n\nPlease edit or delete an existing contact to add a new one.",
          style: TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Got It"),
          ),
        ],
      ),
    );
  }

  void deleteContact(int index) {
    final contact = contacts[index];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Delete Emergency Contact", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          "Are you sure you want to remove Contact #${index + 1} (${contact.name})?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              setState(() {
                contacts.removeAt(index);
                // If deleted contact was primary and others exist, set first as primary
                if (contact.isPrimary && contacts.isNotEmpty) {
                  contacts[0] = contacts[0].copyWith(isPrimary: true);
                }
              });
              saveContacts();
              Navigator.pop(ctx);
              _showSnackBar("Contact deleted (${contacts.length}/$maxContacts remaining)", Colors.orange.shade800);
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, Color bgColor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: bgColor,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // =========================================================
  // ACTIONS: SEND LIVE LOCATION TO SINGLE CONTACT
  // =========================================================
  Future<void> _sendLiveLocationToContact(EmergencyContact contact, {bool viaWhatsApp = false}) async {
    await [Permission.location, Permission.sms].request();

    Position? pos;
    try {
      pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
    } catch (_) {
      try {
        pos = await Geolocator.getLastKnownPosition();
      } catch (_) {}
    }

    if (pos == null) {
      _showSnackBar("Could not retrieve GPS location. Ensure location is enabled.", Colors.red);
      return;
    }

    final address = await NearbyHelpService.getAddressFromCoordinates(pos.latitude, pos.longitude);
    final message = NearbyHelpService.formatEmergencyMessage(
      lat: pos.latitude,
      lng: pos.longitude,
      address: address,
      customNote: "Emergency Alert sent to ${contact.name}. Please check my live location immediately!",
    );

    if (viaWhatsApp) {
      await NearbyHelpService.sendEmergencyWhatsApp(
        phone: contact.phone,
        message: message,
      );
    } else {
      final sent = await NearbyHelpService.sendEmergencySms(
        phone: contact.phone,
        message: message,
      );

      _showSnackBar(
        sent
            ? "🚨 Live Location SOS sent to ${contact.name} (${contact.phone})!"
            : "Opened SMS app to send Live Location to ${contact.name}.",
        sent ? Colors.green : Colors.orange,
      );
    }
  }

  // =========================================================
  // BROADCAST TO ALL EMERGENCY CONTACTS (1 to 10 contacts)
  // =========================================================
  Future<void> _broadcastLiveLocationToAll() async {
    if (contacts.isEmpty) {
      _showSnackBar("No emergency contacts configured. Please add at least 1 contact.", Colors.red);
      return;
    }

    setState(() => isBroadcasting = true);

    try {
      await [Permission.location, Permission.sms].request();

      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        );
      } catch (_) {
        pos = await Geolocator.getLastKnownPosition();
      }

      if (pos == null) {
        _showSnackBar("Unable to fetch location. Please turn on GPS.", Colors.red);
        setState(() => isBroadcasting = false);
        return;
      }

      final address = await NearbyHelpService.getAddressFromCoordinates(pos.latitude, pos.longitude);
      final message = NearbyHelpService.formatEmergencyMessage(
        lat: pos.latitude,
        lng: pos.longitude,
        address: address,
        customNote: "BROADCAST SOS: I need immediate help! Live location attached.",
      );

      int successCount = 0;
      for (final contact in contacts) {
        final sent = await NearbyHelpService.sendEmergencySms(
          phone: contact.phone,
          message: message,
        );
        if (sent) successCount++;
      }

      _showSnackBar(
        successCount > 0
            ? "🚨 Live Location SOS broadcast to $successCount of ${contacts.length} emergency contacts!"
            : "Failed to broadcast SMS. Please check SMS permissions.",
        successCount > 0 ? Colors.green : Colors.red,
      );
    } catch (e) {
      debugPrint("Broadcast error: $e");
    } finally {
      if (mounted) setState(() => isBroadcasting = false);
    }
  }

  // =========================================================
  // BUILD CONTACT CARD WITH 1-10 NUMBERING
  // =========================================================
  Widget _buildContactCard(EmergencyContact contact, int index) {
    final int slotNumber = index + 1;
    Color badgeColor = Colors.deepPurple;
    IconData badgeIcon = Icons.family_restroom;

    if (contact.relationship.contains("Police") || contact.relationship.contains("Authority")) {
      badgeColor = Colors.blue.shade700;
      badgeIcon = Icons.local_police;
    } else if (contact.relationship.contains("Doctor") || contact.relationship.contains("Hospital")) {
      badgeColor = Colors.green.shade700;
      badgeIcon = Icons.local_hospital;
    } else if (contact.relationship.contains("Friend")) {
      badgeColor = Colors.teal;
      badgeIcon = Icons.people;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: contact.isPrimary
            ? BorderSide(color: Colors.deepPurple.shade400, width: 2)
            : BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Slot Number Badge (1 to 10)
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: contact.isPrimary ? Colors.deepPurple : Colors.grey.shade100,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: contact.isPrimary ? Colors.deepPurple : Colors.grey.shade300,
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      "#$slotNumber",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: contact.isPrimary ? Colors.white : Colors.deepPurple.shade800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Icon for Relationship
                CircleAvatar(
                  radius: 20,
                  backgroundColor: badgeColor.withValues(alpha: 0.15),
                  child: Icon(badgeIcon, color: badgeColor, size: 22),
                ),
                const SizedBox(width: 12),

                // Name & Phone
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              contact.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (contact.isPrimary) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.deepPurple,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                "PRIMARY",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "${contact.phone} • ${contact.relationship}",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // Menu for Edit / Delete
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.grey),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (val) {
                    if (val == 'edit') {
                      _openAddOrEditContactDialog(existingContact: contact, editIndex: index);
                    } else if (val == 'delete') {
                      deleteContact(index);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 18, color: Colors.deepPurple),
                          SizedBox(width: 8),
                          Text("Edit Contact"),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text("Delete", style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // Action Buttons
            Row(
              children: [
                // 1. Send Live Location SOS via SMS
                Expanded(
                  flex: 3,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => _sendLiveLocationToContact(contact, viaWhatsApp: false),
                    icon: const Icon(Icons.emergency_share, size: 16),
                    label: const Text(
                      "GPS SOS",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // 2. WhatsApp
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF25D366),
                      side: const BorderSide(color: Color(0xFF25D366)),
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => _sendLiveLocationToContact(contact, viaWhatsApp: true),
                    icon: const Icon(Icons.chat_bubble_outline, size: 15),
                    label: const Text(
                      "WhatsApp",
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // 3. Call
                IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.green.shade50,
                    foregroundColor: Colors.green.shade800,
                    padding: const EdgeInsets.all(8),
                  ),
                  icon: const Icon(Icons.phone, size: 20),
                  tooltip: "Call ${contact.name}",
                  onPressed: () => NearbyHelpService.makePhoneCall(contact.phone),
                ),
              ],
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
    final bool isMaxReached = contacts.length >= maxContacts;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F6FA),
      appBar: AppBar(
        title: const Text(
          "Emergency Contacts",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.deepPurple,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // 1-10 Slot indicator in AppBar
          Container(
            margin: const EdgeInsets.only(right: 14, top: 12, bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white38),
            ),
            child: Center(
              child: Text(
                "${contacts.length}/$maxContacts Slots",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: isMaxReached ? Colors.grey : Colors.deepPurple,
        foregroundColor: Colors.white,
        onPressed: () {
          if (isMaxReached) {
            _showLimitReachedDialog();
          } else {
            _openAddOrEditContactDialog();
          }
        },
        icon: Icon(isMaxReached ? Icons.block : Icons.person_add),
        label: Text(
          isMaxReached ? "Max 10 Added" : "Add Contact (${contacts.length}/$maxContacts)",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.deepPurple))
          : Column(
              children: [
                // Top Capacity & Broadcast Banner (1 to 10 contacts format)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.deepPurple.shade800, Colors.deepPurple.shade600],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.deepPurple.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.shield, color: Colors.amberAccent, size: 28),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Emergency SOS Network",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  contacts.isEmpty
                                      ? "Configure 1 to 10 contacts for emergency alerts"
                                      : "${contacts.length} of $maxContacts contact slots configured",
                                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Capacity Progress Bar (1 to 10 slots)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: contacts.length / maxContacts,
                          minHeight: 6,
                          backgroundColor: Colors.white.withValues(alpha: 0.25),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            contacts.isEmpty
                                ? Colors.redAccent
                                : (contacts.length >= maxContacts ? Colors.amberAccent : Colors.greenAccent),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Broadcast Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: contacts.isEmpty ? Colors.grey.shade700 : Colors.red,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: (isBroadcasting || contacts.isEmpty) ? null : _broadcastLiveLocationToAll,
                          icon: isBroadcasting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.send_rounded),
                          label: Text(
                            isBroadcasting
                                ? "Broadcasting to ${contacts.length} Contact(s)..."
                                : (contacts.isEmpty
                                    ? "Add Contacts to Enable Broadcast"
                                    : "Broadcast Live GPS to All (${contacts.length})"),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Contacts List (1 to 10 contacts)
                Expanded(
                  child: contacts.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.contact_phone_outlined, size: 68, color: Colors.grey.shade400),
                                const SizedBox(height: 14),
                                const Text(
                                  "No Emergency Contacts Added",
                                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "You can add between 1 and 10 trusted contacts (family, friends, or police) to automatically receive SOS alerts and Live GPS.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.deepPurple,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  ),
                                  onPressed: () => _openAddOrEditContactDialog(),
                                  icon: const Icon(Icons.person_add),
                                  label: const Text("Add First Contact (#1)"),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 80),
                          itemCount: contacts.length,
                          itemBuilder: (context, index) {
                            return _buildContactCard(contacts[index], index);
                          },
                        ),
                ),
              ],
            ),
    );
  }
}