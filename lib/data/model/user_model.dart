class User {
  final String name;
  final String avatarUrl;
  bool isSelected;

  User({
    required this.name,
    required this.avatarUrl,
    this.isSelected = false,
  });
}
