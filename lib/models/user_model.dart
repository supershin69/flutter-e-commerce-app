class UserModel {
  final String id;
  final String email;
  final String name;
  final String? avatarUrl;
  final String phoneNumber;
  final String shippingAddress;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.avatarUrl,
    required this.phoneNumber,
    required this.shippingAddress,
  });

  /// Convert UserModel to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'avatar_url': avatarUrl,
      'phone_number': phoneNumber,
      'shipping_address': shippingAddress,
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
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      shippingAddress: shippingAddress ?? this.shippingAddress,
    );
  }

  @override
  String toString() {
    return 'UserModel(id: $id, email: $email, name: $name, phoneNumber: $phoneNumber, shippingAddress: $shippingAddress)';
  }
}
