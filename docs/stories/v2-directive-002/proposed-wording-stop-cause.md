# V2-DIRECTIVE-002 phase D slice 4 — Proposed wording for the Directive stop cause

**PROPOSALS ONLY. Jeff decides.**

Jeff chose proposal C ("I follow what I was told.") and it is in the text bank.

File: `data/shouts/stop_short_text.json`. Proposal C is in the file now (chosen by Jeff).

## How to read this file

- The meaning column is written in Simplified Technical English (STE). It explains the key.
- A, B and C are proposed game lines. They are NOT STE. They follow the project voice: natural, familiar, concrete.
- A = plain. B = warmer. C = drier.
- The Echo speaks about itself, in first person.
- No line contains a number, an id or a game word (Directive, stance, cause, order as a code).
- The line works for any Directive (careful or bold). It says the Echo follows the way it was told. It does not sound like a fault of the Echo.
- Each line passes the text-bank rules in `tests/StopShortServiceTests.gd` (no digit, no underscore, no `cause`, `actor`, `benefit`, no pronoun other than I and me).

## Where the key is read

`StopShortText.cause_clause("directive_order")`. The key is the `code` of the new Directive stop cause (the existing trace code `directive_order`). No screen reads `cause_clause` now. The stop reason on the board uses `reason_line` and falls back to the plain line for a code with no own line. So the player does not see this key yet. The tests check that it resolves.

## `cause_clause.directive_order`

Meaning: the Echo stops because the Keeper's Directive told it to go carefully, or to hold back.

| key | A (plain) | B (warmer) | C (drier) |
|---|---|---|---|
| `cause_clause.directive_order` | I am doing what I was told. | I was asked to take care here, and I trust that. | I follow what I was told. |

## Optional lines (not in the file)

The code does not use `reason_line.<benefit>.with_cause.directive_order`. A Directive stop shows the plain reason line of its benefit. No proposal is made for that key.
