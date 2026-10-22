class RealtimePnlTick {
  const RealtimePnlTick({
    required this.totalNav,
    required this.totalPnl,
    required this.unrealizedPnl,
    this.receivedAt,
  });

  final double totalNav;
  final double totalPnl;
  final double unrealizedPnl;
  final DateTime? receivedAt;

  factory RealtimePnlTick.fromJson(Map<String, dynamic> json) {
    double readDouble(List<String> keys) {
      for (final key in keys) {
        final value = json[key];
        if (value is num) {
          return value.toDouble();
        }
        final parsed = double.tryParse(value?.toString() ?? '');
        if (parsed != null) {
          return parsed;
        }
      }
      return 0;
    }

    DateTime? readDateTime(List<String> keys) {
      for (final key in keys) {
        final value = json[key];
        if (value == null) {
          continue;
        }
        final parsed = DateTime.tryParse(value.toString());
        if (parsed != null) {
          return parsed.toUtc();
        }
      }
      return null;
    }

    return RealtimePnlTick(
      totalNav: readDouble(
        const [
          'total_nav',
          'total_market_value',
          'total_current_value',
          'nav',
        ],
      ),
      totalPnl: readDouble(
        const [
          'total_pnl',
          'pnl',
          'total_unrealized_pnl',
        ],
      ),
      unrealizedPnl: readDouble(
        const [
          'unrealized_pnl',
          'total_unrealized_pnl',
          'pnl',
        ],
      ),
      receivedAt: readDateTime(
        const ['received_at', 'as_of', 'timestamp'],
      ),
    );
  }
}
