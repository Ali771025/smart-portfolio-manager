// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'portfolio_card_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PortfolioCardDto _$PortfolioCardDtoFromJson(Map<String, dynamic> json) =>
    _PortfolioCardDto(
      id: json['id'] as String,
      name: json['name'] as String,
      totalValue: (json['totalValue'] as num).toDouble(),
      roiPercent: (json['roiPercent'] as num).toDouble(),
      riskStdDeviation: (json['riskStdDeviation'] as num).toDouble(),
      sparklineValues: (json['sparklineValues'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          const <double>[],
      isDefault: json['isDefault'] as bool? ?? false,
    );

Map<String, dynamic> _$PortfolioCardDtoToJson(_PortfolioCardDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'totalValue': instance.totalValue,
      'roiPercent': instance.roiPercent,
      'riskStdDeviation': instance.riskStdDeviation,
      'sparklineValues': instance.sparklineValues,
      'isDefault': instance.isDefault,
    };
