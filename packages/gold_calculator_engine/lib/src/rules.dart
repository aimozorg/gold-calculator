import 'rational.dart';

enum TaxBaseRule { laborPlusProfitPlusCommission }

enum DiscountTaxTreatment { afterTax, reduceTaxableBase }

enum DiscountScope { total, labor, profit, commission }

class TaxRuleSet {
  final String version;
  final Rational rate;
  final TaxBaseRule baseRule;
  final bool goldPrincipalExempt;
  final DiscountTaxTreatment discountTaxTreatment;

  const TaxRuleSet({
    required this.version,
    required this.rate,
    this.baseRule = TaxBaseRule.laborPlusProfitPlusCommission,
    this.goldPrincipalExempt = true,
    this.discountTaxTreatment = DiscountTaxTreatment.afterTax,
  });

  factory TaxRuleSet.iran1405() => TaxRuleSet(
        version: 'IR-VAT-1405-10P-DRAFT',
        rate: percent('10'),
      );
}

class EngineRules {
  final String engineVersion;
  final String currency;
  final TaxRuleSet taxRuleSet;
  final Rational defaultSellerProfitRate;
  final int defaultMoneyRoundingUnit;

  EngineRules({
    this.engineVersion = 'GCE-1.0.0',
    this.currency = 'IRT',
    required this.taxRuleSet,
    Rational? defaultSellerProfitRate,
    this.defaultMoneyRoundingUnit = 1,
  }) : defaultSellerProfitRate = defaultSellerProfitRate ??
            (Rational.parse('7') / Rational.fromInt(100));

  factory EngineRules.mvp1405() =>
      EngineRules(taxRuleSet: TaxRuleSet.iran1405());
}
