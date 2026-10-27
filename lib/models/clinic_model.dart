class Clinic {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String phone;
  final double rating;
  final bool isOpen247;
  final String openHours;
  final List<String> services;
  final double distanceKm;

  Clinic({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.phone,
    this.rating = 5.0,
    this.isOpen247 = false,
    this.openHours = "08:00 - 21:00",
    this.services = const [],
    this.distanceKm = 0.0,
  });

  factory Clinic.fromJson(Map<String, dynamic> json) {
    return Clinic(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      phone: json['phone'] as String,
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      isOpen247: (json['isOpen24_7'] as bool?) ?? false,
      openHours: (json['openHours'] as String?) ?? "08:00 - 21:00",
      services: (json['services'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'phone': phone,
      'rating': rating,
      'isOpen24_7': isOpen247,
      'openHours': openHours,
      'services': services,
      'distanceKm': distanceKm,
    };
  }

  Clinic copyWith({double? distanceKm}) {
    return Clinic(
      id: id,
      name: name,
      address: address,
      latitude: latitude,
      longitude: longitude,
      phone: phone,
      rating: rating,
      isOpen247: isOpen247,
      openHours: openHours,
      services: services,
      distanceKm: distanceKm ?? this.distanceKm,
    );
  }
}
