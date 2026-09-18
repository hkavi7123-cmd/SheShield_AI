import 'dart:convert';

class EmergencyContact {
  final String id;
  final String name;
  final String phone;
  final String relationship; // e.g. "Family", "Police", "Friend", "Doctor", "Guardian"
  final bool isPrimary;

  EmergencyContact({
    String? id,
    required this.name,
    required this.phone,
    this.relationship = "Family",
    this.isPrimary = false,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'relationship': relationship,
      'isPrimary': isPrimary,
    };
  }

  factory EmergencyContact.fromMap(Map<String, dynamic> map) {
    return EmergencyContact(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      relationship: map['relationship']?.toString() ?? 'Family',
      isPrimary: map['isPrimary'] == true,
    );
  }

  String toJson() => json.encode(toMap());

  factory EmergencyContact.fromJson(dynamic source) {
    if (source is String) {
      // Check if it's JSON format
      if (source.trim().startsWith('{')) {
        try {
          return EmergencyContact.fromMap(json.decode(source));
        } catch (_) {}
      }
      // Handle legacy format: "Name - Phone" or plain phone
      if (source.contains(" - ")) {
        final parts = source.split(" - ");
        return EmergencyContact(
          name: parts.first.trim(),
          phone: parts.last.trim(),
        );
      }
      return EmergencyContact(name: "Contact", phone: source.trim());
    } else if (source is Map<String, dynamic>) {
      return EmergencyContact.fromMap(source);
    }
    return EmergencyContact(name: "Contact", phone: "");
  }

  EmergencyContact copyWith({
    String? id,
    String? name,
    String? phone,
    String? relationship,
    bool? isPrimary,
  }) {
    return EmergencyContact(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      relationship: relationship ?? this.relationship,
      isPrimary: isPrimary ?? this.isPrimary,
    );
  }
}