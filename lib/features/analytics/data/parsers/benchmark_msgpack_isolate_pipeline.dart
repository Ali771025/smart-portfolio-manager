import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:fpdart/fpdart.dart';
import 'package:msgpack_dart/msgpack_dart.dart' as msgpack;

import '../../../../core/network/app_failure.dart';
import '../../domain/models/benchmark_chart_series.dart';

const int _decodeOffloadThresholdBytes = 12 * 1024;
const int _defaultMaxPointsPerSeries = 500;

const String _portfolioField = 'portfolio_twr_cumulative';
const String _totalIndexField = 'total_index_cumulative';
const String _equalWeightedField = 'equal_weighted_cumulative';
const String _bankDepositField = 'bank_deposit_cumulative';
const String _fixedIncomeField = 'fixed_income_cumulative';

const Map<String, String> _seriesFieldMap = <String, String>{
  'portfolio': _portfolioField,
  'totalIndex': _totalIndexField,
  'equalWeighted': _equalWeightedField,
  'bankDeposit': _bankDepositField,
  'fixedIncome': _fixedIncomeField,
};

typedef _IsolateRequest = ({
  TransferableTypedData payload,
  int maxPointsPerSeries,
});

typedef _PackedSpots = Map<String, List<List<double>>>;

class _LttbPoint {
  const _LttbPoint({
    required this.x,
    required this.y,
  });

  final double x;
  final double y;
}

Future<Either<AppFailure, BenchmarkChartSeries>> parseBenchmarkMsgPackToSeries(
  Uint8List payload, {
  int maxPointsPerSeries = _defaultMaxPointsPerSeries,
}) async {
  if (payload.isEmpty) {
    return const Left(
      AppFailure(message: 'داده باینری بنچمارک خالی است.'),
    );
  }
  if (maxPointsPerSeries < 3) {
    return const Left(
      AppFailure(message: 'حداقل آستانه کاهش نمونه باید ۳ نقطه باشد.'),
    );
  }

  try {
    final packedSpots = await _decodeAndDownsample(payload, maxPointsPerSeries);
    return Right(
      BenchmarkChartSeries(
        portfolio: _toImmutableSpots(packedSpots['portfolio']),
        totalIndex: _toImmutableSpots(packedSpots['totalIndex']),
        equalWeighted: _toImmutableSpots(packedSpots['equalWeighted']),
        bankDeposit: _toImmutableSpots(packedSpots['bankDeposit']),
        fixedIncome: _toImmutableSpots(packedSpots['fixedIncome']),
      ),
    );
  } on FormatException catch (error) {
    return Left(
      AppFailure(message: 'فرمت داده بنچمارک نامعتبر است: ${error.message}'),
    );
  } catch (_) {
    return const Left(
      AppFailure(message: 'پردازش و کاهش نمونه داده بنچمارک ناموفق بود.'),
    );
  }
}

Future<_PackedSpots> _decodeAndDownsample(
  Uint8List payload,
  int maxPointsPerSeries,
) async {
  if (kIsWeb || payload.length < _decodeOffloadThresholdBytes) {
    return _decodeAndDownsampleSync(payload, maxPointsPerSeries);
  }

  final request = (
    payload: TransferableTypedData.fromList(<TypedData>[payload]),
    maxPointsPerSeries: maxPointsPerSeries,
  );
  return Isolate.run<_PackedSpots>(
    () => _decodeAndDownsampleInIsolate(request),
  );
}

_PackedSpots _decodeAndDownsampleInIsolate(_IsolateRequest request) {
  final bytes = request.payload.materialize().asUint8List();
  return _decodeAndDownsampleSync(bytes, request.maxPointsPerSeries);
}

_PackedSpots _decodeAndDownsampleSync(
  Uint8List payload,
  int maxPointsPerSeries,
) {
  final String? maybeJson = _tryDecodeUtf8(payload);
  if (maybeJson != null) {
    return _decodeJsonAndDownsampleSync(maybeJson, maxPointsPerSeries);
  }

  final raw = msgpack.deserialize(payload);
  return _downsampleRoot(raw, maxPointsPerSeries);
}

_PackedSpots _decodeJsonAndDownsampleSync(
  String jsonPayload,
  int maxPointsPerSeries,
) {
  final raw = jsonDecode(jsonPayload);
  return _downsampleRoot(raw, maxPointsPerSeries);
}

_PackedSpots _downsampleRoot(
  Object? raw,
  int maxPointsPerSeries,
) {
  final root = _asMap(raw, context: 'ریشه داده');
  final rawPoints = root['points'] ?? root['rows'];
  if (rawPoints is! List) {
    throw const FormatException('فهرست سطح بالای "points" در داده یافت نشد.');
  }

  final mutableSeries = <String, List<_LttbPoint>>{
    for (final key in _seriesFieldMap.keys) key: <_LttbPoint>[],
  };

  var fallbackX = 0.0;
  for (final dynamic row in rawPoints) {
    final rowMap = _asMap(row, context: 'ردیف نقاط');
    final xValue = _extractXAxis(rowMap, fallbackX);

    for (final entry in _seriesFieldMap.entries) {
      final rawY = rowMap[entry.value];
      final yValue = _toFiniteDouble(rawY);
      if (yValue == null) {
        continue;
      }
      mutableSeries[entry.key]!.add(_LttbPoint(x: xValue, y: yValue));
    }

    fallbackX += 1.0;
  }

  return <String, List<List<double>>>{
    for (final entry in mutableSeries.entries)
      entry.key: _largestTriangleThreeBuckets(
        entry.value,
        maxPointsPerSeries,
      ).map((point) => <double>[point.x, point.y]).toList(growable: false),
  };
}

String? _tryDecodeUtf8(Uint8List payload) {
  try {
    final maybeText = utf8.decode(payload, allowMalformed: false).trimLeft();
    if (maybeText.startsWith('{') || maybeText.startsWith('[')) {
      return maybeText;
    }
    return null;
  } catch (_) {
    return null;
  }
}

Map<String, dynamic> _asMap(
  Object? value, {
  required String context,
}) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map<String, dynamic>(
      (dynamic key, dynamic item) => MapEntry(key.toString(), item),
    );
  }
  throw FormatException('ساختار map برای $context مورد انتظار بود.');
}

double _extractXAxis(Map<String, dynamic> row, double fallbackX) {
  final rawDate = row['as_of'] ?? row['date'];
  final rawEpoch = row['x_epoch_ms'];

  final parsedEpoch = _toFiniteDouble(rawEpoch);
  if (parsedEpoch != null) {
    return parsedEpoch;
  }

  if (rawDate != null) {
    final parsedDate = DateTime.tryParse(rawDate.toString());
    if (parsedDate != null) {
      return parsedDate.toUtc().millisecondsSinceEpoch.toDouble();
    }
  }

  return fallbackX;
}

double? _toFiniteDouble(Object? rawValue) {
  if (rawValue is num) {
    final candidate = rawValue.toDouble();
    if (candidate.isFinite) {
      return candidate;
    }
    return null;
  }
  if (rawValue == null) {
    return null;
  }

  final candidate = double.tryParse(rawValue.toString());
  if (candidate == null || !candidate.isFinite) {
    return null;
  }
  return candidate;
}

IList<FlSpot> _toImmutableSpots(List<List<double>>? packed) {
  if (packed == null || packed.isEmpty) {
    return const IListConst<FlSpot>([]);
  }

  final spots = List<FlSpot>.generate(
    packed.length,
    (index) {
      final pair = packed[index];
      final x = pair.isNotEmpty ? pair[0] : 0.0;
      final y = pair.length > 1 ? pair[1] : 0.0;
      return FlSpot(x, y);
    },
    growable: false,
  );
  return IList<FlSpot>(spots);
}

List<_LttbPoint> _largestTriangleThreeBuckets(
  List<_LttbPoint> points,
  int threshold,
) {
  final total = points.length;
  if (total <= threshold || threshold <= 0) {
    return List<_LttbPoint>.from(points, growable: false);
  }
  if (threshold < 3) {
    throw const FormatException('برای LTTB حداقل آستانه ۳ لازم است.');
  }

  final sampled = List<_LttbPoint>.filled(threshold, points.first, growable: false);
  sampled[0] = points.first;
  sampled[threshold - 1] = points.last;

  final bucketSize = (total - 2) / (threshold - 2);
  var anchorIndex = 0;

  for (var i = 0; i < threshold - 2; i++) {
    final avgStart = ((i + 1) * bucketSize).floor() + 1;
    final avgEnd = (((i + 2) * bucketSize).floor() + 1).clamp(1, total);

    var avgX = 0.0;
    var avgY = 0.0;
    final avgLength = (avgEnd - avgStart).clamp(1, total);
    for (var idx = avgStart; idx < avgEnd; idx++) {
      avgX += points[idx].x;
      avgY += points[idx].y;
    }
    avgX /= avgLength;
    avgY /= avgLength;

    final rangeOffs = (i * bucketSize).floor() + 1;
    final rangeTo = (((i + 1) * bucketSize).floor() + 1).clamp(1, total - 1);

    var maxArea = -1.0;
    var nextAnchorIndex = rangeOffs;

    for (var idx = rangeOffs; idx < rangeTo; idx++) {
      final area = _triangleArea(
        points[anchorIndex].x,
        points[anchorIndex].y,
        points[idx].x,
        points[idx].y,
        avgX,
        avgY,
      );
      if (area > maxArea) {
        maxArea = area;
        nextAnchorIndex = idx;
      }
    }

    sampled[i + 1] = points[nextAnchorIndex];
    anchorIndex = nextAnchorIndex;
  }

  return sampled;
}

double _triangleArea(
  double ax,
  double ay,
  double bx,
  double by,
  double cx,
  double cy,
) {
  return ((ax - cx) * (by - ay) - (ax - bx) * (cy - ay)).abs() * 0.5;
}
