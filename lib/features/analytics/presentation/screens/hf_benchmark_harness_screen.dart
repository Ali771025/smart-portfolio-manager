import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:msgpack_dart/msgpack_dart.dart' as msgpack;

import '../../../../core/theme/custom_theme_extension.dart';
import '../widgets/financial_numeric_text.dart';
import '../widgets/hf_benchmark_multiline_chart.dart';

class HighFrequencyBenchmarkHarnessScreen extends StatefulWidget {
  const HighFrequencyBenchmarkHarnessScreen({
    required this.portfolioId,
    super.key,
  });

  final String portfolioId;

  @override
  State<HighFrequencyBenchmarkHarnessScreen> createState() =>
      _HighFrequencyBenchmarkHarnessScreenState();
}

class _HighFrequencyBenchmarkHarnessScreenState
    extends State<HighFrequencyBenchmarkHarnessScreen> {
  static const List<int> _pointOptions = <int>[5000, 10000, 20000, 40000];
  static const int _targetMaxRenderPoints = 500;
  static const double _targetFrameBudgetMs120 = 8.33;
  static const double _targetFrameBudgetMs60 = 16.67;

  Uint8List? _payload;
  int _selectedPointCount = 20000;
  bool _loadingPayload = false;
  _FrameStats _stats = const _FrameStats.empty();
  final List<double> _frameTimesMs = <double>[];

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_onFrameTimings);
    _regeneratePayload();
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onFrameTimings);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customTheme = CustomThemeExtension.resolve(context);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ابزار سنجش بنچمارک'),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
            _card(
              context,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'تنظیمات داده‌نمایشی',
                    style: customTheme.sectionTitleStyle,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _pointOptions.map((pointCount) {
                      return ChoiceChip(
                        label: Text('$pointCount نقطه'),
                        selected: _selectedPointCount == pointCount,
                        onSelected: (_) {
                          setState(() => _selectedPointCount = pointCount);
                          _regeneratePayload();
                        },
                      );
                    }).toList(growable: false),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'سقف رندر (LTTB): $_targetMaxRenderPoints نقطه برای هر خط',
                          style: customTheme.captionStyle.copyWith(
                            color: customTheme.chartAxis,
                            fontFeatures: kFinancialNumericFontFeatures,
                          ),
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _loadingPayload ? null : _regeneratePayload,
                        icon: _loadingPayload
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh_rounded),
                        label: const Text('تولید مجدد'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _card(
              context,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'پایش زمان فریم',
                    style: customTheme.sectionTitleStyle,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      _statTile(
                        label: 'میانگین FPS',
                        value: _stats.avgFps.toStringAsFixed(1),
                      ),
                      _statTile(
                        label: 'صدک ۹۵ (ms)',
                        value: _stats.p95Ms.toStringAsFixed(2),
                      ),
                      _statTile(
                        label: 'بدترین (ms)',
                        value: _stats.worstMs.toStringAsFixed(2),
                      ),
                      _statTile(
                        label: 'بیش از 8.33ms',
                        value: '${_stats.over120BudgetPct.toStringAsFixed(1)}%',
                      ),
                      _statTile(
                        label: 'بیش از 16.67ms',
                        value: '${_stats.over60BudgetPct.toStringAsFixed(1)}%',
                      ),
                      _statTile(
                        label: 'نمونه‌ها',
                        value: _stats.samples.toString(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'هدف برای 120fps: ${_targetFrameBudgetMs120.toStringAsFixed(2)} میلی‌ثانیه برای هر فریم',
                    style: customTheme.captionStyle.copyWith(
                      color: customTheme.chartAxis,
                      fontFeatures: kFinancialNumericFontFeatures,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _card(
              context,
              child: _payload == null
                  ? const SizedBox(
                      height: 260,
                      child: Center(child: CircularProgressIndicator.adaptive()),
                    )
                  : HighFrequencyBenchmarkChart(
                      portfolioId: widget.portfolioId,
                      messagePackPayload: _payload,
                      maxPointsPerSeries: _targetMaxRenderPoints,
                      showMiniMap: true,
                    ),
            ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(BuildContext context, {required Widget child}) {
    final customTheme = CustomThemeExtension.resolve(context);
    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: customTheme.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: customTheme.cardStroke),
          boxShadow: [
            BoxShadow(
              color: customTheme.cardShadow,
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: child,
        ),
      ),
    );
  }

  Widget _statTile({
    required String label,
    required String value,
  }) {
    return SizedBox(
      width: 110,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          const SizedBox(height: 2),
          FinancialNumericText(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }

  Future<void> _regeneratePayload() async {
    if (_loadingPayload) {
      return;
    }

    setState(() => _loadingPayload = true);
    try {
      final payload = await Isolate.run<Uint8List>(
        () => _buildSyntheticBenchmarkMsgPack(pointCount: _selectedPointCount),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _payload = payload;
      });
    } finally {
      if (mounted) {
        setState(() => _loadingPayload = false);
      }
    }
  }

  void _onFrameTimings(List<FrameTiming> timings) {
    if (!mounted || timings.isEmpty) {
      return;
    }

    for (final timing in timings) {
      _frameTimesMs.add(timing.totalSpan.inMicroseconds / 1000.0);
    }

    const maxSamples = 360;
    if (_frameTimesMs.length > maxSamples) {
      _frameTimesMs.removeRange(0, _frameTimesMs.length - maxSamples);
    }

    final nextStats = _FrameStats.fromSamples(
      _frameTimesMs,
      budget120Ms: _targetFrameBudgetMs120,
      budget60Ms: _targetFrameBudgetMs60,
    );
    if (nextStats != _stats) {
      setState(() => _stats = nextStats);
    }
  }
}

Uint8List _buildSyntheticBenchmarkMsgPack({
  required int pointCount,
}) {
  final rows = List<Map<String, Object?>>.generate(
    pointCount,
    (index) {
      final xEpochMs = DateTime.utc(2024, 1, 1)
              .add(Duration(minutes: index * 5))
              .millisecondsSinceEpoch
              .toDouble();
      final progress = index / math.max(1, pointCount - 1);
      final trend = (progress * 0.42) - 0.1;
      final cycleFast = math.sin(index / 27) * 0.0048;
      final cycleSlow = math.sin(index / 215) * 0.018;

      final portfolio = trend + cycleSlow + cycleFast;
      final totalIndex = (trend * 0.88) + (math.sin(index / 31) * 0.0065);
      final equalWeighted = (trend * 0.92) + (math.sin(index / 29) * 0.0083);
      final bankDeposit = (progress * 0.18) + (math.sin(index / 800) * 0.0008);
      final fixedIncome = (progress * 0.24) + (math.sin(index / 440) * 0.0018);

      return <String, Object?>{
        'x_epoch_ms': xEpochMs,
        'portfolio_twr_cumulative': portfolio,
        'total_index_cumulative': totalIndex,
        'equal_weighted_cumulative': equalWeighted,
        'bank_deposit_cumulative': bankDeposit,
        'fixed_income_cumulative': fixedIncome,
      };
    },
    growable: false,
  );

  final payload = <String, Object?>{
    'rows': rows,
  };
  final encoded = msgpack.serialize(payload);
  return Uint8List.fromList(encoded);
}

@immutable
class _FrameStats {
  const _FrameStats({
    required this.samples,
    required this.avgFps,
    required this.p95Ms,
    required this.worstMs,
    required this.over120BudgetPct,
    required this.over60BudgetPct,
  });

  const _FrameStats.empty()
      : samples = 0,
        avgFps = 0,
        p95Ms = 0,
        worstMs = 0,
        over120BudgetPct = 0,
        over60BudgetPct = 0;

  final int samples;
  final double avgFps;
  final double p95Ms;
  final double worstMs;
  final double over120BudgetPct;
  final double over60BudgetPct;

  factory _FrameStats.fromSamples(
    List<double> input, {
    required double budget120Ms,
    required double budget60Ms,
  }) {
    if (input.isEmpty) {
      return const _FrameStats.empty();
    }

    final sorted = List<double>.from(input)..sort();
    final avgFrameMs = input.reduce((a, b) => a + b) / input.length;
    final avgFps = avgFrameMs <= 0 ? 0.0 : 1000.0 / avgFrameMs;
    final p95Index = (sorted.length * 0.95).floor().clamp(0, sorted.length - 1);
    final p95 = sorted[p95Index];
    final worst = sorted.last;
    final over120 = input.where((ms) => ms > budget120Ms).length;
    final over60 = input.where((ms) => ms > budget60Ms).length;

    return _FrameStats(
      samples: input.length,
      avgFps: avgFps,
      p95Ms: p95,
      worstMs: worst,
      over120BudgetPct: (over120 / input.length) * 100,
      over60BudgetPct: (over60 / input.length) * 100,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is _FrameStats &&
        samples == other.samples &&
        avgFps == other.avgFps &&
        p95Ms == other.p95Ms &&
        worstMs == other.worstMs &&
        over120BudgetPct == other.over120BudgetPct &&
        over60BudgetPct == other.over60BudgetPct;
  }

  @override
  int get hashCode => Object.hash(
        samples,
        avgFps,
        p95Ms,
        worstMs,
        over120BudgetPct,
        over60BudgetPct,
      );
}
