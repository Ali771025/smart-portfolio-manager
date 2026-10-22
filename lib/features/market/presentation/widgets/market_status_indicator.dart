/// Minimal market status indicator widget.
///
/// Displays:
/// - Market open/closed status
/// - Data freshness indicator
/// - Last sync timestamp
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/market_controller.dart';
import '../../domain/models/market_models.dart';

/// Market status indicator widget.
class MarketStatusIndicator extends ConsumerWidget {
  const MarketStatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusState = ref.watch(marketStatusControllerProvider);

    if (statusState.isLoading && statusState.status == null) {
      return const SizedBox.shrink();
    }

    final status = statusState.status;
    if (status == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getStatusColor(status).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getStatusIcon(status),
            size: 14,
            color: _getStatusColor(status),
          ),
          const SizedBox(width: 4),
          Text(
            _getStatusText(status),
            style: TextStyle(
              fontSize: 11,
              color: _getStatusColor(status),
              fontWeight: FontWeight.w500,
            ),
          ),
          if (status.dataFreshnessSeconds != null) ...[
            const SizedBox(width: 8),
            Text(
              status.freshnessDescription,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
              ),
            ),
          ],
          if (status.lastSyncAt != null) ...[
            const SizedBox(width: 8),
            Text(
              _formatLastSync(status.lastSyncAt),
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getStatusColor(MarketStatus status) {
    if (!status.isTradingDay) return Colors.grey;
    if (!status.isMarketOpen) return Colors.orange;
    if (status.isStale) return Colors.orange;
    if (status.isHealthy) return Colors.green;
    return Colors.red;
  }

  IconData _getStatusIcon(MarketStatus status) {
    if (!status.isTradingDay) return Icons.event_busy;
    if (!status.isMarketOpen) return Icons.schedule;
    if (status.isStale) return Icons.warning_amber;
    if (status.isHealthy) return Icons.check_circle;
    return Icons.error;
  }

  String _getStatusText(MarketStatus status) {
    if (!status.isTradingDay) return 'روز غیرمعاملاتی';
    if (!status.isMarketOpen) return 'بازار بسته';
    if (status.isStale) return 'داده قدیمی';
    if (status.isHealthy) return 'بازار فعال';
    return 'خطا';
  }

  String _formatLastSync(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '';
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      return value;
    }
    return DateFormat('HH:mm', 'fa_IR').format(parsed.toLocal());
  }
}

/// Market data freshness indicator.
class MarketFreshnessIndicator extends ConsumerWidget {
  const MarketFreshnessIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveState = ref.watch(marketLiveControllerProvider);

    if (liveState.isLoading) {
      return const SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (liveState.error != null) {
      return Icon(
        Icons.error_outline,
        size: 14,
        color: Colors.red[400],
      );
    }

    if (liveState.lastUpdated == null) {
      return Icon(
        Icons.help_outline,
        size: 14,
        color: Colors.grey[400],
      );
    }

    final lastUpdated = liveState.lastUpdated;
    if (lastUpdated == null) {
      return Icon(
        Icons.help_outline,
        size: 14,
        color: Colors.grey[400],
      );
    }

    final age = DateTime.now().toUtc().difference(lastUpdated);
    final isStale = age.inMinutes > 5;

    return Icon(
      isStale ? Icons.refresh : Icons.fiber_smart_record,
      size: 14,
      color: isStale ? Colors.orange : Colors.green,
    );
  }
}
