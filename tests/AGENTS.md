# tests/ — Agent Instructions

> Deterministic unit tests for the core simulation. Run inside Godot via CoreTestRunner.
> Full context: `../docs/CONTEXT.md`. Lessons: `../docs/LESSONS.md`.

---

## What Goes Here

One test file per system (e.g. `EconomyTests.gd`, `SanctumSummonTests.gd`).
Tests are pure GDScript — no UI, no scene tree, no network, no OS time.

---

## How Tests Run

Tests execute inside Godot via the Debug Panel (`F1` → `tests` command) or `CoreTestRunner.gd`.
There is no standalone CLI runner. To verify from terminal (compile check only):
```bash
/opt/homebrew/bin/godot --headless --check-only --path /Users/jeffreygyamfi/Sites/echoes-vnext 2>&1
```

---

## Test Rules

### Isolation — every test is self-contained
Each test must set up its own environment. Never depend on global state, save files, or test execution order.

### Set balance directly — never via service add methods
```gdscript
# CORRECT — deterministic starting state
var save_data = _make_runtime_env()
save_data["economy"]["ase"] = 500   # set directly

# FORBIDDEN — adds ON TOP of whatever the save file has
economy_service.add_ase(500, save_data, logger, 0)   # non-deterministic
```

`_make_runtime_env()` loads the real save file. Tests that need a controlled balance must set values directly on the save ref.

### No RNG without seeded CampaignSeed
Tests that need randomness must create a `CampaignSeed` with a fixed seed and call `.derive()`. Never call `randi()`, `randf()`, or `randomize()`.

### No print() — use assertions
Tests assert return values and state. Never use `print()` to inspect results. Assertion failures are surfaced by `CoreTestRunner`.

---

## Test File Pattern

```gdscript
class_name EconomyTests

const SUITE_NAME = "EconomyTests"

func run_all(runner) -> void:
    runner.describe(SUITE_NAME)
    _test_spend_ase_reduces_balance(runner)
    _test_cannot_spend_more_than_balance(runner)
    # ...

func _test_spend_ase_reduces_balance(runner) -> void:
    var env = _make_runtime_env()
    env["save_data"]["economy"]["ase"] = 200

    var result = EconomyService.spend_ase(50, env["save_data"], env["logger"], 0)

    runner.expect(result).to_be(true)
    runner.expect(env["save_data"]["economy"]["ase"]).to_equal(150)

func _make_runtime_env() -> Dictionary:
    # construct minimal save_data + logger for isolated testing
    ...
```

---

## Adding a New Test Suite

1. Create `XxxTests.gd` in `tests/`
2. Follow the `class_name / run_all / _test_*` pattern above
3. Register in `CoreTestRunner.gd`
4. Run compile check: `godot --headless --check-only ...`
5. Verify via Debug Panel before marking story done

---

## Existing Suites (do not duplicate coverage)

EconomyTests, SanctumSummonTests, PartyTests, ActorTests, EchoSchemaTests, ActorStatInitTests,
DerivedStatTests, BehaviorModuleTests, MeleeTests, BehaviorArbiterTests, StructureTests,
MoraleInfluenceTests, KODeathTests, EmotionTests, VectorTests, DirectiveTests, GridTests,
CombatStateTests, CombatServiceTests, CombatRoundTests, CombatSnapshotTests, RetreatTests,
ArchetypeTests, StageProgressionTests, SkillDefinitionTests, CallingBehaviorTests,
ExclusiveActionTests, CooldownTests, PassiveIdentityTests, SkillLoadoutTests,
MaturityExpressionTests, ThreadServiceTests, VowServiceTests, SocialGraphTests, ProgressionTests,
RealmModelTests, StageModelTests, CallingTests
