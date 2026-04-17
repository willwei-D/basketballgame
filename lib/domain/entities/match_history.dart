class MatchResult {
  final int shotsFired;
  final int shotsScored;
  final int homeScore;
  final int guestScore;
  final String rank;
  final DateTime time;

  MatchResult({
    required this.shotsFired,
    required this.shotsScored,
    required this.homeScore,
    required this.guestScore,
    required this.rank,
    required this.time,
  });

  double get shootingPct =>
      shotsFired == 0 ? 0.0 : shotsScored / shotsFired * 100;
}

class MatchHistory {
  static final List<MatchResult> _records = [];

  static List<MatchResult> get records => List.unmodifiable(_records);

  static void add(MatchResult result) {
    _records.insert(0, result);
    if (_records.length > 5) _records.removeLast();
  }
}
