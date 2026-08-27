import 'package:flutter_test/flutter_test.dart';
import 'package:gold_calculator_engine/gold_calculator_engine.dart';

Rational r(String value) => Rational.parse(value);

void main() {
  final engine = GoldCalculationEngine(
    rules: EngineRules.mvp1405(),
  );

  final now = DateTime(2026, 8, 28);

  RateInput rate18(String value) => RateInput(
        value: r(value),
        basis: PriceBasis.per18k,
        timestamp: now,
      );

  SaleInput sale({
    String weight = '1',
    String purity = '750',
    String rate = '10000000',
    String labor = '0.10',
    String profit = '0.07',
  }) {
    return SaleInput(
      grossWeight: r(weight),
      purity: r(purity),
      rate: rate18(rate),
      labor: LaborInput(
        mode: LaborMode.percent,
        rate: r(labor),
      ),
      profit: ProfitInput(
        mode: ProfitMode.percentOfGoldPlusLabor,
        rate: r(profit),
      ),
      taxRules: TaxRuleSet.iran1405(),
      timestamp: now,
    );
  }

  group('Rational', () {
    test('exact arithmetic does not use floating point', () {
      final value = r('0.1') + r('0.2');
      expect(value.toDecimalString(), '0.3');
    });

    test('normalizes fractions', () {
      final value = Rational.fromInt(2) / Rational.fromInt(4);
      expect(value.toDecimalString(), '0.5');
    });
  });

  group('Sale', () {
    test('calculates a basic sale', () {
      final result = engine.calculateSale(
        sale(
          weight: '1',
          purity: '750',
          rate: '10000000',
          labor: '0',
          profit: '0',
        ),
      );

      expect(result.metalValue.toDecimalString(), '10000000');
      expect(result.laborAmount.toDecimalString(), '0');
      expect(result.profitAmount.toDecimalString(), '0');
      expect(result.finalTotal.toDecimalString(), '10000000');
    });

    test('includes labor and profit', () {
      final result = engine.calculateSale(
        sale(
          weight: '1',
          purity: '750',
          rate: '10000000',
          labor: '0.10',
          profit: '0.05',
        ),
      );

      expect(result.metalValue.toDecimalString(), '10000000');
      expect(result.laborAmount.toDecimalString(), '1000000');
      expect(result.profitAmount.toDecimalString(), '550000');
      expect(result.finalTotal > result.metalValue, isTrue);
    });

    test('stone weight is removed from gross weight', () {
      final input = sale(weight: '2');

      final result = engine.calculateSale(
        SaleInput(
          grossWeight: r('2'),
          purity: r('750'),
          stoneWeight: r('0.25'),
          rate: input.rate,
          labor: input.labor,
          profit: input.profit,
          taxRules: input.taxRules,
          timestamp: now,
        ),
      );

      expect(result.metalValue.toDecimalString(), '17500000');
    });

    test('rejects zero weight', () {
      expect(
        () => engine.calculateSale(sale(weight: '0')),
        throwsA(isA<GoldCalcException>()),
      );
    });

    test('rejects stone heavier than item', () {
      final input = sale(weight: '1');

      expect(
        () => engine.calculateSale(
          SaleInput(
            grossWeight: r('1'),
            purity: r('750'),
            stoneWeight: r('1.1'),
            rate: input.rate,
            labor: input.labor,
            profit: input.profit,
            taxRules: input.taxRules,
            timestamp: now,
          ),
        ),
        throwsA(isA<GoldCalcException>()),
      );
    });
  });

  group('Buy', () {
    test('calculates customer purchase offer', () {
      final result = engine.calculateBuy(
        BuyInput(
          weight: r('1'),
          purity: r('750'),
          rate: rate18('10000000'),
          buyFactor: r('0.95'),
          timestamp: now,
        ),
      );

      expect(result.baseValue.toDecimalString(), '10000000');
      expect(result.discountedValue.toDecimalString(), '9500000');
      expect(result.offerPrice.toDecimalString(), '9500000');
    });

    test('applies percentage deduction', () {
      final result = engine.calculateBuy(
        BuyInput(
          weight: r('1'),
          purity: r('750'),
          rate: rate18('10000000'),
          buyFactor: r('1'),
          deductionMode: DeductionMode.percent,
          deduction: r('0.02'),
          timestamp: now,
        ),
      );

      expect(result.deductionAmount.toDecimalString(), '200000');
      expect(result.offerPrice.toDecimalString(), '9800000');
    });
  });

  group('Melted gold', () {
    test('calculates pure weight', () {
      final result = engine.calculateMelted(
        MeltedInput(
          weight: r('10'),
          purity: r('750'),
          rate: RateInput(
            value: r('10000000'),
            basis: PriceBasis.per24k,
            timestamp: now,
          ),
          timestamp: now,
        ),
      );

      expect(result.pureWeight.toDecimalString(), '7.5');
      expect(result.metalValue.toDecimalString(), '75000000');
      expect(result.finalTotal.toDecimalString(), '75000000');
    });

    test('applies melting loss', () {
      final result = engine.calculateMelted(
        MeltedInput(
          weight: r('10'),
          purity: r('750'),
          rate: RateInput(
            value: r('10000000'),
            basis: PriceBasis.per24k,
            timestamp: now,
          ),
          lossEnabled: true,
          lossPercent: r('0.02'),
          timestamp: now,
        ),
      );

      expect(result.adjustedWeight.toDecimalString(), '7.35');
    });
  });

  group('Purity conversion', () {
    test('converts 750 gold to 995 equivalent weight', () {
      final result = engine.convertPurity(
        weight: r('10'),
        fromPurity: r('750'),
        toPurity: r('995'),
      );

      expect(result.pureWeight.toDecimalString(), '7.5');
      expect(result.convertedWeight.toDecimalString(), '7.537688');
    });

    test('rejects invalid purity', () {
      expect(
        () => engine.convertPurity(
          weight: r('1'),
          fromPurity: r('0'),
          toPurity: r('750'),
        ),
        throwsA(isA<GoldCalcException>()),
      );
    });
  });

  group('Reverse calculation', () {
    test('solves weight for a target', () {
      final base = sale(
        weight: '1',
        purity: '750',
        rate: '10000000',
        labor: '0',
        profit: '0',
      );

      final target = engine.calculateSale(base).finalTotal;

      final reverse = engine.solveWeightForTarget(
        baseInput: base,
        target: target * Rational.fromInt(2),
      );

      expect(reverse.variable, 'weight');
      expect(reverse.value > r('1.9'), isTrue);
      expect(reverse.value < r('2.1'), isTrue);
    });
  });

  group('Exchange', () {
    test('calculates difference between old and new gold', () {
      final oldItem = BuyInput(
        weight: r('1'),
        purity: r('750'),
        rate: rate18('10000000'),
        buyFactor: r('1'),
        timestamp: now,
      );

      final newItem = sale(
        weight: '2',
        purity: '750',
        rate: '10000000',
        labor: '0',
        profit: '0',
      );

      final result = engine.calculateExchange(
        ExchangeInput(
          oldItems: [oldItem],
          newItems: [newItem],
        ),
      );

      expect(result.oldCredit.toDecimalString(), '10000000');
      expect(result.newTotal.toDecimalString(), '20000000');
      expect(result.cashDifference.toDecimalString(), '10000000');
    });
  });
}
