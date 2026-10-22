enum ManualTransactionType {
  buy('BUY', 'خرید'),
  sell('SELL', 'فروش'),
  capitalIncreaseBonus('CAPITAL_INCREASE_BONUS', 'سهام جایزه'),
  stockSplit('STOCK_SPLIT', 'تجزیه سهام'),
  preEmptiveRights('PRE_EMPTIVE_RIGHTS', 'حق‌تقدم'),
  cashDividend('CASH_DIVIDEND', 'سود نقدی'),
  assetTransfer('ASSET_TRANSFER', 'انتقال دارایی');

  const ManualTransactionType(this.apiValue, this.displayLabel);

  final String apiValue;
  final String displayLabel;

  static ManualTransactionType fromApiValue(String value) {
    return values.firstWhere(
      (entry) => entry.apiValue == value,
      orElse: () => ManualTransactionType.buy,
    );
  }
}
