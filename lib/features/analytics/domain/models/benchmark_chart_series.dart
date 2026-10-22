import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:fl_chart/fl_chart.dart';

class BenchmarkChartSeries {
  const BenchmarkChartSeries({
    required this.portfolio,
    required this.totalIndex,
    required this.equalWeighted,
    required this.bankDeposit,
    required this.fixedIncome,
  });

  final IList<FlSpot> portfolio;
  final IList<FlSpot> totalIndex;
  final IList<FlSpot> equalWeighted;
  final IList<FlSpot> bankDeposit;
  final IList<FlSpot> fixedIncome;

  static const BenchmarkChartSeries empty = BenchmarkChartSeries(
    portfolio: IListConst<FlSpot>([]),
    totalIndex: IListConst<FlSpot>([]),
    equalWeighted: IListConst<FlSpot>([]),
    bankDeposit: IListConst<FlSpot>([]),
    fixedIncome: IListConst<FlSpot>([]),
  );

  bool get isEmpty =>
      portfolio.isEmpty &&
      totalIndex.isEmpty &&
      equalWeighted.isEmpty &&
      bankDeposit.isEmpty &&
      fixedIncome.isEmpty;
}
