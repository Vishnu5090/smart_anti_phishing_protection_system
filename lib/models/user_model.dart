class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final DateTime createdAt;
  final int totalScans;
  final int safeSites;
  final int dangerousSites;

  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.createdAt,
    this.totalScans = 0,
    this.safeSites = 0,
    this.dangerousSites = 0,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      displayName: map['displayName']?.toString() ?? '',
      createdAt: map['createdAt'] != null 
          ? DateTime.parse(map['createdAt'].toString())
          : DateTime.now(),
      totalScans: int.tryParse(map['totalScans']?.toString() ?? '0') ?? 0,
      safeSites: int.tryParse(map['safeSites']?.toString() ?? '0') ?? 0,
      dangerousSites: int.tryParse(map['dangerousSites']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'createdAt': createdAt.toIso8601String(),
      'totalScans': totalScans,
      'safeSites': safeSites,
      'dangerousSites': dangerousSites,
    };
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    DateTime? createdAt,
    int? totalScans,
    int? safeSites,
    int? dangerousSites,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      createdAt: createdAt ?? this.createdAt,
      totalScans: totalScans ?? this.totalScans,
      safeSites: safeSites ?? this.safeSites,
      dangerousSites: dangerousSites ?? this.dangerousSites,
    );
  }
}