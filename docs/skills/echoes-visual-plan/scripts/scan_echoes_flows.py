#!/usr/bin/env python3
"""
Static Echoes vNext visual-plan scanner and HTML prototype exporter.

Run from the repository root:
  python3 docs/skills/echoes-visual-plan/scripts/scan_echoes_flows.py --root .
  python3 docs/skills/echoes-visual-plan/scripts/scan_echoes_flows.py --root . --html /tmp/echoes-flow-scan.html
"""

from __future__ import annotations

import argparse
import html
import re
from pathlib import Path


FLOW_RE = re.compile(r'"(flow\.[a-zA-Z0-9_\.]+)"')
ACTION_SLOT_RE = re.compile(r'"((?:nav|cta|overlay|primary|secondary|back)[a-zA-Z0-9_\.\-]*)"')
ACTION_TYPE_RE = re.compile(r'"type"\s*:\s*"([a-zA-Z0-9_]+\.[a-zA-Z0-9_\.]+)"')
PRELOAD_RE = re.compile(r'preload\("res://([^"]+)"\)')
MODAL_ID_RE = re.compile(r'&"([a-zA-Z0-9_\.]+)"')
CLASS_RE = re.compile(r'^\s*class_name\s+([A-Za-z0-9_]+)', re.MULTILINE)
EXTENDS_RE = re.compile(r'^\s*extends\s+([A-Za-z0-9_\.]+)', re.MULTILINE)
NODE_RE = re.compile(r'^\[node name="([^"]+)" type="([^"]+)"', re.MULTILINE)
SIGNAL_RE = re.compile(r'^\s*signal\s+([A-Za-z0-9_]+)', re.MULTILINE)


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return path.read_text(errors="replace")


def rel(path: Path, root: Path) -> str:
    return path.relative_to(root).as_posix()


def collect_files(root: Path, pattern: str) -> list[Path]:
    ignored = {".git", ".godot", ".import"}
    files: list[Path] = []
    for path in root.rglob(pattern):
        if any(part in ignored for part in path.parts):
            continue
        files.append(path)
    return sorted(files)


def first(values: list[str]) -> str:
    return values[0] if values else ""


def scan_flow_states(root: Path) -> list[dict[str, object]]:
    state_root = root / "core" / "state" / "flow" / "states"
    rows: list[dict[str, object]] = []
    if not state_root.exists():
        return rows
    for path in collect_files(state_root, "*.gd"):
        text = read_text(path)
        rows.append(
            {
                "file": rel(path, root),
                "class": first(CLASS_RE.findall(text)),
                "extends": first(EXTENDS_RE.findall(text)),
                "flows": sorted(set(FLOW_RE.findall(text))),
                "action_slots": sorted(set(ACTION_SLOT_RE.findall(text))),
                "action_types": sorted(set(ACTION_TYPE_RE.findall(text))),
                "build_snapshot": "build_snapshot" in text or "build_round_snapshot" in text,
            }
        )
    return rows


def scan_routes(root: Path) -> list[dict[str, object]]:
    route_files = [
        root / "ui" / "AppRoot.gd",
        root / "ui" / "shells" / "SanctumShell.gd",
        root / "ui" / "shells" / "RealmShell.gd",
    ]
    rows: list[dict[str, object]] = []
    for path in route_files:
        if not path.exists():
            continue
        text = read_text(path)
        rows.append(
            {
                "file": rel(path, root),
                "flows": sorted(set(FLOW_RE.findall(text))),
                "preloads": sorted(set(PRELOAD_RE.findall(text))),
                "modal_ids": sorted(set(MODAL_ID_RE.findall(text))),
            }
        )
    return rows


def scan_screens(root: Path) -> list[dict[str, object]]:
    screen_root = root / "ui" / "screens"
    rows: list[dict[str, object]] = []
    if not screen_root.exists():
        return rows
    for script in collect_files(screen_root, "*.gd"):
        text = read_text(script)
        scene = script.with_suffix(".tscn")
        scene_nodes: list[str] = []
        if scene.exists():
            scene_text = read_text(scene)
            scene_nodes = [f"{name}:{kind}" for name, kind in NODE_RE.findall(scene_text)[:18]]
        rows.append(
            {
                "file": rel(script, root),
                "class": first(CLASS_RE.findall(text)),
                "flows": sorted(set(FLOW_RE.findall(text))),
                "action_slots": sorted(set(ACTION_SLOT_RE.findall(text))),
                "signals": sorted(set(SIGNAL_RE.findall(text))),
                "scene": rel(scene, root) if scene.exists() else "",
                "scene_nodes": scene_nodes,
            }
        )
    return rows


def collect_scan(root: Path) -> dict[str, object]:
    return {
        "root": str(root),
        "routes": scan_routes(root),
        "states": scan_flow_states(root),
        "screens": scan_screens(root),
    }


def shell_for_flow(flow: str) -> str:
    sanctum = {
        "flow.sanctum",
        "flow.summon",
        "flow.echo_party",
        "flow.realm_select",
        "flow.vow_manage",
        "flow.weaving_rite",
    }
    realm = {
        "flow.stage_map",
        "flow.stage",
        "flow.stage_explore",
        "flow.encounter",
        "flow.keeper_trial",
        "flow.resolve",
    }
    onboarding = {
        "flow.onboarding_invocation",
        "flow.onboarding_anansi",
        "flow.onboarding_choose_name",
        "flow.onboarding_meeting",
        "flow.onboarding_empty_sanctum",
        "flow.onboarding_name_sanctum",
        "flow.keeper_call",
        "flow.keeper_rewind",
        "flow.keeper_thread_return",
        "flow.keeper_awakening",
        "flow.keeper_weaving",
        "flow.keeper_keeping",
    }
    if flow in sanctum:
        return "SanctumShell"
    if flow in realm:
        return "RealmShell"
    if flow in onboarding:
        return "AppRoot onboarding"
    if flow in {"flow.splash", "flow.main_menu", "flow.save_error"}:
        return "AppRoot boot"
    return "Unmapped/Action"


def screen_guess(flow: str, scan: dict[str, object]) -> str:
    direct = {
        "flow.sanctum": "SanctumScreen",
        "flow.summon": "SummonScreen",
        "flow.echo_party": "EchoPartyScreen",
        "flow.realm_select": "RealmSelectScreen",
        "flow.vow_manage": "VowScreen",
        "flow.weaving_rite": "WeavingRiteScreen",
        "flow.stage_map": "StageMapScreen",
        "flow.stage": "StageExploreScreen",
        "flow.stage_explore": "StageExploreScreen",
        "flow.encounter": "CombatBoardScreen",
        "flow.keeper_trial": "CombatBoardScreen",
        "flow.resolve": "ResolveScreen modal",
    }
    if flow in direct:
        return direct[flow]
    for screen in scan["screens"]:
        if flow in screen.get("flows", []):
            return str(screen.get("class", "") or screen.get("file", ""))
    return "-"


def render_html(scan: dict[str, object]) -> str:
    return f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Echoes Player Flow Prototype</title>
  <style>
    :root {{
      --ink: #241b17;
      --muted: #6f6258;
      --panel: #fffaf1;
      --surface: #fffdf8;
      --line: #d8c8ae;
      --field: #f2eadb;
      --leaf: #2d6a4f;
      --clay: #a94f37;
      --gold: #c9922e;
      --danger: #8d3f2f;
      --focus: #385f72;
      --shadow: 0 12px 32px rgba(49, 38, 26, 0.14);
    }}
    * {{ box-sizing: border-box; }}
    body {{
      margin: 0;
      color: var(--ink);
      background: var(--field);
      font: 15px/1.5 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    }}
    header {{
      padding: 34px clamp(20px, 5vw, 64px) 24px;
      background: #38271f;
      color: #fff8e8;
    }}
    header h1 {{ margin: 0; font-size: clamp(34px, 5vw, 62px); letter-spacing: 0; }}
    header p {{ max-width: 920px; color: #e5d6bd; font-size: 17px; }}
    main {{ padding: 24px clamp(16px, 4vw, 56px) 56px; }}
    .toolbar {{
      display: flex;
      gap: 12px;
      flex-wrap: wrap;
      align-items: center;
      margin-bottom: 20px;
    }}
    input[type="search"] {{
      min-width: min(100%, 420px);
      padding: 12px 14px;
      border: 1px solid var(--line);
      border-radius: 8px;
      background: var(--surface);
      color: var(--ink);
      font: inherit;
    }}
    section {{
      margin-top: 20px;
      padding: clamp(16px, 2vw, 24px);
      background: var(--panel);
      border: 1px solid var(--line);
      border-radius: 8px;
      box-shadow: var(--shadow);
      overflow: auto;
    }}
    h2 {{ margin: 0 0 14px; font-size: 23px; }}
    h3 {{ margin: 0 0 8px; font-size: 17px; }}
    .subtle {{ color: var(--muted); max-width: 920px; }}
    .journey-board {{
      display: grid;
      grid-template-columns: repeat(6, minmax(220px, 1fr));
      gap: 12px;
      min-width: 1280px;
    }}
    .flow-stage {{
      min-height: 270px;
      padding: 14px;
      background: var(--surface);
      border: 1px solid var(--line);
      border-radius: 8px;
    }}
    .flow-stage h3 {{ color: var(--leaf); }}
    .screen-node {{
      margin: 10px 0;
      padding: 10px;
      border: 1px solid var(--line);
      border-left: 5px solid var(--gold);
      border-radius: 6px;
      background: #fffaf0;
    }}
    .screen-node strong {{ display: block; }}
    .screen-node small {{ color: var(--muted); }}
    .decision, .risk {{
      margin-top: 10px;
      padding: 8px;
      border-radius: 6px;
    }}
    .decision {{ background: #e7f0e5; color: #244533; font-weight: 700; }}
    .risk {{ background: #f8e8dc; color: var(--danger); }}
    .prototype-grid {{
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(360px, 1fr));
      gap: 18px;
    }}
    .screen-prototype {{
      background: var(--surface);
      border: 1px solid var(--line);
      border-radius: 8px;
      padding: 14px;
    }}
    .screen-meta {{
      display: flex;
      gap: 8px;
      flex-wrap: wrap;
      margin-bottom: 10px;
    }}
    .tag, .pill {{
      display: inline-flex;
      min-height: 24px;
      align-items: center;
      border-radius: 999px;
      padding: 3px 8px;
      background: #ead8b9;
      border: 1px solid #d5bd91;
      font-size: 12px;
    }}
    .mock-screen {{
      min-height: 300px;
      border: 2px solid #2b211b;
      background: #fcf6e8;
      border-radius: 8px;
      padding: 10px;
      display: grid;
      gap: 8px;
      grid-template-rows: auto 1fr auto;
    }}
    .mock-top, .mock-bottom {{
      background: #ead8b9;
      border: 1px solid #d1bc91;
      border-radius: 6px;
      padding: 8px;
    }}
    .mock-body {{
      display: grid;
      grid-template-columns: 1.15fr 0.85fr;
      gap: 8px;
      min-height: 190px;
    }}
    .mock-space, .mock-panel {{
      border: 1px dashed #9d8468;
      border-radius: 6px;
      padding: 10px;
      background: var(--surface);
    }}
    .mock-space {{
      display: grid;
      place-items: center;
      color: var(--muted);
      min-height: 170px;
      text-align: center;
    }}
    .mock-panel ul {{ margin: 8px 0 0; padding-left: 18px; }}
    .feedback-row {{
      display: grid;
      grid-template-columns: repeat(3, 1fr);
      gap: 8px;
      margin-top: 10px;
    }}
    .feedback {{
      border: 1px solid var(--line);
      border-radius: 6px;
      padding: 8px;
      background: #fff9ed;
    }}
    .feel-grid {{
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
      gap: 12px;
    }}
    .feel-card {{
      border: 1px solid var(--line);
      border-radius: 8px;
      padding: 14px;
      background: var(--surface);
    }}
    .feel-card strong {{ display: block; color: var(--leaf); font-size: 18px; }}
    .chip-row {{ display: flex; gap: 8px; flex-wrap: wrap; margin-top: 14px; }}
    .chip {{
      border: 1px solid #d5bd91;
      background: #fff7e6;
      color: var(--ink);
      border-radius: 999px;
      padding: 8px 11px;
      font: inherit;
      text-align: left;
    }}
    .chip span {{ display: block; color: var(--muted); font-size: 11px; }}
    .opportunity-grid {{
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
      gap: 12px;
    }}
    .opportunity {{
      border: 1px solid var(--line);
      border-radius: 8px;
      padding: 14px;
      background: var(--surface);
    }}
    .priority {{
      display: inline-flex;
      min-height: 24px;
      align-items: center;
      padding: 2px 8px;
      border-radius: 999px;
      background: #dce9ec;
      color: var(--focus);
      border: 1px solid #aec7cf;
      font-size: 12px;
      font-weight: 700;
    }}
    .test-grid {{
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
      gap: 12px;
    }}
    .test-card {{
      border: 1px solid var(--line);
      border-radius: 8px;
      padding: 14px;
      background: #fff9ed;
    }}
    .test-card strong {{ display: block; color: var(--clay); }}
    code {{ color: inherit; }}
    .muted {{ color: var(--muted); }}
    pre {{ white-space: pre-wrap; background: #1f1815; color: #fff8e8; padding: 14px; border-radius: 8px; overflow: auto; }}
    @media (max-width: 760px) {{
      .mock-body {{ grid-template-columns: 1fr; }}
      .feedback-row {{ grid-template-columns: 1fr; }}
      .journey-board {{ grid-template-columns: 1fr; min-width: 0; }}
    }}
  </style>
</head>
<body>
  <header>
    <h1>Echoes Player Flow Prototype</h1>
    <p>A UX and game-feel prototype for reading the current game as a player journey: what the Keeper sees, chooses, gets back as feedback, and where the flow needs design attention.</p>
  </header>
  <main>
    <div class="toolbar">
      <input id="filter" type="search" placeholder="Filter prototype screens, feelings, decisions, risks">
      <span class="muted">Prototype generated from current Echoes surfaces.</span>
    </div>

    <section>
      <h2>Player Journey Board</h2>
      <p class="subtle">This is the primary output. Each column is a player-facing state: what the player is trying to understand, what they can do, and what feeling the moment should create.</p>
      <div class="journey-board">
        <article class="flow-stage scan-card" data-search="onboarding invocation keeper anansi first sanctum name">
          <h3>1. Enter The Myth</h3>
          <div class="screen-node"><strong>Invocation / Anansi web</strong><small>AppRoot onboarding screens</small></div>
          <div class="screen-node"><strong>Forgotten name choice</strong><small>Player chooses identity seed</small></div>
          <div class="decision">Decision: continue, confirm name, answer call.</div>
          <div class="risk">Feel check: onboarding must teach stewardship before systems appear.</div>
        </article>
        <article class="flow-stage scan-card" data-search="sanctum home bottomrail echoes party summon vow weaving">
          <h3>2. Read The Sanctum</h3>
          <div class="screen-node"><strong>Sanctum home</strong><small>Home base and care surface</small></div>
          <div class="screen-node"><strong>BottomRail</strong><small>Party, Summon, Realm, Vows, Weaving</small></div>
          <div class="decision">Decision: grow home, inspect Echoes, summon, pledge, or depart.</div>
          <div class="risk">Feel check: player should understand “what needs care now?” at a glance.</div>
        </article>
        <article class="flow-stage scan-card" data-search="realm select stage map prep enter stage party">
          <h3>3. Prepare A Trial</h3>
          <div class="screen-node"><strong>Realm choice</strong><small>Pick which stolen story to enter</small></div>
          <div class="screen-node"><strong>Stage preparation</strong><small>Review progress, party readiness, and entry stakes</small></div>
          <div class="decision">Decision: choose where to risk the party next.</div>
          <div class="risk">Feel check: risk, reward, and party readiness should be visible before entry.</div>
        </article>
        <article class="flow-stage scan-card" data-search="stage explore directive situation contact advance turn">
          <h3>4. Explore The Realm</h3>
          <div class="screen-node"><strong>Realm exploration</strong><small>Board, pressure, directive, and situation choices</small></div>
          <div class="screen-node"><strong>Directive and situation prompts</strong><small>Advance, consult, engage, speak</small></div>
          <div class="decision">Decision: push forward, scout, engage, respond, or return.</div>
          <div class="risk">Feel check: exploration needs anticipation, not just “press next turn.”</div>
        </article>
        <article class="flow-stage scan-card" data-search="encounter combat keeper trial objective retreat round">
          <h3>5. Resolve Pressure</h3>
          <div class="screen-node"><strong>Combat pressure</strong><small>Objective, initiative, positioning, and retreat tension</small></div>
          <div class="screen-node"><strong>Objective + initiative + EchoBar</strong><small>Round actions and retreat</small></div>
          <div class="decision">Decision: commit combat round or retreat.</div>
          <div class="risk">Feel check: combat outcome must feel legible, weighted, and earned.</div>
        </article>
        <article class="flow-stage scan-card" data-search="resolve return sanctum thread reward standing continuity">
          <h3>6. Bring It Home</h3>
          <div class="screen-node"><strong>Resolve moment</strong><small>Outcome, recovery, wounds, rewards, and return choice</small></div>
          <div class="screen-node"><strong>Return to Sanctum</strong><small>Rewards, wounds, Threads, continuity</small></div>
          <div class="decision">Decision: continue, next stage, or return home.</div>
          <div class="risk">Feel check: the player should feel what changed in the Echoes and Sanctum.</div>
        </article>
      </div>
    </section>

    <section>
      <h2>Screen Wireframe Prototypes</h2>
      <p class="subtle">These are intentionally low-fidelity game UX frames: shell chrome, spatial field, decision surface, feedback, and failure state.</p>
      <div class="prototype-grid">
        <article class="screen-prototype scan-card" data-search="sanctum screen shell bottomrail spatial overview">
          <h3>Sanctum Home</h3>
          <div class="screen-meta"><span class="tag">Home base</span><span class="tag">Spatial hub</span><span class="tag">Persistent bottom navigation</span></div>
          <div class="mock-screen">
            <div class="mock-top">Sanctum name · Ase/Ekwan · active vow · continuity signal</div>
            <div class="mock-body">
              <div class="mock-space">Spatial Sanctum field<br>Echo focus / buildings / placement hints</div>
              <div class="mock-panel"><strong>Keeper dashboard</strong><ul><li>Party readiness</li><li>Thread reserve</li><li>Institutions</li><li>Echo detail drawer</li></ul></div>
            </div>
            <div class="mock-bottom">Party · Summon · Realm · Vows · Weaving</div>
          </div>
          <div class="feedback-row"><div class="feedback"><strong>Decision</strong><br>Care for home or depart.</div><div class="feedback"><strong>Feedback</strong><br>Notifications, unlocks, Echo detail.</div><div class="feedback"><strong>Disabled</strong><br>Depart locked until party/stage ready.</div></div>
        </article>
        <article class="screen-prototype scan-card" data-search="realm select screen cards locks choice">
          <h3>Realm Select</h3>
          <div class="screen-meta"><span class="tag">Realm choice</span><span class="tag">Card selection</span><span class="tag">Locked-state clarity</span></div>
          <div class="mock-screen">
            <div class="mock-top">Choose a Realm · locked/unlocked state · party context</div>
            <div class="mock-body">
              <div class="mock-space">Realm card grid<br>story theme · recovery state · lock reason</div>
              <div class="mock-panel"><strong>Selected Realm</strong><ul><li>What story is at stake?</li><li>What could be recovered?</li><li>What danger is implied?</li></ul></div>
            </div>
            <div class="mock-bottom">Back · Select Realm</div>
          </div>
          <div class="feedback-row"><div class="feedback"><strong>Decision</strong><br>Pick the next story to enter.</div><div class="feedback"><strong>Feedback</strong><br>Realm locks and stage preview.</div><div class="feedback"><strong>Disabled</strong><br>Locked realm explains requirement.</div></div>
        </article>
        <article class="screen-prototype scan-card" data-search="stage map prep party enter stage">
          <h3>Stage Map</h3>
          <div class="screen-meta"><span class="tag">Stage prep</span><span class="tag">Party readiness</span><span class="tag">Echo state visible</span></div>
          <div class="mock-screen">
            <div class="mock-top">Realm stage path · current stage · party preview</div>
            <div class="mock-body">
              <div class="mock-space">Stage list / progression track</div>
              <div class="mock-panel"><strong>Stage detail</strong><ul><li>Objective</li><li>Party readiness</li><li>Directive entry point</li><li>Enter stage CTA</li></ul></div>
            </div>
            <div class="mock-bottom">EchoBar: Echo cards · emotional status · HP/readiness</div>
          </div>
          <div class="feedback-row"><div class="feedback"><strong>Decision</strong><br>Commit party to the stage.</div><div class="feedback"><strong>Feedback</strong><br>Prep state and locks.</div><div class="feedback"><strong>Disabled</strong><br>Enter blocked without valid party.</div></div>
        </article>
        <article class="screen-prototype scan-card" data-search="stage explore map directive situation contact">
          <h3>Stage Explore</h3>
          <div class="screen-meta"><span class="tag">Exploration</span><span class="tag">Pressure and discovery</span><span class="tag">Situations and contact</span></div>
          <div class="mock-screen">
            <div class="mock-top">Turn · objective · directive · pressure state</div>
            <div class="mock-body">
              <div class="mock-space">Exploration board<br>party token · fog · revealed markers</div>
              <div class="mock-panel"><strong>Choice panel</strong><ul><li>Advance turn</li><li>Consult Echoes</li><li>Engage situation</li><li>Speak response</li><li>Return home</li></ul></div>
            </div>
            <div class="mock-bottom">EchoBar: party emotional state changes as pressure rises</div>
          </div>
          <div class="feedback-row"><div class="feedback"><strong>Decision</strong><br>Risk progress or preserve the party.</div><div class="feedback"><strong>Feedback</strong><br>Map reveal, situation result, contact response.</div><div class="feedback"><strong>Disabled</strong><br>Unavailable responses should explain why.</div></div>
        </article>
        <article class="screen-prototype scan-card" data-search="combat encounter board objective round retreat">
          <h3>Combat Board</h3>
          <div class="screen-meta"><span class="tag">Combat</span><span class="tag">Objective pressure</span><span class="tag">Round commitment</span></div>
          <div class="mock-screen">
            <div class="mock-top">Objective banner · round · initiative · pressure</div>
            <div class="mock-body">
              <div class="mock-space">Combat grid<br>Echoes · enemies · distance · telegraphs</div>
              <div class="mock-panel"><strong>Action surface</strong><ul><li>Initialize combat</li><li>Confirm round</li><li>Next actor</li><li>Retreat</li></ul></div>
            </div>
            <div class="mock-bottom">EchoBar remains visible as emotional/HP stakes</div>
          </div>
          <div class="feedback-row"><div class="feedback"><strong>Decision</strong><br>Commit to the round.</div><div class="feedback"><strong>Feedback</strong><br>Telegraphs, barks, damage, objective change.</div><div class="feedback"><strong>Disabled</strong><br>Retreat/confirm reasons stay visible.</div></div>
        </article>
        <article class="screen-prototype scan-card" data-search="resolve modal rewards return home thread">
          <h3>Resolve Modal</h3>
          <div class="screen-meta"><span class="tag">Outcome</span><span class="tag">Return decision</span><span class="tag">Persistent consequence</span></div>
          <div class="mock-screen">
            <div class="mock-top">Dimmed Realm screen behind modal</div>
            <div class="mock-body">
              <div class="mock-space">Outcome banner<br>victory, retreat, contact, situation, scout</div>
              <div class="mock-panel"><strong>What changed?</strong><ul><li>Rewards</li><li>Standing/Step</li><li>Thread progress</li><li>Wounds/refusals</li><li>Next stage or home</li></ul></div>
            </div>
            <div class="mock-bottom">Continue · Next Stage · Return Home</div>
          </div>
          <div class="feedback-row"><div class="feedback"><strong>Decision</strong><br>Continue deeper or bring recovery home.</div><div class="feedback"><strong>Feedback</strong><br>Outcome contrast and persistent consequences.</div><div class="feedback"><strong>Disabled</strong><br>Next stage blocked when objective path ends.</div></div>
        </article>
      </div>
    </section>

    <section>
      <h2>Gameplay Feel Audit</h2>
      <div class="feel-grid">
        <div class="feel-card"><strong>Clarity</strong><p>Each screen needs one obvious next player question: care, choose, prepare, explore, fight, or bring home.</p></div>
        <div class="feel-card"><strong>Motivation</strong><p>Every CTA should connect to Echo state, Thread recovery, Sanctum continuity, risk, or reward.</p></div>
        <div class="feel-card"><strong>Response</strong><p>Input should produce visible state change: map reveal, modal result, Echo reaction, bar update, or lock reason.</p></div>
        <div class="feel-card"><strong>Satisfaction</strong><p>Success and failure need contrast. Resolve should show what changed in people and place, not just numbers.</p></div>
        <div class="feel-card"><strong>Fit</strong><p>Player language should feel like stewardship and recovery, not command-console operation.</p></div>
      </div>
    </section>

    <section>
      <h2>UX Improvement Opportunities</h2>
      <p class="subtle">These are design prompts for improving feel and usability. They are intentionally phrased as player-experience questions, not implementation tasks.</p>
      <div class="opportunity-grid">
        <article class="opportunity scan-card" data-search="sanctum clarity home what needs care">
          <span class="priority">High impact</span>
          <h3>Sanctum should answer “what needs care now?”</h3>
          <p>The home screen risks becoming a menu hub unless it clearly surfaces party readiness, emotional state, current vow pressure, Thread reserve, and a next meaningful recommendation.</p>
        </article>
        <article class="opportunity scan-card" data-search="realm prep risk reward readiness">
          <span class="priority">High impact</span>
          <h3>Departure needs a stronger risk read</h3>
          <p>Realm and stage selection should make risk, reward, party readiness, and potential story recovery legible before commitment.</p>
        </article>
        <article class="opportunity scan-card" data-search="exploration anticipation directive situation">
          <span class="priority">Feel risk</span>
          <h3>Exploration needs anticipation between turns</h3>
          <p>Advance-turn actions should create suspense through forecast, pressure, map reveal, Echo reaction, or situational tease.</p>
        </article>
        <article class="opportunity scan-card" data-search="combat response weight feedback">
          <span class="priority">Feel risk</span>
          <h3>Combat must show commitment and consequence</h3>
          <p>Confirming a round should feel like a deliberate commitment, with readable telegraphs before and layered feedback after.</p>
        </article>
        <article class="opportunity scan-card" data-search="resolve consequence rewards echo thread sanctum">
          <span class="priority">High impact</span>
          <h3>Resolve should show what changed emotionally</h3>
          <p>Rewards alone are not enough. The resolve moment should show how Echoes, Threads, and the Sanctum changed because of the player’s choices.</p>
        </article>
        <article class="opportunity scan-card" data-search="language stewardship recovery not command">
          <span class="priority">Tone</span>
          <h3>CTA language should reinforce stewardship</h3>
          <p>Replace operational-feeling copy with language that carries care, recovery, risk, and responsibility where appropriate.</p>
        </article>
      </div>
    </section>

    <section>
      <h2>Playtest Prompts</h2>
      <div class="test-grid">
        <article class="test-card"><strong>New player clarity</strong><p>Ask: “What do you think you should do next, and why?” after each major screen.</p></article>
        <article class="test-card"><strong>Decision weight</strong><p>Ask: “What feels at risk if you press this CTA?” before Realm entry, exploration advance, and combat confirm.</p></article>
        <article class="test-card"><strong>Feedback read</strong><p>After each action, ask: “What changed?” The player should mention a visible state, not infer from memory.</p></article>
        <article class="test-card"><strong>Emotional continuity</strong><p>After resolve, ask: “Who changed, what came home, and what does the Sanctum need now?”</p></article>
      </div>
    </section>
  </main>
  <script>
    const input = document.getElementById('filter');
    input.addEventListener('input', () => {{
      const query = input.value.trim().toLowerCase();
      for (const card of document.querySelectorAll('.scan-card')) {{
        const haystack = card.getAttribute('data-search') || card.textContent.toLowerCase();
        card.style.display = !query || haystack.includes(query) ? '' : 'none';
      }}
      for (const row of document.querySelectorAll('tbody tr')) {{
        row.style.display = !query || row.textContent.toLowerCase().includes(query) ? '' : 'none';
      }}
    }});
  </script>
</body>
</html>
"""


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default=".", help="Repository root")
    parser.add_argument(
        "--html",
        default="docs/visual-plans/echoes-flow-scan.html",
        help="Write a standalone HTML prototype to this path",
    )
    args = parser.parse_args()

    root = Path(args.root).resolve()
    scan = collect_scan(root)
    out_path = Path(args.html).expanduser()
    if not out_path.is_absolute():
        out_path = root / out_path
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(render_html(scan), encoding="utf-8")
    print(f"HTML prototype written: {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
