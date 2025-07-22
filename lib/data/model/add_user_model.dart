class AddUser {
  final String id;
  final String name;
  final String avatarUrl;
  bool isSelected;

  AddUser({
    required this.id,
    required this.name,
    required this.avatarUrl,
    this.isSelected = false,
  });
}