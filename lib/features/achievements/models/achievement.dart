/// Lightweight model for an achievement with progress (0..1).
/// `icon` is a simple Material icon name (e.g., "verified", "eco", "emoji_events").
/// Call `achieved` to check if it's completed.
class Achievement {
  final String id;
  final String title;
  final String description;

  /// Progress between 0.0 and 1.0 (values outside will be clamped).
  final double progress;

  /// Material icon name
  final String icon;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required double progress,
    required this.icon,
  }) : progress = progress.clamp(0.0, 1.0);

  /// True when progress is complete.
  bool get achieved => progress >= 1.0;

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
      progress: (progress ?? this.progress).clamp(0.0, 1.0),
      icon: icon ?? this.icon,
    );
  }
}
