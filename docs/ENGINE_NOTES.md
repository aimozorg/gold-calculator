# Engineering Notes

## Unit strategy

- Weight inputs are decimal grams.
- Money is represented as exact rationals inside the engine and rounded only at the configured money boundary.
- UI should show تومان by default and label the unit beside every rate.

## Snapshot strategy

Every completed sale calculation stores:
- engine_version
- ruleset_version
- scenario
- input rates and their timestamps
- raw inputs
- derived components
- final output

This makes replay/audit possible even after prices change.

## Reverse solver

The first implementation uses monotonic bisection rather than assuming every formula is analytically linear. This is intentional so the solver remains correct across per-gram labor, fixed labor, commissions, discounts, and configurable tax treatment.

## Scope boundary

This engine intentionally excludes:
- live market price feeds
- accounting ledger
- inventory ERP
- e-invoice submission
- banking/payment processing
- subscription enforcement

Those belong to application/service layers.
