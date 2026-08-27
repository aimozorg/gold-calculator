class GoldCalcException implements Exception {
  final String code;
  final String message;
  const GoldCalcException(this.code, this.message);
  @override
  String toString() => '$code: $message';
}
