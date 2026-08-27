import 'errors.dart';
import 'models.dart';
import 'rational.dart';
import 'rules.dart';

class GoldCalculationEngine {
  final EngineRules rules;
  const GoldCalculationEngine({required this.rules});

  Rational netWeight({required Rational grossWeight, Rational stoneWeight = Rational.zero}) {
    _requirePositive(grossWeight, 'E001', 'وزن باید بیشتر از صفر باشد.');
    if (stoneWeight.isNegative) throw const GoldCalcException('E004', 'وزن سنگ نمی‌تواند منفی باشد.');
    if (stoneWeight > grossWeight) {
      throw const GoldCalcException('E008', 'وزن سنگ بیشتر از وزن کل است.');
    }
    return grossWeight - stoneWeight;
  }

  Rational rateForPurity({required RateInput rate, required Rational purity}) {
    _validatePurity(purity);
    switch (rate.basis) {
      case PriceBasis.per18k:
        return rate.value * (purity / Rational.fromInt(750));
      case PriceBasis.per24k:
        return rate.value * (purity / Rational.fromInt(1000));
      case PriceBasis.perGivenPurity:
        return rate.value;
      case PriceBasis.perMesghal17k:
        final price18 = (rate.value / Rational.parse('4.608')) *
            (Rational.fromInt(750) / Rational.fromInt(705));
        return price18 * (purity / Rational.fromInt(750));
    }
  }

  CalculationResult calculateSale(SaleInput input) {
    _validateSale(input);
    final net = netWeight(grossWeight: input.grossWeight, stoneWeight: input.stoneWeight);
    final itemRate = rateForPurity(rate: input.rate, purity: input.purity);
    final metal = net * itemRate;
    final labor = _laborAmount(input.labor, metal, net);
    final profit = _profitAmount(input.profit, metal, labor);
    final commission = _nonNegative(input.commission, 'commission');

    final taxBaseBeforeDiscount = labor + profit + commission;
    final grossBeforeDiscountTax = metal + labor + profit + commission;

    Rational taxBase = taxBaseBeforeDiscount;
    Rational tax;
    Rational discount;

    if (input.taxRules.discountTaxTreatment == DiscountTaxTreatment.reduceTaxableBase) {
      discount = _discountAmount(input.discount, grossBeforeDiscountTax, labor, profit, commission);
      final applicable = _discountAgainstScope(input.discount.scope, discount, labor, profit, commission);
      taxBase = (taxBaseBeforeDiscount - applicable).max(Rational.zero);
      tax = taxBase * input.taxRules.rate;
      discount = input.discount.scope == DiscountScope.total
          ? _clampDiscount(discount, grossBeforeDiscountTax)
          : discount;
    } else {
      tax = taxBaseBeforeDiscount * input.taxRules.rate;
      final grossAfterTax = grossBeforeDiscountTax + tax;
      discount = _discountAmount(input.discount, grossAfterTax, labor, profit, commission);
      discount = input.discount.scope == DiscountScope.total
          ? _clampDiscount(discount, grossAfterTax)
          : discount;
    }

    final gross = grossBeforeDiscountTax + tax;
    final finalTotalRaw = (gross - discount).max(Rational.zero);
    final finalTotal = _roundMoney(finalTotalRaw, input.roundingUnit, input.roundingMode);

    return CalculationResult(
      scenario: Scenario.sale,
      metalValue: metal,
      laborAmount: labor,
      profitAmount: profit,
      commissionAmount: commission,
      taxBase: taxBase,
      taxAmount: tax,
      grossTotal: gross,
      discountAmount: discount,
      finalTotal: Rational(finalTotal),
      snapshot: _saleSnapshot(input, net, itemRate, metal, labor, profit, commission, taxBase, tax, gross, discount, finalTotal),
    );
  }

  BuyResult calculateBuy(BuyInput input) {
    _validateBuy(input);
    final itemRate = rateForPurity(rate: input.rate, purity: input.purity);
    final base = input.weight * itemRate;
    final discounted = base * input.buyFactor;
    final deduction = input.deductionMode == DeductionMode.percent
        ? discounted * input.deduction
        : input.deduction;
    final afterDeduction = (discounted - deduction).max(Rational.zero);
    final feeAmount = _feeAmount(input.feeMode, input.fee, input.weight, afterDeduction);
    final offer = (afterDeduction - feeAmount).max(Rational.zero);
    return BuyResult(
      baseValue: base,
      discountedValue: discounted,
      deductionAmount: deduction,
      feeAmount: feeAmount,
      offerPrice: offer,
      snapshot: {
        'engine_version': rules.engineVersion,
        'scenario': 'buy',
        'weight': input.weight.toDecimalString(),
        'purity': input.purity.toDecimalString(),
        'rate': input.rate.value.toDecimalString(),
        'rate_basis': input.rate.basis.name,
        'rate_timestamp': input.rate.timestamp.toIso8601String(),
        'buy_factor': input.buyFactor.toDecimalString(),
        'deduction': input.deduction.toDecimalString(),
        'deduction_mode': input.deductionMode.name,
        'fee': input.fee.toDecimalString(),
        'fee_mode': input.feeMode.name,
        'outputs': {
          'base_value': base.toDecimalString(),
          'discounted_value': discounted.toDecimalString(),
          'deduction_amount': deduction.toDecimalString(),
          'fee_amount': feeAmount.toDecimalString(),
          'offer_price': offer.toDecimalString(),
        },
      },
    );
  }

  ExchangeResult calculateExchange(ExchangeInput input) {
    if (input.oldItems.isEmpty || input.newItems.isEmpty) {
      throw const GoldCalcException('E014', 'تعویض باید حداقل یک قطعه قدیمی و یک قطعه جدید داشته باشد.');
    }
    Rational oldCredit = Rational.zero;
    for (final oldItem in input.oldItems) {
      oldCredit += calculateBuy(oldItem).offerPrice;
    }
    Rational newTotal = Rational.zero;
    final snapshots = <Map<String, dynamic>>[];
    for (final newItem in input.newItems) {
      final result = calculateSale(newItem);
      newTotal += result.finalTotal;
      snapshots.add(result.snapshot);
    }
    final difference = newTotal - oldCredit;
    return ExchangeResult(
      oldCredit: oldCredit,
      newTotal: newTotal,
      cashDifference: difference,
      snapshot: {
        'engine_version': rules.engineVersion,
        'scenario': 'exchange',
        'old_credit': oldCredit.toDecimalString(),
        'new_total': newTotal.toDecimalString(),
        'cash_difference': difference.toDecimalString(),
        'customer_pays_when_positive': difference > Rational.zero,
        'customer_receives_when_negative': difference < Rational.zero,
        'new_item_snapshots': snapshots,
      },
    );
  }

  MeltedResult calculateMelted(MeltedInput input) {
    _validateMelted(input);
    final pure = input.weight * (input.purity / Rational.fromInt(1000));
    final adjusted = input.lossEnabled
        ? pure * (Rational.one - input.lossPercent)
        : pure;
    final perGram24 = _rateAs24k(rate: input.rate);
    final metal = adjusted * perGram24;
    final fee = _feeAmount(input.feeMode, input.fee, input.weight, metal);
    final finalTotal = (metal - fee).max(Rational.zero);
    return MeltedResult(
      pureWeight: pure,
      adjustedWeight: adjusted,
      metalValue: metal,
      feeAmount: fee,
      finalTotal: finalTotal,
      snapshot: {
        'engine_version': rules.engineVersion,
        'scenario': 'melted',
        'weight': input.weight.toDecimalString(),
        'purity': input.purity.toDecimalString(),
        'rate': input.rate.value.toDecimalString(),
        'rate_basis': input.rate.basis.name,
        'loss_enabled': input.lossEnabled,
        'loss_percent': input.lossPercent.toDecimalString(),
        'fee_mode': input.feeMode.name,
        'fee': input.fee.toDecimalString(),
        'outputs': {
          'pure_weight': pure.toDecimalString(),
          'adjusted_weight': adjusted.toDecimalString(),
          'metal_value': metal.toDecimalString(),
          'fee_amount': fee.toDecimalString(),
          'final_total': finalTotal.toDecimalString(),
        },
      },
    );
  }

  ConversionResult convertPurity({required Rational weight, required Rational fromPurity, required Rational toPurity}) {
    _requirePositive(weight, 'E001', 'وزن باید بیشتر از صفر باشد.');
    _validatePurity(fromPurity);
    _validatePurity(toPurity);
    final pure = weight * (fromPurity / Rational.fromInt(1000));
    final converted = pure / (toPurity / Rational.fromInt(1000));
    return ConversionResult(pureWeight: pure, convertedWeight: converted, convertedPricePerGram: Rational.zero);
  }

  ConversionResult convertPrice({required Rational price, required PriceBasis from, required Rational targetPurity}) {
    _validatePurity(targetPurity);
    final rate = RateInput(value: price, basis: from, timestamp: DateTime.now());
    final converted = rateForPurity(rate: rate, purity: targetPurity);
    return ConversionResult(
      pureWeight: Rational.zero,
      convertedWeight: Rational.zero,
      convertedPricePerGram: converted,
    );
  }

  Rational mesghal17To18({required Rational mesghalPrice}) =>
      (mesghalPrice / Rational.parse('4.608')) *
      (Rational.fromInt(750) / Rational.fromInt(705));

  Rational gram18ToMesghal17({required Rational price18}) =>
      price18 * Rational.parse('4.608') * (Rational.fromInt(705) / Rational.fromInt(750));

  ReverseResult solveWeightForTarget({required SaleInput baseInput, required Rational target, Rational tolerance = const Rational._(BigInt.from(1), BigInt.from(1000))}) {
    _requireNonNegative(target, 'target');
    var low = Rational.zero;
    var high = Rational.fromInt(1);
    for (var i = 0; i < 160 && calculateSale(_copySale(baseInput, grossWeight: high)).finalTotal < target; i++) {
      high = high * Rational.fromInt(2);
    }
    if (calculateSale(_copySale(baseInput, grossWeight: high)).finalTotal < target) {
      throw const GoldCalcException('E015', 'برای مبلغ هدف، وزن قابل حل در محدوده موتور پیدا نشد.');
    }
    for (var i = 0; i < 220; i++) {
      final mid = (low + high) / Rational.fromInt(2);
      final total = calculateSale(_copySale(baseInput, grossWeight: mid)).finalTotal;
      final diff = total - target;
      if (diff.abs() <= tolerance) {
        return ReverseResult(variable: 'weight', value: mid, achievedTotal: total, absoluteError: diff.abs());
      }
      if (diff.isNegative) {
        low = mid;
      } else {
        high = mid;
      }
    }
    final mid = (low + high) / Rational.fromInt(2);
    final total = calculateSale(_copySale(baseInput, grossWeight: mid)).finalTotal;
    return ReverseResult(variable: 'weight', value: mid, achievedTotal: total, absoluteError: (total - target).abs());
  }

  ReverseResult solveLaborPercentForTarget({required SaleInput baseInput, required Rational target, Rational tolerance = const Rational._(BigInt.from(1), BigInt.from(1000)), Rational lowPercent = const Rational._(BigInt.zero, BigInt.one), Rational highPercent = const Rational._(BigInt.from(100), BigInt.one)}) {
    return _solveMonotonic(
      variable: 'labor_percent',
      target: target,
      low: lowPercent,
      high: highPercent,
      valueOf: (x) => calculateSale(_copySale(baseInput, labor: LaborInput(mode: LaborMode.percent, rate: x))).finalTotal,
      tolerance: tolerance,
      rebuild: (x) => calculateSale(_copySale(baseInput, labor: LaborInput(mode: LaborMode.percent, rate: x))),
    );
  }

  ReverseResult solveProfitPercentForTarget({required SaleInput baseInput, required Rational target, Rational tolerance = const Rational._(BigInt.from(1), BigInt.from(1000)), Rational lowPercent = const Rational._(BigInt.zero, BigInt.one), Rational highPercent = const Rational._(BigInt.from(100), BigInt.one)}) {
    return _solveMonotonic(
      variable: 'profit_percent',
      target: target,
      low: lowPercent,
      high: highPercent,
      valueOf: (x) => calculateSale(_copySale(baseInput, profit: ProfitInput(mode: ProfitMode.percentOfGoldPlusLabor, rate: x))).finalTotal,
      tolerance: tolerance,
      rebuild: (x) => calculateSale(_copySale(baseInput, profit: ProfitInput(mode: ProfitMode.percentOfGoldPlusLabor, rate: x))),
    );
  }

  ReverseResult solveDiscountForTarget({required SaleInput baseInput, required Rational target, Rational tolerance = const Rational._(BigInt.from(1), BigInt.from(1000))}) {
    final noDiscount = calculateSale(_copySale(baseInput, discount: const DiscountInput(value: Rational.zero))).grossTotal;
    final required = (noDiscount - target).max(Rational.zero);
    if (required > noDiscount) throw const GoldCalcException('E016', 'تخفیف هدف بیشتر از مبلغ معامله است.');
    final achieved = calculateSale(_copySale(baseInput, discount: DiscountInput(mode: DiscountMode.fixed, value: required))).finalTotal;
    return ReverseResult(variable: 'discount', value: required, achievedTotal: achieved, absoluteError: (achieved - target).abs());
  }

  Rational roundMoney(Rational amount, int unit, RoundingMode mode) => _roundMoney(amount, unit, mode);

  Rational _rateAs24k({required RateInput rate}) {
    switch (rate.basis) {
      case PriceBasis.per24k:
        return rate.value;
      case PriceBasis.per18k:
        return rate.value * Rational.fromInt(1000) / Rational.fromInt(750);
      case PriceBasis.perGivenPurity:
        throw const GoldCalcException('E017', 'برای نرخ perGivenPurity باید عیار مبنا نیز در ورودی مشخص باشد.');
      case PriceBasis.perMesghal17k:
        return mesghal17To18(mesghalPrice: rate.value) * Rational.fromInt(1000) / Rational.fromInt(750);
    }
  }

  Rational _laborAmount(LaborInput labor, Rational metal, Rational net) {
    _requireNonNegative(labor.rate, 'labor_rate');
    _requireNonNegative(labor.perGram, 'labor_per_gram');
    _requireNonNegative(labor.fixed, 'labor_fixed');
    switch (labor.mode) {
      case LaborMode.percent:
        return metal * labor.rate;
      case LaborMode.perGram:
        return net * labor.perGram;
      case LaborMode.fixed:
        return labor.fixed;
      case LaborMode.percentPlusPerGram:
        return metal * labor.rate + net * labor.perGram;
      case LaborMode.percentPlusFixed:
        return metal * labor.rate + labor.fixed;
    }
  }

  Rational _profitAmount(ProfitInput profit, Rational metal, Rational labor) {
    _requireNonNegative(profit.rate, 'profit_rate');
    _requireNonNegative(profit.fixed, 'profit_fixed');
    switch (profit.mode) {
      case ProfitMode.percentOfGoldPlusLabor:
        return (metal + labor) * profit.rate;
      case ProfitMode.percentOfGold:
        return metal * profit.rate;
      case ProfitMode.fixed:
        return profit.fixed;
    }
  }

  Rational _discountAmount(DiscountInput discount, Rational gross, Rational labor, Rational profit, Rational commission) {
    _requireNonNegative(discount.value, 'discount');
    final base = switch (discount.scope) {
      DiscountScope.total => gross,
      DiscountScope.labor => labor,
      DiscountScope.profit => profit,
      DiscountScope.commission => commission,
    };
    return discount.mode == DiscountMode.percent ? base * discount.value : discount.value;
  }

  Rational _discountAgainstScope(DiscountScope scope, Rational discount, Rational labor, Rational profit, Rational commission) {
    final base = switch (scope) {
      DiscountScope.total => labor + profit + commission,
      DiscountScope.labor => labor,
      DiscountScope.profit => profit,
      DiscountScope.commission => commission,
    };
    return discount.min(base);
  }

  Rational _feeAmount(FeeMode mode, Rational fee, Rational weight, Rational base) {
    _requireNonNegative(fee, 'fee');
    switch (mode) {
      case FeeMode.fixed:
        return fee;
      case FeeMode.perGram:
        return fee * weight;
      case FeeMode.percent:
        return base * fee;
    }
  }

  Rational _clampDiscount(Rational discount, Rational gross) => discount.min(gross).max(Rational.zero);

  Rational _roundMoney(Rational amount, int unit, RoundingMode mode) {
    if (unit <= 0) throw ArgumentError('Rounding unit must be positive.');
    if (mode == RoundingMode.none) return amount;
    final scaled = amount / Rational.fromInt(unit);
    final whole = scaled.round(mode: mode);
    return Rational(whole * BigInt.fromInt(unit));
  }

  ReverseResult _solveMonotonic({required String variable, required Rational target, required Rational low, required Rational high, required Rational Function(Rational) valueOf, required CalculationResult Function(Rational) rebuild, required Rational tolerance}) {
    _requireNonNegative(target, 'target');
    final lowValue = valueOf(low);
    final highValue = valueOf(high);
    if (target < lowValue || target > highValue) {
      throw GoldCalcException('E018', 'مبلغ هدف خارج از محدوده قابل دستیابی برای $variable است.');
    }
    var a = low;
    var b = high;
    for (var i = 0; i < 220; i++) {
      final mid = (a + b) / Rational.fromInt(2);
      final value = valueOf(mid);
      final diff = value - target;
      if (diff.abs() <= tolerance) {
        final result = rebuild(mid);
        return ReverseResult(variable: variable, value: mid, achievedTotal: result.finalTotal, absoluteError: (result.finalTotal - target).abs());
      }
      if (value < target) {
        a = mid;
      } else {
        b = mid;
      }
    }
    final mid = (a + b) / Rational.fromInt(2);
    final result = rebuild(mid);
    return ReverseResult(variable: variable, value: mid, achievedTotal: result.finalTotal, absoluteError: (result.finalTotal - target).abs());
  }

  SaleInput _copySale(SaleInput source, {Rational? grossWeight, LaborInput? labor, ProfitInput? profit, DiscountInput? discount}) => SaleInput(
        grossWeight: grossWeight ?? source.grossWeight,
        purity: source.purity,
        stoneWeight: source.stoneWeight,
        rate: source.rate,
        labor: labor ?? source.labor,
        profit: profit ?? source.profit,
        commission: source.commission,
        taxRules: source.taxRules,
        discount: discount ?? source.discount,
        roundingMode: source.roundingMode,
        roundingUnit: source.roundingUnit,
        timestamp: source.timestamp,
      );

  void _validateSale(SaleInput input) {
    _requirePositive(input.grossWeight, 'E001', 'وزن باید بیشتر از صفر باشد.');
    _validatePurity(input.purity);
    _requireNonNegative(input.grossWeight - input.stoneWeight, 'net_weight');
    if (input.rate.value.isNegative) throw const GoldCalcException('E003', 'نرخ نمی‌تواند منفی باشد.');
    if (input.rate.value.isZero) throw const GoldCalcException('E003', 'نرخ باید بیشتر از صفر باشد.');
  }

  void _validateBuy(BuyInput input) {
    _requirePositive(input.weight, 'E001', 'وزن باید بیشتر از صفر باشد.');
    _validatePurity(input.purity);
    if (input.rate.value.isNegative) throw const GoldCalcException('E003', 'نرخ نمی‌تواند منفی باشد.');
    if (input.rate.value.isZero) throw const GoldCalcException('E003', 'نرخ باید بیشتر از صفر باشد.');
    _requireNonNegative(input.buyFactor, 'buy_factor');
    _requireNonNegative(input.deduction, 'deduction');
  }

  void _validateMelted(MeltedInput input) {
    _requirePositive(input.weight, 'E001', 'وزن باید بیشتر از صفر باشد.');
    _validatePurity(input.purity);
    if (input.rate.value.isNegative || input.rate.value.isZero) throw const GoldCalcException('E003', 'نرخ باید بیشتر از صفر باشد.');
    _requireNonNegative(input.lossPercent, 'loss_percent');
    if (input.lossPercent > Rational.one) throw const GoldCalcException('E019', 'کسر ذوب نمی‌تواند بیشتر از 100 درصد باشد.');
  }

  void _validatePurity(Rational purity) {
    if (purity <= Rational.zero || purity > Rational.fromInt(1000)) {
      throw const GoldCalcException('E002', 'عیار باید بیشتر از صفر و حداکثر 1000 باشد.');
    }
  }

  void _requirePositive(Rational value, String code, String message) {
    if (value <= Rational.zero) throw GoldCalcException(code, message);
  }

  void _requireNonNegative(Rational value, String name) {
    if (value.isNegative) throw GoldCalcException('E004', '$name نمی‌تواند منفی باشد.');
  }

  Rational _nonNegative(Rational value, String name) {
    _requireNonNegative(value, name);
    return value;
  }

  Map<String, dynamic> _saleSnapshot(SaleInput input, Rational net, Rational itemRate, Rational metal, Rational labor, Rational profit, Rational commission, Rational taxBase, Rational tax, Rational gross, Rational discount, BigInt finalTotal) => {
        'engine_version': rules.engineVersion,
        'ruleset_version': input.taxRules.version,
        'scenario': 'sale',
        'timestamp': input.timestamp.toIso8601String(),
        'gross_weight': input.grossWeight.toDecimalString(),
        'stone_weight': input.stoneWeight.toDecimalString(),
        'net_gold_weight': net.toDecimalString(),
        'purity': input.purity.toDecimalString(),
        'rate': input.rate.value.toDecimalString(),
        'rate_basis': input.rate.basis.name,
        'rate_timestamp': input.rate.timestamp.toIso8601String(),
        'labor_mode': input.labor.mode.name,
        'profit_mode': input.profit.mode.name,
        'tax_rate': input.taxRules.rate.toDecimalString(),
        'discount_mode': input.discount.mode.name,
        'discount_scope': input.discount.scope.name,
        'outputs': {
          'item_rate': itemRate.toDecimalString(),
          'metal_value': metal.toDecimalString(),
          'labor_amount': labor.toDecimalString(),
          'profit_amount': profit.toDecimalString(),
          'commission_amount': commission.toDecimalString(),
          'tax_base': taxBase.toDecimalString(),
          'tax_amount': tax.toDecimalString(),
          'gross_total': gross.toDecimalString(),
          'discount_amount': discount.toDecimalString(),
          'final_total': finalTotal.toString(),
        },
      };
}
