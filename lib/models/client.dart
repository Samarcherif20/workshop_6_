class Client {
  final String id;
  final String? name;
  final DateTime createdAt;
  final double? lat;
  final double? lng;
  final bool isSynced; // Optional: useful if you track sync status

  Client({
    required this.id,
    required this.name,
    required this.createdAt,
    this.lat,
    this.lng,
    this.isSynced = false,
  });

  /// Construct from a map (e.g. from Supabase or local DB)
  factory Client.fromMap(Map<String, dynamic> map) {
  try {
    return Client(
      id: (map['id'] ?? map['uuid'] ?? '').toString(), // ✅ supports both
      name: map['name'] ?? 'Unknown',
      createdAt: map['created_at'] is String
          ? DateTime.parse(map['created_at'])
          : (map['created_at'] ?? DateTime.now()),
      lat: _parseDouble(map['lat']),
      lng: _parseDouble(map['lng']),
      isSynced: map['is_synced'] == 1 || map['is_synced'] == true,
    );
  } catch (e) {
    print('❌ Error parsing Client: $e \nMap: $map');
    rethrow;
  }
}


  /// Convert to a map (e.g. for storage or API upload)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt.toIso8601String(),
      'lat': lat,
      'lng': lng,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  @override
  String toString() {
    return 'Client(id: $id, name: $name, createdAt: $createdAt, lat: $lat, lng: $lng, isSynced: $isSynced)';
  }

  /// Helper: safely parse numeric values
  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
  }

  operator [](String other) {}
}
