class Achievement {
  final String id;
  final String title;
  final String description;
  final double progress; // 0..1
  final String icon; // simple material icon name

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.progress,
    required this.icon,
  });

  Achievement copyWith({
    String? id,
    String? title,
    String? description,
    double? progress,
    String? icon,
  }) {
    return Achievement(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      progress: progress ?? this.progress,
      icon: icon ?? this.icon,
    );
  }
}
