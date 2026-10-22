import 'package:freezed_annotation/freezed_annotation.dart';

part 'portfolio_card_dto.freezed.dart';
part 'portfolio_card_dto.g.dart';

@freezed
abstract class PortfolioCardDto with _$PortfolioCardDto {
  const PortfolioCardDto._();

  const factory PortfolioCardDto({
    required String id,
    required String name,
    required double totalValue,
    required double roiPercent,
    required double riskStdDeviation,
    @Default(<double>[]) List<double> sparklineValues,
    @Default(false) bool isDefault,
  }) = _PortfolioCardDto;

  factory PortfolioCardDto.fromJson(Map<String, dynamic> json) =>
      _$PortfolioCardDtoFromJson(json);
}

@freezed
abstract class PortfolioOptionDto with _$PortfolioOptionDto {
  const factory PortfolioOptionDto({
    required String id,
    required String title,
  }) = _PortfolioOptionDto;
}
