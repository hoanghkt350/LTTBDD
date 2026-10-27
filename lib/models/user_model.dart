class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final String? phoneNumber;
  final String? address;
  final String? avatarUrl;
  final String membershipLevel; // 'STANDARD', 'SILVER', 'GOLD', 'VIP'

  AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    this.phoneNumber,
    this.address,
    this.avatarUrl,
    this.membershipLevel = 'STANDARD',
  });

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'phoneNumber': phoneNumber,
      'address': address,
      'avatarUrl': avatarUrl,
      'membershipLevel': membershipLevel,
    };
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      uid: json['uid'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String,
      phoneNumber: json['phoneNumber'] as String?,
      address: json['address'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      membershipLevel: (json['membershipLevel'] as String?) ?? 'STANDARD',
    );
  }

  AppUser copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? phoneNumber,
    String? address,
    String? avatarUrl,
    String? membershipLevel,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      address: address ?? this.address,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      membershipLevel: membershipLevel ?? this.membershipLevel,
    );
  }
}
