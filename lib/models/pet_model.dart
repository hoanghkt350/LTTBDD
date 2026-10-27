class Pet {
  final int? id;
  final String? serverId;
  final String name;
  final String species; // 'Dog', 'Cat', 'Bird', etc.
  final String breed;
  final String gender; // 'Đực', 'Cái'
  final String birthDate; // YYYY-MM-DD
  final double weight; // kg
  final String? microchipId;
  final String? avatarPath;
  final String? avatarCloudUrl;
  final int isSynced;

  Pet({
    this.id,
    this.serverId,
    required this.name,
    required this.species,
    required this.breed,
    required this.gender,
    required this.birthDate,
    required this.weight,
    this.microchipId,
    this.avatarPath,
    this.avatarCloudUrl,
    this.isSynced = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'server_id': serverId,
      'name': name,
      'species': species,
      'breed': breed,
      'gender': gender,
      'birth_date': birthDate,
      'weight': weight,
      'microchip_id': microchipId,
      'avatar_path': avatarPath,
      'avatar_cloud_url': avatarCloudUrl,
      'is_synced': isSynced,
    };
  }

  factory Pet.fromMap(Map<String, dynamic> map) {
    return Pet(
      id: map['id'] as int?,
      serverId: map['server_id'] as String?,
      name: map['name'] as String,
      species: map['species'] as String,
      breed: map['breed'] as String,
      gender: map['gender'] as String,
      birthDate: map['birth_date'] as String,
      weight: (map['weight'] as num).toDouble(),
      microchipId: map['microchip_id'] as String?,
      avatarPath: map['avatar_path'] as String?,
      avatarCloudUrl: map['avatar_cloud_url'] as String?,
      isSynced: (map['is_synced'] as int?) ?? 0,
    );
  }

  Pet copyWith({
    int? id,
    String? serverId,
    String? name,
    String? species,
    String? breed,
    String? gender,
    String? birthDate,
    double? weight,
    String? microchipId,
    String? avatarPath,
    String? avatarCloudUrl,
    int? isSynced,
  }) {
    return Pet(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      name: name ?? this.name,
      species: species ?? this.species,
      breed: breed ?? this.breed,
      gender: gender ?? this.gender,
      birthDate: birthDate ?? this.birthDate,
      weight: weight ?? this.weight,
      microchipId: microchipId ?? this.microchipId,
      avatarPath: avatarPath ?? this.avatarPath,
      avatarCloudUrl: avatarCloudUrl ?? this.avatarCloudUrl,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
