import 'dart:async';
import 'dart:math' as math;

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/debug/import_analytics_refresh_trace.dart';
import '../../../../core/theme/custom_theme_extension.dart';
import '../../../../core/theme/institutional_chart_theme_extension.dart';
import '../../domain/models/analytics_models.dart';
import '../../domain/models/benchmark_chart_series.dart';
import '../../domain/models/benchmark_dashboard_state.dart';
import '../providers/benchmark_dashboard_controller.dart';
import 'financial_numeric_text.dart';

class HighFrequencyBenchmarkChart extends ConsumerStatefulWidget {
  const HighFrequencyBenchmarkChart({
    required this.portfolioId,
    this.messagePackPayload,
    this.maxPointsPerSeries = 500,
    this.showMiniMap = true,
    this.timeframe,
    super.key,
  });

  final String portfolioId;
  final Uint8List? messagePackPayload;
  final int maxPointsPerSeries;
  final bool showMiniMap;
  final AnalyticsTimeframe? timeframe;

  @override
  ConsumerState<HighFrequencyBenchmarkChart> createState() =>
      _HighFrequencyBenchmarkChartState();
}

class _HighFrequencyBenchmarkChartState
    extends ConsumerState<HighFrequencyBenchmarkChart> {
  static const double _mainChartHeight = 320;
  static const double _miniMapHeight = 84;

  final LayerLink _overlayLayerLink = LayerLink();
  final GlobalKey _chartKey = GlobalKey(debugLabel: 'hf_benchmark_chart');
  final ValueNotifier<_TooltipState?> _tooltipState =
      ValueNotifier<_TooltipState?>(null);

  OverlayEntry? _tooltipOverlayEntry;
  int? _lastPayloadFingerprint;
  Size _chartSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _ingestPayloadIfNeeded();
  }

  @override
  void didUpdateWidget(covariant HighFrequencyBenchmarkChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    final portfolioChanged = oldWidget.portfolioId != widget.portfolioId;
    if (portfolioChanged) {
      _lastPayloadFingerprint = null;
      _hideTooltip();
      if (kDebugMode) {
        debugPrint(
          '[HighFrequencyBenchmarkChart] portfolio changed '
          '${oldWidget.portfolioId} -> ${widget.portfolioId}; reset local chart state',
        );
      }
    }
    if (portfolioChanged ||
        !identical(oldWidget.messagePackPayload, widget.messagePackPayload) ||
        oldWidget.maxPointsPerSeries != widget.maxPointsPerSeries) {
      _ingestPayloadIfNeeded();
    }
  }

  @override
  void dispose() {
    _removeTooltipOverlay();
    _tooltipState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(
      benchmarkDashboardControllerProvider(widget.portfolioId),
    );
    final visibleSeries = ref.watch(
      benchmarkVisibleSeriesProvider(widget.portfolioId),
    );
    final dashboard = dashboardAsync.value ?? BenchmarkDashboardState.initial;
    final chartTheme = context.institutionalChartTheme;
    final customTheme = CustomThemeExtension.resolve(context);

    final bounds = _resolveBounds(visibleSeries);
    final pointCount = visibleSeries.values.fold<int>(
      0,
      (total, item) => total + item.length,
    );
    final firstX = _minXFromVisible(visibleSeries);
    final lastX = _maxXFromVisible(visibleSeries);
    final widgetFingerprint = ImportAnalyticsRefreshTrace.fingerprintFromObjects(
      <Object?>[
        pointCount,
        firstX,
        lastX,
        for (final entry in visibleSeries.entries) entry.key.name,
        for (final entry in visibleSeries.entries) entry.value.length,
      ],
    );
    final traceId =
        ImportAnalyticsRefreshTrace.traceIdForPortfolio(widget.portfolioId);
    ImportAnalyticsRefreshTrace.logWidgetBuild(
      traceId: traceId,
      widgetName: 'HighFrequencyBenchmarkChart',
      portfolioId: widget.portfolioId,
      timeframe: widget.timeframe?.name,
      pointCount: pointCount,
      firstDate: _toUtc(firstX),
      lastDate: _toUtc(lastX),
      dataFingerprint: widgetFingerprint,
    );

    if (dashboardAsync.isLoading && dashboard.series.isEmpty) {
      return const SizedBox(
        height: _mainChartHeight,
        child: Center(child: CircularProgressIndicator.adaptive()),
      );
    }

    final lineBars = _buildLineBarsData(
      visibleSeries: visibleSeries,
      chartTheme: chartTheme,
    );

    if (visibleSeries.isEmpty || bounds == null || lineBars.isEmpty) {
      return SizedBox(
        height: _mainChartHeight,
        child: Center(
          child: Text(
            'در حال حاضر هیچ خط بنچمارکی نمایش داده نمی‌شود.',
            style: customTheme.bodyStyle.copyWith(color: customTheme.chartAxis),
          ),
        ),
      );
    }

    final controller = ref.read(
      benchmarkDashboardControllerProvider(widget.portfolioId).notifier,
    );
    final domain = _resolveDomainBounds(dashboard);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LineVisibilityChips(
          selected: dashboard.visibleLines,
          available: _availableLines(dashboard.series),
          chartTheme: chartTheme,
          onToggle: controller.toggleLine,
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: _mainChartHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              _chartSize = Size(constraints.maxWidth, constraints.maxHeight);
              return CompositedTransformTarget(
                link: _overlayLayerLink,
                child: MouseRegion(
                  onExit: (_) => _hideTooltip(),
                  child: Listener(
                    onPointerDown: (event) =>
                        _handlePointerEvent(event.position, bounds, visibleSeries),
                    onPointerHover: (event) =>
                        _handlePointerEvent(event.position, bounds, visibleSeries),
                    onPointerMove: (event) =>
                        _handlePointerEvent(event.position, bounds, visibleSeries),
                    onPointerUp: (_) => _hideTooltip(),
                    onPointerCancel: (_) => _hideTooltip(),
                    child: RepaintBoundary(
                      key: _chartKey,
                      child: LineChart(
                        LineChartData(
                          minX: bounds.minX,
                          maxX: bounds.maxX,
                          minY: bounds.minY,
                          maxY: bounds.maxY,
                          borderData: FlBorderData(show: false),
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: bounds.yInterval,
                            getDrawingHorizontalLine: (_) => FlLine(
                              color: customTheme.chartGrid.withValues(alpha: 0.45),
                              strokeWidth: 1,
                            ),
                          ),
                          titlesData: FlTitlesData(
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 52,
                                interval: bounds.yInterval,
                                getTitlesWidget: (value, _) {
                                  return FinancialNumericText(
                                    _compactCurrency(value),
                                    style: customTheme.captionStyle.copyWith(
                                      color: customTheme.chartAxis,
                                    ),
                                  );
                                },
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 28,
                                interval: bounds.xInterval,
                                getTitlesWidget: (value, _) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      _formatXAxis(value),
                                      style: customTheme.captionStyle.copyWith(
                                        color: customTheme.chartAxis,
                                        fontFeatures: kFinancialNumericFontFeatures,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          lineTouchData: const LineTouchData(enabled: false),
                          lineBarsData: lineBars,
                        ),
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (widget.showMiniMap && domain != null) ...[
          const SizedBox(height: 12),
          _MiniMapBrush(
            height: _miniMapHeight,
            bounds: domain,
            series: dashboard.series,
            brushWindow: dashboard.brushWindow,
            chartTheme: chartTheme,
            onWindowChanged: (window) => controller.setBrushWindow(
              minX: window.minX,
              maxX: window.maxX,
            ),
            onWindowCleared: controller.clearBrushWindow,
          ),
        ],
      ],
    );
  }

  void _ingestPayloadIfNeeded() {
    final payload = widget.messagePackPayload;
    if (payload == null || payload.isEmpty) {
      if (kDebugMode) {
        debugPrint(
          '[HighFrequencyBenchmarkChart] skip ingest: empty payload '
          'portfolioId=${widget.portfolioId}',
        );
      }
      return;
    }

    final fingerprint = _payloadFingerprint(payload);
    final fingerprintHex = fingerprint.toRadixString(16).padLeft(8, '0');
    final traceId =
        ImportAnalyticsRefreshTrace.traceIdForPortfolio(widget.portfolioId);
    if (_lastPayloadFingerprint == fingerprint) {
      if (kDebugMode) {
        debugPrint(
          '[HighFrequencyBenchmarkChart] skip ingest: unchanged payload '
          'portfolioId=${widget.portfolioId}',
        );
      }
      ImportAnalyticsRefreshTrace.logWidgetBuild(
        traceId: traceId,
        widgetName: 'HighFrequencyBenchmarkChart.ingest',
        portfolioId: widget.portfolioId,
        timeframe: widget.timeframe?.name,
        pointCount: payload.length,
        dataFingerprint: fingerprintHex,
        payloadFingerprintChanged: false,
      );
      return;
    }
    final payloadChanged = _lastPayloadFingerprint != null;
    _lastPayloadFingerprint = fingerprint;
    if (kDebugMode) {
      debugPrint(
        '[HighFrequencyBenchmarkChart] ingest payload '
        'portfolioId=${widget.portfolioId} bytes=${payload.length} '
        'maxPoints=${widget.maxPointsPerSeries}',
      );
    }
    ImportAnalyticsRefreshTrace.logWidgetBuild(
      traceId: traceId,
      widgetName: 'HighFrequencyBenchmarkChart.ingest',
      portfolioId: widget.portfolioId,
      timeframe: widget.timeframe?.name,
      pointCount: payload.length,
      dataFingerprint: fingerprintHex,
      payloadFingerprintChanged: payloadChanged,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final controller = ref.read(
        benchmarkDashboardControllerProvider(widget.portfolioId).notifier,
      );
      unawaited(
        controller.ingestMessagePack(
          payload,
          maxPointsPerSeries: widget.maxPointsPerSeries,
        ),
      );
    });
  }

  int _payloadFingerprint(Uint8List payload) {
    const int fnvOffset = 0x811C9DC5;
    const int fnvPrime = 0x01000193;

    var hash = fnvOffset;
    for (final byte in payload) {
      hash ^= byte;
      hash = (hash * fnvPrime) & 0xFFFFFFFF;
    }
    return Object.hash(hash, payload.length, widget.maxPointsPerSeries);
  }

  void _handlePointerEvent(
    Offset globalPosition,
    _ChartBounds bounds,
    IMap<BenchmarkLineKind, IList<FlSpot>> visibleSeries,
  ) {
    final renderObject = _chartKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return;
    }

    final local = renderObject.globalToLocal(globalPosition);
    final chartWidth = renderObject.size.width;
    final chartHeight = renderObject.size.height;

    if (local.dx < 0 ||
        local.dx > chartWidth ||
        local.dy < 0 ||
        local.dy > chartHeight) {
      _hideTooltip();
      return;
    }

    final anchorSeries = _resolveAnchorSeries(visibleSeries);
    if (anchorSeries == null || anchorSeries.isEmpty) {
      _hideTooltip();
      return;
    }

    final xDomainValue = bounds.minX +
        ((local.dx / chartWidth).clamp(0.0, 1.0) * (bounds.maxX - bounds.minX));
    final anchorSpot = _nearestSpot(anchorSeries, xDomainValue);
    if (anchorSpot == null) {
      _hideTooltip();
      return;
    }

    final valuesByLine = <BenchmarkLineKind, double>{};
    for (final entry in visibleSeries.entries) {
      final nearest = _nearestSpot(entry.value, anchorSpot.x);
      if (nearest != null) {
        valuesByLine[entry.key] = nearest.y;
      }
    }

    final crosshairX = bounds.toPixelX(anchorSpot.x, chartWidth);
    final crosshairY = bounds.toPixelY(anchorSpot.y, chartHeight);

    _tooltipState.value = _TooltipState(
      pixelX: crosshairX,
      pixelY: crosshairY,
      xValue: anchorSpot.x,
      valuesByLine: valuesByLine,
    );
    _showTooltipOverlay();
  }

  double? _minXFromVisible(IMap<BenchmarkLineKind, IList<FlSpot>> visible) {
    double? minX;
    for (final series in visible.values) {
      if (series.isEmpty) {
        continue;
      }
      final x = series.first.x;
      if (minX == null || x < minX) {
        minX = x;
      }
    }
    return minX;
  }

  double? _maxXFromVisible(IMap<BenchmarkLineKind, IList<FlSpot>> visible) {
    double? maxX;
    for (final series in visible.values) {
      if (series.isEmpty) {
        continue;
      }
      final x = series.last.x;
      if (maxX == null || x > maxX) {
        maxX = x;
      }
    }
    return maxX;
  }

  DateTime? _toUtc(double? epochMs) {
    if (epochMs == null || !epochMs.isFinite) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(epochMs.round(), isUtc: true);
  }

  IList<FlSpot>? _resolveAnchorSeries(
    IMap<BenchmarkLineKind, IList<FlSpot>> visibleSeries,
  ) {
    if (visibleSeries.containsKey(BenchmarkLineKind.portfolio)) {
      return visibleSeries[BenchmarkLineKind.portfolio];
    }
    return visibleSeries.values.firstOrNull;
  }

  FlSpot? _nearestSpot(IList<FlSpot> spots, double xValue) {
    if (spots.isEmpty) {
      return null;
    }
    if (spots.length == 1) {
      return spots.first;
    }

    var low = 0;
    var high = spots.length - 1;
    while (low <= high) {
      final mid = low + ((high - low) >> 1);
      final midX = spots[mid].x;
      if (midX == xValue) {
        return spots[mid];
      }
      if (midX < xValue) {
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }

    final leftIndex = high.clamp(0, spots.length - 1);
    final rightIndex = low.clamp(0, spots.length - 1);
    final left = spots[leftIndex];
    final right = spots[rightIndex];
    return (xValue - left.x).abs() <= (right.x - xValue).abs() ? left : right;
  }

  void _showTooltipOverlay() {
    if (_tooltipOverlayEntry != null) {
      _tooltipOverlayEntry!.markNeedsBuild();
      return;
    }

    final overlay = Overlay.of(context, rootOverlay: true);
    _tooltipOverlayEntry = OverlayEntry(
      builder: (context) {
        final customTheme = CustomThemeExtension.resolve(context);
        final chartTheme = context.institutionalChartTheme;

        return IgnorePointer(
          child: CompositedTransformFollower(
            link: _overlayLayerLink,
            showWhenUnlinked: false,
            child: SizedBox(
              width: _chartSize.width,
              height: _chartSize.height,
              child: ValueListenableBuilder<_TooltipState?>(
                valueListenable: _tooltipState,
                builder: (context, tooltip, _) {
                  if (tooltip == null) {
                    return const SizedBox.shrink();
                  }

                  final tooltipLeft = (tooltip.pixelX + 12).clamp(
                    0.0,
                    math.max(0.0, _chartSize.width - 220),
                  ).toDouble();
                  final tooltipTop = (tooltip.pixelY - 92).clamp(
                    6.0,
                    math.max(6.0, _chartSize.height - 120),
                  ).toDouble();

                  return Stack(
                    children: [
                      Positioned.fill(
                        child: RepaintBoundary(
                          child: CustomPaint(
                            painter: _CrosshairPainter(
                              x: tooltip.pixelX,
                              y: tooltip.pixelY,
                              color: chartTheme.crosshairColor,
                              strokeWidth: chartTheme.crosshairStrokeWidth,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: tooltipLeft,
                        top: tooltipTop,
                        width: 220,
                        child: RepaintBoundary(
                          child: _BenchmarkTooltipCard(
                            tooltip: tooltip,
                            customTheme: customTheme,
                            chartTheme: chartTheme,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
    overlay.insert(_tooltipOverlayEntry!);
  }

  void _hideTooltip() {
    _tooltipState.value = null;
    _removeTooltipOverlay();
  }

  void _removeTooltipOverlay() {
    _tooltipOverlayEntry?.remove();
    _tooltipOverlayEntry = null;
  }
}

class _MiniMapBrush extends StatefulWidget {
  const _MiniMapBrush({
    required this.height,
    required this.bounds,
    required this.series,
    required this.brushWindow,
    required this.chartTheme,
    required this.onWindowChanged,
    required this.onWindowCleared,
  });

  final double height;
  final _ChartBounds bounds;
  final BenchmarkChartSeries series;
  final BenchmarkBrushWindow? brushWindow;
  final InstitutionalChartThemeExtension chartTheme;
  final ValueChanged<BenchmarkBrushWindow> onWindowChanged;
  final VoidCallback onWindowCleared;

  @override
  State<_MiniMapBrush> createState() => _MiniMapBrushState();
}

class _MiniMapBrushState extends State<_MiniMapBrush> {
  _BrushDragMode _dragMode = _BrushDragMode.none;
  BenchmarkBrushWindow? _dragStartWindow;
  double _dragAnchorX = 0;

  @override
  Widget build(BuildContext context) {
    final customTheme = CustomThemeExtension.resolve(context);
    final currentWindow = widget.brushWindow ??
        BenchmarkBrushWindow(minX: widget.bounds.minX, maxX: widget.bounds.maxX);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'بازه‌نمای نمودار',
              style: customTheme.captionStyle.copyWith(
                color: customTheme.chartAxis,
              ),
            ),
            const Spacer(),
            if (widget.brushWindow != null)
              TextButton(
                onPressed: widget.onWindowCleared,
                child: const Text('بازنشانی بزرگ‌نمایی'),
              ),
          ],
        ),
        SizedBox(
          height: widget.height,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  RepaintBoundary(
                    child: LineChart(
                      LineChartData(
                        minX: widget.bounds.minX,
                        maxX: widget.bounds.maxX,
                        minY: widget.bounds.minY,
                        maxY: widget.bounds.maxY,
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(
                          show: true,
                          border: Border.all(
                            color: widget.chartTheme.miniMapTrack,
                          ),
                        ),
                        titlesData: const FlTitlesData(show: false),
                        lineTouchData: const LineTouchData(enabled: false),
                        lineBarsData: [
                          _miniMapLine(
                            widget.series.portfolio,
                            widget.chartTheme.portfolioLine,
                            widget.chartTheme.miniMapStrokeWidth,
                          ),
                          _miniMapLine(
                            widget.series.totalIndex,
                            widget.chartTheme.totalIndexLine.withValues(alpha: 0.75),
                            widget.chartTheme.miniMapStrokeWidth,
                          ),
                          _miniMapLine(
                            widget.series.equalWeighted,
                            widget.chartTheme.equalWeightedLine.withValues(alpha: 0.7),
                            widget.chartTheme.miniMapStrokeWidth,
                          ),
                          _miniMapLine(
                            widget.series.bankDeposit,
                            widget.chartTheme.bankDepositLine.withValues(alpha: 0.68),
                            widget.chartTheme.miniMapStrokeWidth,
                          ),
                          _miniMapLine(
                            widget.series.fixedIncome,
                            widget.chartTheme.fixedIncomeLine.withValues(alpha: 0.68),
                            widget.chartTheme.miniMapStrokeWidth,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: (details) => _onPanStart(
                        localDx: details.localPosition.dx,
                        width: constraints.maxWidth,
                        window: currentWindow,
                        hasBrush: widget.brushWindow != null,
                      ),
                      onPanUpdate: (details) => _onPanUpdate(
                        localDx: details.localPosition.dx,
                        width: constraints.maxWidth,
                      ),
                      onPanEnd: (_) => _resetDrag(),
                      onPanCancel: _resetDrag,
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: _BrushOverlayPainter(
                            bounds: widget.bounds,
                            window: currentWindow,
                            fillColor: widget.chartTheme.brushFill,
                            borderColor: widget.chartTheme.brushBorder,
                            strokeWidth: widget.chartTheme.brushStrokeWidth,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  void _onPanStart({
    required double localDx,
    required double width,
    required BenchmarkBrushWindow window,
    required bool hasBrush,
  }) {
    final normalized = (localDx / width).clamp(0.0, 1.0);
    final xValue = widget.bounds.minX +
        (normalized * (widget.bounds.maxX - widget.bounds.minX));

    final leftHandlePx = widget.bounds.toPixelX(window.minX, width);
    final rightHandlePx = widget.bounds.toPixelX(window.maxX, width);
    const handleThreshold = 14.0;

    _dragStartWindow = window;
    _dragAnchorX = xValue;

    if (!hasBrush) {
      _dragMode = _BrushDragMode.newWindow;
      final seedWindow = BenchmarkBrushWindow(minX: xValue, maxX: xValue);
      widget.onWindowChanged(seedWindow);
      _dragStartWindow = seedWindow;
      return;
    }

    if ((localDx - leftHandlePx).abs() <= handleThreshold) {
      _dragMode = _BrushDragMode.resizeLeft;
      return;
    }
    if ((localDx - rightHandlePx).abs() <= handleThreshold) {
      _dragMode = _BrushDragMode.resizeRight;
      return;
    }
    if (xValue >= window.minX && xValue <= window.maxX) {
      _dragMode = _BrushDragMode.move;
      return;
    }

    _dragMode = _BrushDragMode.newWindow;
    final seedWindow = BenchmarkBrushWindow(minX: xValue, maxX: xValue);
    widget.onWindowChanged(seedWindow);
    _dragStartWindow = seedWindow;
  }

  void _onPanUpdate({
    required double localDx,
    required double width,
  }) {
    final start = _dragStartWindow;
    if (start == null || _dragMode == _BrushDragMode.none) {
      return;
    }

    final normalized = (localDx / width).clamp(0.0, 1.0);
    final xValue = widget.bounds.minX +
        (normalized * (widget.bounds.maxX - widget.bounds.minX));
    final minWindowWidth = (widget.bounds.maxX - widget.bounds.minX) * 0.015;

    switch (_dragMode) {
      case _BrushDragMode.resizeLeft:
        final nextMin = math.min(xValue, start.maxX - minWindowWidth)
            .clamp(widget.bounds.minX, widget.bounds.maxX);
        widget.onWindowChanged(
          BenchmarkBrushWindow(minX: nextMin, maxX: start.maxX),
        );
        break;
      case _BrushDragMode.resizeRight:
        final nextMax = math.max(xValue, start.minX + minWindowWidth)
            .clamp(widget.bounds.minX, widget.bounds.maxX);
        widget.onWindowChanged(
          BenchmarkBrushWindow(minX: start.minX, maxX: nextMax),
        );
        break;
      case _BrushDragMode.move:
        final delta = xValue - _dragAnchorX;
        final widthValue = start.maxX - start.minX;
        var nextMin = start.minX + delta;
        var nextMax = start.maxX + delta;
        if (nextMin < widget.bounds.minX) {
          nextMin = widget.bounds.minX;
          nextMax = nextMin + widthValue;
        }
        if (nextMax > widget.bounds.maxX) {
          nextMax = widget.bounds.maxX;
          nextMin = nextMax - widthValue;
        }
        widget.onWindowChanged(
          BenchmarkBrushWindow(minX: nextMin, maxX: nextMax),
        );
        break;
      case _BrushDragMode.newWindow:
        widget.onWindowChanged(
          BenchmarkBrushWindow(
            minX: math.min(_dragAnchorX, xValue),
            maxX: math.max(_dragAnchorX, xValue),
          ),
        );
        break;
      case _BrushDragMode.none:
        break;
    }
  }

  void _resetDrag() {
    _dragMode = _BrushDragMode.none;
    _dragStartWindow = null;
    _dragAnchorX = 0;
  }
}

class _LineVisibilityChips extends StatelessWidget {
  const _LineVisibilityChips({
    required this.selected,
    required this.available,
    required this.chartTheme,
    required this.onToggle,
  });

  final ISet<BenchmarkLineKind> selected;
  final ISet<BenchmarkLineKind> available;
  final InstitutionalChartThemeExtension chartTheme;
  final ValueChanged<BenchmarkLineKind> onToggle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: BenchmarkLineKind.values.where(available.contains).map((line) {
          final active = selected.contains(line);
          return Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: FilterChip(
              selected: active,
              showCheckmark: false,
              onSelected: (_) => onToggle(line),
              avatar: CircleAvatar(
                radius: 5,
                backgroundColor: _lineColor(line, chartTheme),
              ),
              label: Text(
                _lineLabel(line),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontFeatures: kFinancialNumericFontFeatures,
                    ),
              ),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }
}

ISet<BenchmarkLineKind> _availableLines(BenchmarkChartSeries series) {
  return ISet<BenchmarkLineKind>([
    if (series.portfolio.isNotEmpty) BenchmarkLineKind.portfolio,
    if (series.totalIndex.isNotEmpty) BenchmarkLineKind.totalIndex,
    if (series.equalWeighted.isNotEmpty) BenchmarkLineKind.equalWeighted,
    if (series.bankDeposit.isNotEmpty) BenchmarkLineKind.bankDeposit,
    if (series.fixedIncome.isNotEmpty) BenchmarkLineKind.fixedIncome,
  ]);
}

class _BenchmarkTooltipCard extends StatelessWidget {
  const _BenchmarkTooltipCard({
    required this.tooltip,
    required this.customTheme,
    required this.chartTheme,
  });

  final _TooltipState tooltip;
  final CustomThemeExtension customTheme;
  final InstitutionalChartThemeExtension chartTheme;

  @override
  Widget build(BuildContext context) {
    final rows = tooltip.valuesByLine.entries.toList(growable: false);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: chartTheme.tooltipBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: chartTheme.tooltipBorder),
        boxShadow: [
          BoxShadow(
            blurRadius: 12,
            offset: const Offset(0, 4),
            color: customTheme.cardShadow,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _formatXAxis(tooltip.xValue),
              style: customTheme.captionStyle.copyWith(
                color: customTheme.chartAxis,
                fontFeatures: kFinancialNumericFontFeatures,
              ),
            ),
            const SizedBox(height: 6),
            ...rows.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _lineColor(entry.key, chartTheme),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _lineLabel(entry.key),
                        style: customTheme.captionStyle.copyWith(
                          color: customTheme.chartAxis,
                        ),
                      ),
                    ),
                    FinancialNumericText(
                      _compactPercent(entry.value),
                      style: customTheme.bodyStyle.copyWith(
                        color: customTheme.primarySemantic,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _CrosshairPainter extends CustomPainter {
  const _CrosshairPainter({
    required this.x,
    required this.y,
    required this.color,
    required this.strokeWidth,
  });

  final double x;
  final double y;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    canvas.drawCircle(
      Offset(x, y),
      3.6,
      Paint()..color = color.withValues(alpha: 0.95),
    );
  }

  @override
  bool shouldRepaint(covariant _CrosshairPainter oldDelegate) {
    return oldDelegate.x != x ||
        oldDelegate.y != y ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

class _BrushOverlayPainter extends CustomPainter {
  const _BrushOverlayPainter({
    required this.bounds,
    required this.window,
    required this.fillColor,
    required this.borderColor,
    required this.strokeWidth,
  });

  final _ChartBounds bounds;
  final BenchmarkBrushWindow window;
  final Color fillColor;
  final Color borderColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final left = bounds.toPixelX(window.minX, size.width);
    final right = bounds.toPixelX(window.maxX, size.width);
    final rect = Rect.fromLTRB(left, 0, right, size.height);
    final fill = Paint()..color = fillColor;
    final stroke = Paint()
      ..color = borderColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    canvas.drawRect(rect, fill);
    canvas.drawRect(rect, stroke);

    final handlePaint = Paint()..color = borderColor;
    final handleHeight = size.height * 0.72;
    final top = (size.height - handleHeight) / 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left - 2, top, 4, handleHeight),
        const Radius.circular(2),
      ),
      handlePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(right - 2, top, 4, handleHeight),
        const Radius.circular(2),
      ),
      handlePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _BrushOverlayPainter oldDelegate) {
    return oldDelegate.window != window ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

class _TooltipState {
  const _TooltipState({
    required this.pixelX,
    required this.pixelY,
    required this.xValue,
    required this.valuesByLine,
  });

  final double pixelX;
  final double pixelY;
  final double xValue;
  final Map<BenchmarkLineKind, double> valuesByLine;
}

class _ChartBounds {
  const _ChartBounds({
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
    required this.xInterval,
    required this.yInterval,
  });

  final double minX;
  final double maxX;
  final double minY;
  final double maxY;
  final double xInterval;
  final double yInterval;

  double toPixelX(double x, double width) {
    final xSpan = math.max(1e-9, maxX - minX);
    return ((x - minX) / xSpan).clamp(0.0, 1.0) * width;
  }

  double toPixelY(double y, double height) {
    final ySpan = math.max(1e-9, maxY - minY);
    return height - (((y - minY) / ySpan).clamp(0.0, 1.0) * height);
  }
}

enum _BrushDragMode {
  none,
  move,
  resizeLeft,
  resizeRight,
  newWindow,
}

_ChartBounds? _resolveBounds(IMap<BenchmarkLineKind, IList<FlSpot>> visibleSeries) {
  final xValues = <double>[];
  final yValues = <double>[];
  for (final points in visibleSeries.values) {
    for (final point in points) {
      if (point.x.isFinite && point.y.isFinite) {
        xValues.add(point.x);
        yValues.add(point.y);
      }
    }
  }
  if (xValues.isEmpty || yValues.isEmpty) {
    return null;
  }

  final minX = xValues.reduce(math.min);
  final maxX = xValues.reduce(math.max);
  final minYRaw = yValues.reduce(math.min);
  final maxYRaw = yValues.reduce(math.max);
  final yPadding = math.max((maxYRaw - minYRaw) * 0.12, 0.0008);

  return _ChartBounds(
    minX: minX,
    maxX: math.max(minX + 1, maxX),
    minY: minYRaw - yPadding,
    maxY: maxYRaw + yPadding,
    xInterval: math.max((maxX - minX) / 4, 1),
    yInterval: math.max((maxYRaw - minYRaw) / 4, 0.001),
  );
}

_ChartBounds? _resolveDomainBounds(BenchmarkDashboardState dashboard) {
  final allLines = <IList<FlSpot>>[
    dashboard.series.portfolio,
    dashboard.series.totalIndex,
    dashboard.series.equalWeighted,
    dashboard.series.bankDeposit,
    dashboard.series.fixedIncome,
  ];

  final xValues = <double>[];
  final yValues = <double>[];
  for (final line in allLines) {
    for (final point in line) {
      if (point.x.isFinite && point.y.isFinite) {
        xValues.add(point.x);
        yValues.add(point.y);
      }
    }
  }
  if (xValues.isEmpty || yValues.isEmpty) {
    return null;
  }
  final minX = xValues.reduce(math.min);
  final maxX = xValues.reduce(math.max);
  final minYRaw = yValues.reduce(math.min);
  final maxYRaw = yValues.reduce(math.max);
  final yPadding = math.max((maxYRaw - minYRaw).abs() * 0.12, 0.0008);

  return _ChartBounds(
    minX: minX,
    maxX: math.max(minX + 1, maxX),
    minY: minYRaw - yPadding,
    maxY: maxYRaw + yPadding,
    xInterval: math.max((maxX - minX) / 4, 1),
    yInterval: math.max((maxYRaw - minYRaw).abs() / 4, 0.001),
  );
}

List<LineChartBarData> _buildLineBarsData({
  required IMap<BenchmarkLineKind, IList<FlSpot>> visibleSeries,
  required InstitutionalChartThemeExtension chartTheme,
}) {
  final rows = <LineChartBarData>[];
  for (final entry in visibleSeries.entries) {
    final spots = entry.value
        .where((point) => point.x.isFinite && point.y.isFinite)
        .toList(growable: false);
    if (spots.isEmpty) {
      continue;
    }
    rows.add(
      LineChartBarData(
        spots: _renderableBenchmarkSpots(spots),
        isCurved: true,
        curveSmoothness: 0.18,
        isStrokeCapRound: true,
        color: _lineColor(entry.key, chartTheme),
        barWidth: entry.key == BenchmarkLineKind.portfolio
            ? chartTheme.mainLineStrokeWidth
            : chartTheme.benchmarkLineStrokeWidth,
        dotData: const FlDotData(show: false),
      ),
    );
  }
  return rows;
}

List<FlSpot> _renderableBenchmarkSpots(List<FlSpot> spots) {
  if (spots.length != 1) {
    return spots;
  }
  final point = spots.first;
  return <FlSpot>[
    point,
    FlSpot(point.x + 1, point.y),
  ];
}

LineChartBarData _miniMapLine(
  IList<FlSpot> spots,
  Color color,
  double strokeWidth,
) {
  final cleanSpots = spots
      .where((point) => point.x.isFinite && point.y.isFinite)
      .toList(growable: false);
  return LineChartBarData(
    spots: cleanSpots.length >= 2
        ? cleanSpots
        : const <FlSpot>[FlSpot(0, 0), FlSpot(1, 0)],
    isCurved: true,
    curveSmoothness: 0.15,
    color: color,
    barWidth: strokeWidth,
    dotData: const FlDotData(show: false),
  );
}

String _lineLabel(BenchmarkLineKind line) {
  return switch (line) {
    BenchmarkLineKind.portfolio => 'پرتفوی',
    BenchmarkLineKind.totalIndex => 'شاخص کل',
    BenchmarkLineKind.equalWeighted => 'هم‌وزن',
    BenchmarkLineKind.bankDeposit => 'سپرده بانکی',
    BenchmarkLineKind.fixedIncome => 'درآمد ثابت',
  };
}

Color _lineColor(
  BenchmarkLineKind line,
  InstitutionalChartThemeExtension chartTheme,
) {
  return switch (line) {
    BenchmarkLineKind.portfolio => chartTheme.portfolioLine,
    BenchmarkLineKind.totalIndex => chartTheme.totalIndexLine,
    BenchmarkLineKind.equalWeighted => chartTheme.equalWeightedLine,
    BenchmarkLineKind.bankDeposit => chartTheme.bankDepositLine,
    BenchmarkLineKind.fixedIncome => chartTheme.fixedIncomeLine,
  };
}

String _formatXAxis(double x) {
  if (x > 1000000000) {
    final dt = DateTime.fromMillisecondsSinceEpoch(x.round(), isUtc: true);
    return DateFormat('yyyy/MM/dd').format(dt);
  }
  return NumberFormat.compact().format(x);
}

String _compactCurrency(double value) {
  return NumberFormat.compactCurrency(symbol: '', decimalDigits: 2).format(value);
}

String _compactPercent(double value) {
  return '${(value * 100).toStringAsFixed(2)}%';
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
