// Update your ViewMember model: lib/data/model/view_user_model.dart
class ViewMember {
  final String id;
  final String name;
  final String avatarUrl;
  final String? email;
  final String? joinedAt;
  final bool? isOnline;
  final String? role; // admin, member, etc.

  ViewMember({
    required this.id,
    required this.name,
    required this.avatarUrl,
    this.email,
    this.joinedAt,
    this.isOnline,
    this.role,
  });

  // Factory constructor to create ViewMember from API response
  factory ViewMember.fromJson(Map<String, dynamic> json) {
    return ViewMember(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown Member',
      avatarUrl: json['avatar']?.toString() ?? '',
      email: json['email']?.toString(),
      joinedAt: json['joined_at']?.toString(),
      isOnline: json['is_online'] as bool?,
      role: json['role']?.toString(),
    );
  }

  // Convert ViewMember to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'avatar': avatarUrl,
      'email': email,
      'joined_at': joinedAt,
      'is_online': isOnline,
      'role': role,
    };
  }
}