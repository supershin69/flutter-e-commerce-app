enum UserRole {
  user,
  admin,
  moderator;

  static UserRole fromAny(dynamic value) {
    final v = value?.toString().trim().toLowerCase();
    if (v == 'admin') return UserRole.admin;
    if (v == 'moderator') return UserRole.moderator;
    return UserRole.user;
  }

  String get value {
    switch (this) {
      case UserRole.user:
        return 'user';
      case UserRole.admin:
        return 'admin';
      case UserRole.moderator:
        return 'moderator';
    }
  }
}

class UserModel {
  final String id;
  final String email;
  final String name;
  final String? avatarUrl;
  final String phoneNumber;
  final String shippingAddress;
  final UserRole role;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.avatarUrl,
    required this.phoneNumber,
    required this.shippingAddress,
    this.role = UserRole.user,
  });

  bool isAdmin() => role == UserRole.admin;
  bool isModerator() => role == UserRole.moderator;
  bool isUser() => role == UserRole.user;
  bool isStaff() => isAdmin() || isModerator();

  /// Convert UserModel to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'avatar_url': avatarUrl,
      'phone_number': phoneNumber,
      'shipping_address': shippingAddress,
      'role': role.value,
    };
  }

  /// Create UserModel from JSON map
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String? ?? json['user_id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      name: json['name'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String? ?? json['avatar'] as String?,
      phoneNumber: json['phone_number'] as String? ?? json['phone'] as String? ?? '',
      shippingAddress: json['shipping_address'] as String? ?? json['address'] as String? ?? '',
      role: UserRole.fromAny(json['role']),
    );
  }

  /// Create UserModel from Supabase profiles table data
  /// This is a convenience method that handles the common case of fetching from profiles table
  factory UserModel.fromProfilesMap(Map<String, dynamic> map, {String? email, String? userId}) {
    return UserModel(
      id: userId ?? map['user_id'] as String? ?? '',
      email: email ?? '',
      name: map['name'] as String? ?? '',
      avatarUrl: map['avatar'] as String? ?? map['avatar_url'] as String?,
      phoneNumber: map['phone'] as String? ?? map['phone_number'] as String? ?? '',
      shippingAddress: map['address'] as String? ?? map['shipping_address'] as String? ?? '',
      role: UserRole.fromAny(map['role']),
    );
  }

  /// Create a copy of UserModel with updated fields
  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? avatarUrl,
    String? phoneNumber,
    String? shippingAddress,
    UserRole? role,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      shippingAddress: shippingAddress ?? this.shippingAddress,
      role: role ?? this.role,
    );
  }

  @override
  String toString() {
    return 'UserModel(id: $id, email: $email, name: $name, role: ${role.value}, phoneNumber: $phoneNumber, shippingAddress: $shippingAddress)';
  }
}
