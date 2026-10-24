# Summon screen: rising price display (V2-ECONOMY-004, D-55, D-57, D-59, D-60, D-80, D-85)

Status: built; Jeff tests in game. Copy is PLACEHOLDER until the ux-copy pass (D-84).

## What the screen shows (approved mockup, Jeff)

1. Price card: living count, "Next Echo" price, "The one after" price, one reason line (one line, no wrap).
2. Grade row: Uncalled (selected), Called and Chosen shown but locked. No price shows for a locked grade.
3. Count stepper: minus, count, plus, Max, and the total. Range 1 to the affordable maximum.
4. Ase balance and rate hint. A "Need N more Ase" line shows only when the player cannot pay for one summon.
5. Summon button.

## Rules kept

- The screen reads every price and total from the snapshot (`FlowSummonState`). It computes no price.
  The only arithmetic is the shortfall: `batch_totals[count-1] - ase_balance`.
- The batch total is `batch_totals[count-1]`. No product of count and price exists in `ui/`.
- No "cheaper" or "discount" wording. No id. The word is "village".
- The reason line switches on `price_flat`.

## Where things are

| Item | File |
|---|---|
| Screen | `ui/screens/sanctum/SummonScreen.tscn`, `.gd` |
| Copy table (one place to edit) | `data/ui/summon_price_text.json`, read by `ui/components/SummonPriceText.gd` |
| Locked grades | `_OPEN_GRADES` in `SummonScreen.gd`. Add `"called"` or `"chosen"` to open one. |
| UI tests | `tests/SummonPriceUITests.gd` (suite `summon_price_ui`) |
| Screenshots | `scripts/screenshot.gd` fixtures `summon_price_rising`, `summon_price_flat`, `summon_price_short` |

## Open items for Jeff

1. The snapshot has no locked flag per grade. `_OPEN_GRADES` is a UI constant until a field exists.
2. No lock icon asset exists. Locked grades use the disabled style and a tooltip. `sr-game-artist` can supply an icon.
3. At 1280x720 the intro line is hidden so the stepper and button stay in view (`INTRO_MIN_HEIGHT` in `SummonScreen.gd`).
4. Opening Called or Chosen needs `sanctum.grade_select` wiring in the screen. It is not built because both stay locked.
5. Not in this story: the next price on the Sanctum home screen; the price change moment after a recruit or a loss.
