# Test Manifest

## Suite — `test/gold_calculator_engine_test.dart`

Location: top-level `test/` folder. Uses `flutter_test` (not the bare `test`
package), so run it with:

```bash
flutter test
```

13 tests across 7 groups:
- `Rational` — exact decimal arithmetic (no float drift), fraction
  normalization
- `Sale` — basic sale, labor + profit combined, stone-weight deduction,
  E00x validation for zero weight and stone-heavier-than-item
- `Buy` — customer purchase offer, percentage deduction
- `Melted gold` — pure weight from purity, melting loss
- `Purity conversion` — 750→995 equivalent weight, invalid-purity
  rejection
- `Reverse calculation` — `solveWeightForTarget`
- `Exchange` — cash difference between an old buy-back item and a new
  sale item

Every golden value in this suite has been independently hand-verified
(recomputed from the formulas in `ENGINE_NOTES.md`, not just re-derived
from the code) — no errors found.

## What this suite does not cover yet

Compared to the engine's full surface area, these are still untested:
- `calculateExchange` with multiple old/new items, or an empty list
  (`E014`)
- `solveDiscountForTarget`, `solveLaborPercentForTarget`,
  `solveProfitPercentForTarget` (only `solveWeightForTarget` is covered)
- `convertPrice`
- Discount modes/scopes on `calculateSale` (percent vs fixed, and the
  `afterTax` vs `reduceTaxableBase` tax treatments) — only the
  no-discount path is exercised
- Labor modes other than `percent` (`perGram`, `fixed`,
  `percentPlusPerGram`, `percentPlusFixed`)
- `roundMoney` directly, and non-default rounding units/modes
- Most `E0xx` error codes beyond the two covered in the `Sale` group

## Not yet executed by Claude

These tests have been reviewed and hand-verified line by line, but this
review environment has no Flutter SDK, so `flutter test` has not actually
been run here. If it hasn't been run in your environment either, do that
before trusting this suite for real transactions.
