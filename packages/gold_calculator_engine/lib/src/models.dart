import 'rational.dart';
import 'rules.dart';

enum PriceBasis { per18k, per24k, perGivenPurity, perMesghal17k }

enum LaborMode { percent, perGram, fixed, percentPlusPerGram, percentPlusFixed }

enum ProfitMode { percentOfGoldPlusLabor, percentOfGold, fixed }

enum DiscountMode { fixed, percent }

enum Scenario { sale, buy, exchange, melted, conversion }

enum DeductionMode { fixed, percent }

enum FeeMode { fixed, perGram, percent }

class RateInput {
  final Rational value;
  final PriceBasis basis;
  final DateTime timestamp;
  const RateInput(
      {required this.value, required this.basis, required this.timestamp});
}

class LaborInput {
  final LaborMode mode;
  final Rational rate;
  final Rational perGram;
  final Rational fixed;
  LaborInput({
    this.mode = LaborMode.percent,
    Rational? rate,
    Rational? perGram,
    Rational? fixed,
  })  : rate = rate ?? Rational.zero,
        perGram = perGram ?? Rational.zero,
        fixed = fixed ?? Rational.zero;
}

class ProfitInput {
  final ProfitMode mode;
  final Rational rate;
  final Rational fixed;
  ProfitInput({
    this.mode = ProfitMode.percentOfGoldPlusLabor,
    Rational? rate,
    Rational? fixed,
  })  : rate = rate ?? Rational.zero,
        fixed = fixed ?? Rational.zero;
}

class DiscountInput {
  final DiscountMode mode;
  final Rational value;
  final DiscountScope scope;
  DiscountInput({
    this.mode = DiscountMode.fixed,
    Rational? value,
    this.scope = DiscountScope.total,
  }) : value = value ?? Rational.zero;
}

class SaleInput {
  final Rational grossWeight;
  final Rational purity;
  final Rational stoneWeight;
  final RateInput rate;
  final LaborInput labor;
  final ProfitInput profit;
  final Rational commission;
  final TaxRuleSet taxRules;
  final DiscountInput discount;
  final RoundingMode roundingMode;
  final int roundingUnit;
  final DateTime timestamp;

  SaleInput({
    required this.grossWeight,
    required this.purity,
    required this.rate,
    Rational? stoneWeight,
    required this.labor,
    required this.profit,
    Rational? commission,
    required this.taxRules,
    DiscountInput? discount,
    this.roundingMode = RoundingMode.halfUp,
    this.roundingUnit = 1,
    required this.timestamp,
  })  : stoneWeight = stoneWeight ?? Rational.zero,
        commission = commission ?? Rational.zero,
        discount = discount ?? DiscountInput();
}

class BuyInput {
  final Rational weight;
  final Rational purity;
  final RateInput rate;
  final Rational buyFactor;
  final DeductionMode deductionMode;
  final Rational deduction;
  final FeeMode feeMode;
  final Rational fee;
  final DateTime timestamp;

  BuyInput({
    required this.weight,
    required this.purity,
    required this.rate,
    required this.buyFactor,
    this.deductionMode = DeductionMode.fixed,
    Rational? deduction,
    this.feeMode = FeeMode.fixed,
    Rational? fee,
    required this.timestamp,
  })  : deduction = deduction ?? Rational.zero,
        fee = fee ?? Rational.zero;
}

class ExchangeInput {
  final List<BuyInput> oldItems;
  final List<SaleInput> newItems;
  const ExchangeInput({required this.oldItems, required this.newItems});
}

class MeltedInput {
  final Rational weight;
  final Rational purity;
  final RateInput rate;
  final FeeMode feeMode;
  final Rational fee;
  final Rational lossPercent;
  final bool lossEnabled;
  final DateTime timestamp;

  MeltedInput({
    required this.weight,
    required this.purity,
    required this.rate,
    this.feeMode = FeeMode.fixed,
    Rational? fee,
    Rational? lossPercent,
    this.lossEnabled = false,
    required this.timestamp,
  })  : fee = fee ?? Rational.zero,
        lossPercent = lossPercent ?? Rational.zero;
}

class CalculationResult {
  final Scenario scenario;
  final Rational metalValue;
  final Rational laborAmount;
  final Rational profitAmount;
  final Rational commissionAmount;
  final Rational taxBase;
  final Rational taxAmount;
  final Rational grossTotal;
  final Rational discountAmount;
  final Rational finalTotal;
  final Map<String, dynamic> snapshot;

  const CalculationResult({
    required this.scenario,
    required this.metalValue,
    required this.laborAmount,
    required this.profitAmount,
    required this.commissionAmount,
    required this.taxBase,
    required this.taxAmount,
    required this.grossTotal,
    required this.discountAmount,
    required this.finalTotal,
    required this.snapshot,
  });
}

class BuyResult {
  final Rational baseValue;
  final Rational discountedValue;
  final Rational deductionAmount;
  final Rational feeAmount;
  final Rational offerPrice;
  final Map<String, dynamic> snapshot;
  const BuyResult({
    required this.baseValue,
    required this.discountedValue,
    required this.deductionAmount,
    required this.feeAmount,
    required this.offerPrice,
    required this.snapshot,
  });
}

class ExchangeResult {
  final Rational oldCredit;
  final Rational newTotal;
  final Rational cashDifference;
  final Map<String, dynamic> snapshot;
  const ExchangeResult({
    required this.oldCredit,
    required this.newTotal,
    required this.cashDifference,
    required this.snapshot,
  });
}

class MeltedResult {
  final Rational pureWeight;
  final Rational adjustedWeight;
  final Rational metalValue;
  final Rational feeAmount;
  final Rational finalTotal;
  final Map<String, dynamic> snapshot;
  const MeltedResult({
    required this.pureWeight,
    required this.adjustedWeight,
    required this.metalValue,
    required this.feeAmount,
    required this.finalTotal,
    required this.snapshot,
  });
}

class ConversionResult {
  final Rational pureWeight;
  final Rational convertedWeight;
  final Rational convertedPricePerGram;
  const ConversionResult({
    required this.pureWeight,
    required this.convertedWeight,
    required this.convertedPricePerGram,
  });
}

class ReverseResult {
  final String variable;
  final Rational value;
  final Rational achievedTotal;
  final Rational absoluteError;
  const ReverseResult({
    required this.variable,
    required this.value,
    required this.achievedTotal,
    required this.absoluteError,
  });
}
