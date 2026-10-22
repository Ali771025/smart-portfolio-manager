import 'dart:math' as math;

import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';

class LttbInputPoint {
  const LttbInputPoint({
    required this.x,
    required this.y,
  });

  final int x;
  final Decimal y;
}

class LttbOutputPoint {
  const LttbOutputPoint({
    required this.x,
    required this.y,
  });

  final int x;
  final double y;
}

class _LttbRequest {
  const _LttbRequest({
    required this.x,
    required this.y,
    required this.threshold,
  });

  final List<int> x;
  final List<String> y;
  final int threshold;
}

class _LttbResponse {
  const _LttbResponse({
    required this.x,
    required this.y,
  });

  final List<int> x;
  final List<double> y;
}

Future<List<LttbOutputPoint>> downsampleLttbInIsolate({
  required List<LttbInputPoint> points,
  required int threshold,
}) async {
  if (points.isEmpty) {
    return const <LttbOutputPoint>[];
  }

  if (points.length <= threshold || threshold < 3) {
    return points
        .map((point) => LttbOutputPoint(x: point.x, y: _toChartDouble(point.y)))
        .toList(growable: false);
  }

  final request = _LttbRequest(
    x: points.map((point) => point.x).toList(growable: false),
    y: points.map((point) => point.y.toString()).toList(growable: false),
    threshold: threshold,
  );

  final response = await compute<_LttbRequest, _LttbResponse>(_lttbWorker, request);
  return List<LttbOutputPoint>.generate(
    response.x.length,
    (index) => LttbOutputPoint(x: response.x[index], y: response.y[index]),
    growable: false,
  );
}

_LttbResponse _lttbWorker(_LttbRequest request) {
  final x = request.x;
  final y = request.y.map((value) => Decimal.parse(value)).toList(growable: false);

  if (x.length <= request.threshold || request.threshold < 3) {
    return _LttbResponse(
      x: x,
      y: y.map(_toChartDouble).toList(growable: false),
    );
  }

  final sampledX = <int>[x.first];
  final sampledY = <Decimal>[y.first];

  final bucketSize = (x.length - 2) / (request.threshold - 2);
  var a = 0;

  for (var i = 0; i < request.threshold - 2; i++) {
    final rangeStart = (((i + 1) * bucketSize).floor() + 1).clamp(1, x.length - 1);
    final rangeEnd = (((i + 2) * bucketSize).floor() + 1).clamp(1, x.length);

    Decimal avgX = Decimal.zero;
    Decimal avgY = Decimal.zero;
    final avgRangeLength = math.max(1, rangeEnd - rangeStart);

    for (var j = rangeStart; j < rangeEnd; j++) {
      avgX += Decimal.fromInt(x[j]);
      avgY += y[j];
    }

    avgX = (avgX / Decimal.fromInt(avgRangeLength)).toDecimal();
    avgY = (avgY / Decimal.fromInt(avgRangeLength)).toDecimal();

    final pointRangeStart = ((i * bucketSize).floor() + 1).clamp(1, x.length - 1);
    final pointRangeEnd = (((i + 1) * bucketSize).floor() + 1).clamp(1, x.length - 1);

    var maxArea = Decimal.fromInt(-1);
    var maxAreaIndex = pointRangeStart;

    for (var j = pointRangeStart; j <= pointRangeEnd; j++) {
      final area = _decimalAbs(
        (Decimal.fromInt(x[a]) - avgX) * (y[j] - y[a]) -
            (Decimal.fromInt(x[a]) - Decimal.fromInt(x[j])) * (avgY - y[a]),
      );

      if (area > maxArea) {
        maxArea = area;
        maxAreaIndex = j;
      }
    }

    sampledX.add(x[maxAreaIndex]);
    sampledY.add(y[maxAreaIndex]);
    a = maxAreaIndex;
  }

  sampledX.add(x.last);
  sampledY.add(y.last);

  return _LttbResponse(
    x: sampledX,
    y: sampledY.map(_toChartDouble).toList(growable: false),
  );
}

Decimal _decimalAbs(Decimal value) {
  return value >= Decimal.zero ? value : -value;
}

double _toChartDouble(Decimal value) {
  return double.tryParse(value.toString()) ?? 0;
}
