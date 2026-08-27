/// Exact rational number backed by BigInt. No floating-point arithmetic is used
/// for financial calculations. Convert UI strings to Rational, not doubles.
class Rational implements Comparable<Rational> {
  final BigInt numerator;
  final BigInt denominator;

  static final Rational zero = Rational._(BigInt.zero, BigInt.one);
  static final Rational one = Rational._(BigInt.one, BigInt.one);

  const Rational._(this.numerator, this.denominator);

  factory Rational(BigInt numerator, [BigInt? denominator]) {
    final d = denominator ?? BigInt.one;
    if (d == BigInt.zero) {
      throw ArgumentError('Denominator cannot be zero.');
    }
    final sign = d.isNegative ? BigInt.from(-1) : BigInt.one;
    final n = numerator * sign;
    final positiveD = d.abs();
    final g = _gcd(n.abs(), positiveD);
    return Rational._(n ~/ g, positiveD ~/ g);
  }

  factory Rational.fromInt(int value) => Rational(BigInt.from(value));

  factory Rational.parse(String value) {
    final normalized = value.trim().replaceAll(',', '').replaceAll('_', '');
    if (normalized.isEmpty) throw FormatException('Empty number.');
    final match = RegExp(r'^([+-]?)(\d+)(?:\.(\d+))?$').firstMatch(normalized);
    if (match == null) throw FormatException('Invalid decimal: $value');
    final sign = match.group(1) == '-' ? BigInt.from(-1) : BigInt.one;
    final whole = BigInt.parse(match.group(2)!);
    final fractional = match.group(3) ?? '';
    if (fractional.isEmpty) return Rational(sign * whole);
    final scale = BigInt.from(10).pow(fractional.length);
    final frac = BigInt.parse(fractional);
    return Rational(sign * (whole * scale + frac), scale);
  }

  Rational operator +(Rational other) => Rational(
        numerator * other.denominator + other.numerator * denominator,
        denominator * other.denominator,
      );

  Rational operator -(Rational other) => Rational(
        numerator * other.denominator - other.numerator * denominator,
        denominator * other.denominator,
      );

  Rational operator *(Rational other) => Rational(
        numerator * other.numerator,
        denominator * other.denominator,
      );

  Rational operator /(Rational other) {
    if (other.numerator == BigInt.zero)
      throw ArgumentError('Division by zero.');
    return Rational(
        numerator * other.denominator, denominator * other.numerator);
  }

  Rational operator -() => Rational(-numerator, denominator);

  bool get isNegative => numerator.isNegative;
  bool get isZero => numerator == BigInt.zero;
  Rational abs() => isNegative ? -this : this;
  Rational max(Rational other) => compareTo(other) >= 0 ? this : other;
  Rational min(Rational other) => compareTo(other) <= 0 ? this : other;

  BigInt roundHalfUp() {
    final sign = numerator.isNegative ? BigInt.from(-1) : BigInt.one;
    final a = numerator.abs();
    final q = a ~/ denominator;
    final r = a % denominator;
    final rounded = r * BigInt.from(2) >= denominator ? q + BigInt.one : q;
    return sign * rounded;
  }

  BigInt floor() {
    if (!isNegative) return numerator ~/ denominator;
    final q = numerator ~/ denominator;
    return numerator % denominator == BigInt.zero ? q : q - BigInt.one;
  }

  BigInt ceil() {
    if (isNegative) return numerator ~/ denominator;
    final q = numerator ~/ denominator;
    return numerator % denominator == BigInt.zero ? q : q + BigInt.one;
  }

  BigInt round({RoundingMode mode = RoundingMode.halfUp}) {
    switch (mode) {
      case RoundingMode.halfUp:
        return roundHalfUp();
      case RoundingMode.floor:
        return floor();
      case RoundingMode.ceiling:
        return ceil();
      case RoundingMode.none:
        return roundHalfUp();
    }
  }

  String toDecimalString({int scale = 6, bool trimTrailingZeros = true}) {
    final sign = isNegative ? '-' : '';
    final n = numerator.abs();
    final whole = n ~/ denominator;
    var remainder = n % denominator;
    if (scale <= 0 || remainder == BigInt.zero) return '$sign$whole';
    final digits = StringBuffer();
    for (var i = 0; i < scale; i++) {
      remainder *= BigInt.from(10);
      final digit = remainder ~/ denominator;
      remainder %= denominator;
      digits.write(digit.toString());
      if (remainder == BigInt.zero && trimTrailingZeros) break;
    }
    return '$sign$whole.${digits.toString()}';
  }

  double toDouble() => numerator.toDouble() / denominator.toDouble();

  @override
  int compareTo(Rational other) =>
      (numerator * other.denominator).compareTo(other.numerator * denominator);

  bool operator <(Rational other) => compareTo(other) < 0;
  bool operator >(Rational other) => compareTo(other) > 0;
  bool operator <=(Rational other) => compareTo(other) <= 0;
  bool operator >=(Rational other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) =>
      other is Rational &&
      numerator == other.numerator &&
      denominator == other.denominator;

  @override
  int get hashCode => Object.hash(numerator, denominator);

  @override
  String toString() => toDecimalString();

  static BigInt _gcd(BigInt a, BigInt b) {
    var x = a;
    var y = b;
    while (y != BigInt.zero) {
      final t = x % y;
      x = y;
      y = t;
    }
    return x == BigInt.zero ? BigInt.one : x;
  }
}

enum RoundingMode { halfUp, floor, ceiling, none }

Rational percent(String value) => Rational.parse(value) / Rational.fromInt(100);
