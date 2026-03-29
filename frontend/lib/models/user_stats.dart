class UserStats {
  final int totalCheckIns;
  final int progressCheckIns; // check-ins counting toward sponsor progress (may differ after a reset)
  final int daysActive;
  final int daysClean;
  final DateTime? lastRelapseAt;

  // Pause / demotion state (sponsors and leaders only)
  final int pauseTier;          // 0=none, 1=30-day, 2=60-day, 3=suspended
  final int pauseDaysRemaining; // 0 when not in a time-based pause
  final DateTime? pauseEndsAt;
  final bool isDemoted;         // role has been stepped down
  final String originalRole;    // role before demotion; "" if not demoted

  const UserStats({
    required this.totalCheckIns,
    required this.progressCheckIns,
    required this.daysActive,
    required this.daysClean,
    this.lastRelapseAt,
    this.pauseTier = 0,
    this.pauseDaysRemaining = 0,
    this.pauseEndsAt,
    this.isDemoted = false,
    this.originalRole = '',
  });

  factory UserStats.fromJson(Map<String, dynamic> json) {
    return UserStats(
      totalCheckIns: json['total_check_ins'] as int? ?? 0,
      progressCheckIns: json['progress_check_ins'] as int? ?? json['total_check_ins'] as int? ?? 0,
      daysActive: json['days_active'] as int? ?? 0,
      daysClean: json['days_clean'] as int? ?? 0,
      lastRelapseAt: json['last_relapse_at'] != null
          ? DateTime.parse(json['last_relapse_at'] as String).toLocal()
          : null,
      pauseTier: json['pause_tier'] as int? ?? 0,
      pauseDaysRemaining: json['pause_days_remaining'] as int? ?? 0,
      pauseEndsAt: json['pause_ends_at'] != null
          ? DateTime.parse(json['pause_ends_at'] as String).toLocal()
          : null,
      isDemoted: json['is_demoted'] as bool? ?? false,
      originalRole: json['original_role'] as String? ?? '',
    );
  }

  /// True when the progress bar should show a paused state.
  bool get isPaused => pauseTier > 0 && (pauseDaysRemaining > 0 || pauseTier == 3);
}
