# tools/ — Agent Instructions

> Investigation and measurement tools. Run inside Godot via the Debug Panel, each gated behind its own command.
> Full context: `../docs/CONTEXT.md`. Lessons: `../docs/LESSONS.md`.

---

## What Goes Here

One-off investigation and measurement tools that answer a specific question about the sim —
e.g. "how does fear behave across many encounters," "how long does PURSUE encounter setup take."

Unlike `tests/`, tools here **may** use wall-clock time, print reports, and write files.
They assert nothing. They are not part of the regular suite — each is gated behind its own
Debug Panel command (e.g. `-- tests fearprobe`, `-- tests pursueprobe`) and excluded from
`tests <no args>`. A human runs one, reads the report, and answers a question with it.

`tools/` also holds non-GDScript helpers. `assemble_contact_responses.py` is a Python script
that lives here today.

---

## How Tools Run

Same mechanism as tests — inside Godot via the Debug Panel (`F1` → `tests <command>`) — but each
tool owns its own command name rather than running as part of the suite. See `ui/AppRoot.gd`
(`_run_tests`) for the dispatch. To verify from terminal (compile check only):
```bash
/opt/homebrew/bin/godot --headless --check-only --path /Users/jeffreygyamfi/Sites/echoes-vnext 2>&1
```

---

## Adding a New Tool

1. Create `XxxProbe.gd` (or similarly named) in `tools/`
2. Give it a `class_name` and a `register(runner)` entry point, same shape as a test suite
3. Wire a dedicated command in `ui/AppRoot.gd::_run_tests` (do not fold it into the default run)
4. Run compile check: `godot --headless --check-only ...`
5. Run the tool directly and confirm the report it produces answers the question it was built for

---

## Existing Tools

- `FearReachabilityProbe.gd` — measures Absolute Fear Rule reachability across many full encounters
- `PursueTimingProbe.gd` — measures PURSUE-encounter setup/resolution timing
- `assemble_contact_responses.py` — Python helper (non-GDScript)
