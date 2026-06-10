#!/usr/bin/env python3
"""
Assembles contact_responses.json from all Phase 1 agent outputs + Phase 3 overrides.

Run from the repo root:
  python3 tools/assemble_contact_responses.py

Writes to: data/conversations/contact_responses.json
"""

import json, re
from pathlib import Path
from copy import deepcopy

SUBDIR = Path("/Users/jeffreygyamfi/.claude/projects/-Users-jeffreygyamfi-Sites-echoes-vnext/2be08294-d3d5-4ebf-9c4f-f17cdef14714/subagents")
REPO_ROOT = Path("/Users/jeffreygyamfi/Sites/echoes-vnext")
LIVE_FILE = REPO_ROOT / "data/conversations/contact_responses.json"
OUTPUT_FILE = REPO_ROOT / "data/conversations/contact_responses.json"

# ─────────────────────────────────────────────────────────────────────────────
# CANONICAL AGENT MAP
# (agent_id, calling_key, tiers_to_take)
# tiers_to_take=None means take everything the agent produced
# ─────────────────────────────────────────────────────────────────────────────
AGENT_MAP = [
    # okomfo
    ("ade7fae1e297fba25", "okomfo", ["radiant", "whole", "grounded"]),   # E1
    ("acaf14c46bac83b1f", "okomfo", ["pressed", "burdened"]),            # E2
    ("a6cf036959bcfd307", "okomfo", ["strained", "fraying", "hollow"]),  # E3-FIX
    # aduro
    ("aa5f4cd91dc3856d6", "aduro",  ["radiant", "whole", "grounded"]),   # E4
    ("adf7111218b6fa0be", "aduro",  ["pressed", "burdened"]),            # E5
    ("ac05f2e4804e2128c", "aduro",  ["strained", "fraying", "hollow"]),  # E6-FIX
    # onyamesu
    ("a2ccfeee6ec17ea05", "onyamesu", ["radiant", "whole", "grounded"]), # E7-FIX
    ("a57e0ad5e193473b9", "onyamesu", ["pressed", "burdened"]),          # E8
    ("ad8b273bf021550ab", "onyamesu", ["strained", "fraying", "hollow"]),# Content agent (better arrays than E9)
    # kra_soro — taken from live file, not agents
    # sum_okwanfo
    ("abd25a4dd14df7b4c", "sum_okwanfo", ["radiant", "whole", "grounded"]),  # E13-FIX
    ("a652e65a4f03abbb1", "sum_okwanfo", ["pressed", "burdened", "strained", "fraying", "hollow"]),  # Content agent (proper arrays + _alignment; replaces E14+E15)
    # okofor
    ("a9fe6d25a6e5d8466", "okofor", ["radiant", "whole", "grounded"]),   # Content agent (proper arrays, replaces E16)
    ("a35bca5cc76e73758", "okofor", ["pressed", "burdened"]),            # E17-FIX
    ("a4b1d3fc4ff9ca3f9", "okofor", ["strained", "fraying", "hollow"]),  # E18 (+ Phase3-A override)
    # uncalled
    ("abb010c0b759bdbfd", "uncalled", ["radiant", "whole", "grounded"]), # E19 (+ Phase3-C override)
    ("a114333ad093cce32", "uncalled", ["pressed", "burdened"]),          # E20
    ("a7c97ca5dc7e7aa9e", "uncalled", ["strained", "fraying", "hollow"]),# Content:uncalled (better format than E21)
    # npc_followup
    ("ab82f459b478ff147", "npc_followup", None),  # N1: witness + guide
    ("aea38e06d2bcc040c", "npc_followup", None),  # N2: charge + claimant
    ("a7eb6354612033cbf", "npc_followup", None),  # N3: temporary_ally (+ Phase3-E fixes)
]

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 3 OVERRIDES
# Applied AFTER agent content is assembled. Slot-keyed patch.
# ─────────────────────────────────────────────────────────────────────────────

# Phase3-A: okofor compassion (all 6 tiers) + strained/wisdom L1
PHASE3_A = {
    "okofor": {
        "radiant": {
            "compassion": [
                "The Okofor says: Not you. Her. Tell me about her.",
                "She says: I have already turned. Say where she is.",
                "She says: Everything else can wait. Where do I go?"
            ],
            "_alignment": {"compassion": [
                "The Okofor says: Not you. Her. I am already moving — say the direction.",
                "She says: Tell me what she needs. I will be there before you finish speaking."
            ]}
        },
        "whole": {
            "compassion": [
                "The Okofor says: Not you. Her. Where is she?",
                "She says: I heard you redirect. I am facing that way now.",
                "She says: Tell me what she needs and I will go."
            ],
            "_alignment": {"compassion": [
                "The Okofor says: Not for you. For her. I am already facing that direction.",
                "She says: Say where. I will close the distance."
            ]}
        },
        "grounded": {
            "compassion": [
                "The Okofor says: Not you. The other one. Tell me where.",
                "She says: I am orienting. Give me something to move toward.",
                "She says: I will get there. Just point me."
            ],
            "_alignment": {"compassion": [
                "The Okofor says: Her. Not you. I am already turning.",
                "She says: Say the direction. I will go."
            ]}
        },
        "strained": {
            "compassion": [
                "The Okofor says: Not you. Her. Where is she?",
                "She says: I am carrying something right now. It does not matter. Where?",
                "She says: I am already moving. Say the direction."
            ],
            # wisdom L1 is a partial override — index 0 only
            "_alignment": {"compassion": [
                "The Okofor says: Not you. Her. I am going — tell me where.",
                "She says: Whatever this is costing me, it does not matter. Say her name."
            ]}
        },
        "fraying": {
            "compassion": [
                "The Okofor says: Her. Tell me where.",
                "She says: I am going.",
                "She says: Say the direction."
            ],
            "_alignment": {"compassion": [
                "The Okofor says: Her. Not you. Where.",
                "She says: I am already moving."
            ]}
        },
        "hollow": {
            "compassion": [
                "The Okofor says: Where.",
                "She says: I am going.",
                "She says: Say it."
            ],
            "_alignment": {"compassion": [
                "The Okofor says: Her. Where.",
                "She says: Going."
            ]}
        }
    }
}
# okofor strained/wisdom L1 separate (partial slot override)
OKOFOR_STRAINED_WISDOM_L1 = "The Okofor says: I heard you. I am still with what you said."

# Phase3-B: onyamesu strained/fraying/hollow compassion
PHASE3_B = {
    "onyamesu": {
        "strained": {
            "compassion": [
                "She says: You are pointing me somewhere else. Who is this person?",
                "She says: Tell me about her. Not what happened — who she is.",
                "She says: What do you know about her? Start there."
            ],
            "_alignment": {"compassion": [
                "She says: We will get to the situation. First — what is she like?",
                "She says: I want to know who we are going toward."
            ]}
        },
        "fraying": {
            "compassion": [
                "She says: Tell me about her.",
                "She says: Who is she?",
                "She says: Not the problem. Her."
            ],
            "_alignment": {"compassion": [
                "She says: We are going to her. What should I know?",
                "She says: Her name. What she is like."
            ]}
        },
        "hollow": {
            "compassion": [
                "She says: Who is she?",
                "She says: Her.",
                "She says: Tell me."
            ],
            "_alignment": {"compassion": [
                "She says: We go together. Who are we going to?",
                "She says: Her name."
            ]}
        }
    }
}

# Phase3-C: uncalled compassion all tiers
PHASE3_C = {
    "uncalled": {
        "radiant": {
            "compassion": [
                "They say: Not you. Someone else. Tell me where.",
                "They say: You are pointing me somewhere. I am already turning. Who is it?",
                "They say: I hear the redirect. Give me a name. Give me a direction. I will move."
            ],
            "_alignment": {"compassion": [
                "They say: You are not asking for yourself. I understand that. Tell me who needs me and I will go to them.",
                "They say: This is not about you. Someone else is waiting. Say where."
            ]}
        },
        "whole": {
            "compassion": [
                "They say: Someone else needs something. I hear it.",
                "They say: You are redirecting me. I am following. Who is it?",
                "They say: Tell me where they are."
            ],
            "_alignment": {"compassion": [
                "They say: Not for you. For someone else. I am not confused by that — say the name.",
                "They say: You pointed. I am already facing that direction. Tell me who."
            ]}
        },
        "grounded": {
            "compassion": [
                "They say: You are pointing somewhere. I am following. Who is it?",
                "They say: You are redirecting me. I hear it. Say who needs the help.",
                "They say: Not you. Someone else. Tell me where."
            ],
            "_alignment": {"compassion": [
                "They say: There is someone else in this. You are telling me to go to them. I will go.",
                "They say: Say who. Say where. I am still here but I am facing the other direction now."
            ]}
        },
        "strained": {
            "compassion": [
                "They say, strained: Someone else. You mean someone else.",
                "They say: Tell me who. Tell me where they are.",
                "They say: I am going. Just — say it plainly."
            ],
            "_alignment": {"compassion": [
                "They say: Not for you. For the other one. I understand. Where.",
                "They say: I am turned. I am ready. Give me something to go toward."
            ]}
        },
        "fraying": {
            "compassion": [
                "They say: Her. You mean her.",
                "They say: Where is she.",
                "They say: I want to go."
            ],
            "_alignment": {"compassion": [
                "They say: Someone else needs this. Not you. Tell me where.",
                "They say: I am going. Say it."
            ]}
        },
        "hollow": {
            "compassion": [
                "They say: Where is she.",
                "They say: Tell me.",
                "They say: I will go."
            ],
            "_alignment": {"compassion": [
                "They say: Not you. The other one. Where.",
                "They say: I am going."
            ]}
        }
    }
}

# Phase3-D: sum_okwanfo strained/fraying/hollow compassion (with POV fix applied)
PHASE3_D = {
    "sum_okwanfo": {
        "strained": {
            "compassion": [
                "She says: You said not for you. I read that. Where is the one you are pointing toward?",
                "She says: I can still move in the direction you gave me. That part is intact.",
                "She says: Tell me what they need. Not you — them. I will go."
            ],
            "_alignment": {"compassion": [
                "She says: The redirect landed. I am already orienting.",
                "She says: I heard the direction. Tell me where they are."
            ]}
        },
        "fraying": {
            "compassion": [
                "She says: I read where you pointed. I am going.",
                "She says: Not you. Them. Noted.",
                "She says: Where?"
            ],
            "_alignment": {"compassion": [
                "She says: I caught the redirect. I am moving.",
                "She says: Point me at them."
            ]}
        },
        "hollow": {
            "compassion": [
                "She says: There. That is where.",
                "She says: Tell me.",
                "She says: I go."
            ],
            "_alignment": {"compassion": [
                "She says: The direction. Give me the direction.",
                "She says: Them. I heard you."
            ]}
        }
    }
}

# Phase3-E: Temp Ally npc_followup 3-line fixes
PHASE3_E_STEADIED_0 = "You did not say what I expected. That tells me something. A little further."
PHASE3_E_WITHDRAWN_0 = "That confirmed what I was afraid of. I am still here, but I am done opening up."
PHASE3_E_WITHDRAWN_2 = "You are asking more than I came here to give. I am still here. But I am not going further."

# ─────────────────────────────────────────────────────────────────────────────
# EXTRACTION LOGIC
# ─────────────────────────────────────────────────────────────────────────────

def find_json_in_text(txt):
    """Try multiple strategies to find valid JSON in agent output text."""
    # Strategy 1: ```json ... ``` code block
    match = re.search(r'```json\s*([\s\S]+?)```', txt)
    if match:
        try:
            return json.loads(match.group(1).strip())
        except json.JSONDecodeError:
            pass

    # Strategy 2: Last { ... } block that parses as valid JSON
    # Find all potential JSON object starts
    starts = [m.start() for m in re.finditer(r'\{', txt)]
    for start in reversed(starts):
        # Scan forward counting braces
        depth = 0
        for i in range(start, len(txt)):
            c = txt[i]
            if c == '{':
                depth += 1
            elif c == '}':
                depth -= 1
                if depth == 0:
                    candidate = txt[start:i+1]
                    try:
                        result = json.loads(candidate)
                        # Only accept if it has calling/npc_followup keys
                        known_keys = {'okomfo','aduro','onyamesu','kra_soro','sum_okwanfo',
                                      'okofor','uncalled','npc_followup'}
                        if any(k in result for k in known_keys):
                            return result
                    except json.JSONDecodeError:
                        break
    return None


def extract_json_from_agent(agent_id):
    """Extract JSON content from the final assistant message of an agent JSONL."""
    jsonl_path = SUBDIR / f"agent-{agent_id}.jsonl"
    if not jsonl_path.exists():
        print(f"  WARNING: {jsonl_path} not found")
        return None

    with open(jsonl_path) as f:
        lines = f.readlines()

    # Walk backward looking for the last assistant message with text content
    for line in reversed(lines):
        try:
            data = json.loads(line.strip())
        except json.JSONDecodeError:
            continue
        if data.get('message', {}).get('role') != 'assistant':
            continue
        content = data['message']['content']
        if isinstance(content, list):
            for b in content:
                if isinstance(b, dict) and b.get('type') == 'text':
                    result = find_json_in_text(b['text'])
                    if result:
                        return result
        elif isinstance(content, str):
            result = find_json_in_text(content)
            if result:
                return result
    return None


# ─────────────────────────────────────────────────────────────────────────────
# DEEP MERGE HELPER
# ─────────────────────────────────────────────────────────────────────────────

def deep_merge(base, override):
    """Recursively merge override into base. Lists replace (not extend)."""
    result = deepcopy(base)
    for key, val in override.items():
        if key in result and isinstance(result[key], dict) and isinstance(val, dict):
            result[key] = deep_merge(result[key], val)
        else:
            result[key] = deepcopy(val)
    return result


# ─────────────────────────────────────────────────────────────────────────────
# MAIN ASSEMBLY
# ─────────────────────────────────────────────────────────────────────────────

def main():
    print("Reading live file for kra_soro + calling_recognition + existing npc_followup structure...")
    with open(LIVE_FILE) as f:
        live = json.load(f)

    assembled = {}

    # Preserve kra_soro from live file (confirmed correct by R3)
    if "kra_soro" in live:
        assembled["kra_soro"] = live["kra_soro"]
        print("  kra_soro: taken from live file (confirmed correct)")
    else:
        print("  WARNING: kra_soro not found in live file")

    # Process all agent-sourced content
    print("\nExtracting agent content...")
    for agent_id, calling_key, tiers_to_take in AGENT_MAP:
        desc = f"{calling_key} / {tiers_to_take or 'all'}"
        data = extract_json_from_agent(agent_id)
        if data is None:
            print(f"  FAILED to extract: {agent_id} ({desc})")
            continue

        if calling_key not in data:
            print(f"  WARNING: {agent_id} ({desc}) — key '{calling_key}' not in output, got: {list(data.keys())}")
            continue

        calling_data = data[calling_key]

        # Filter to requested tiers only
        if tiers_to_take is not None:
            calling_data = {t: v for t, v in calling_data.items() if t in tiers_to_take}
            missing = [t for t in tiers_to_take if t not in calling_data]
            if missing:
                print(f"  WARNING: {agent_id} ({desc}) — missing tiers: {missing}")

        # Merge into assembled
        if calling_key not in assembled:
            assembled[calling_key] = {}

        assembled[calling_key] = deep_merge(assembled[calling_key], calling_data)
        print(f"  OK: {agent_id[:8]}... → {calling_key} / {list(calling_data.keys())}")

    # ── Apply Phase 3 overrides ──────────────────────────────────────────────
    print("\nApplying Phase 3 overrides...")

    # Phase3-A: okofor compassion (all 6 tiers) + strained wisdom L1
    for tier, override_data in PHASE3_A["okofor"].items():
        if "okofor" not in assembled:
            assembled["okofor"] = {}
        if tier not in assembled["okofor"]:
            assembled["okofor"][tier] = {}
        # Override compassion slot
        if "compassion" in override_data:
            assembled["okofor"][tier]["compassion"] = override_data["compassion"]
        # Override _alignment.compassion
        if "_alignment" in override_data:
            if "_alignment" not in assembled["okofor"][tier]:
                assembled["okofor"][tier]["_alignment"] = {}
            if "compassion" in override_data["_alignment"]:
                assembled["okofor"][tier]["_alignment"]["compassion"] = override_data["_alignment"]["compassion"]
    # okofor strained wisdom L1 fix
    if "strained" in assembled.get("okofor", {}):
        wisdom_lines = assembled["okofor"]["strained"].get("wisdom", [])
        if isinstance(wisdom_lines, list) and len(wisdom_lines) > 0:
            assembled["okofor"]["strained"]["wisdom"][0] = OKOFOR_STRAINED_WISDOM_L1
        elif isinstance(wisdom_lines, str):
            # Single string — wrap in array with fix + duplicate
            assembled["okofor"]["strained"]["wisdom"] = [OKOFOR_STRAINED_WISDOM_L1, wisdom_lines, wisdom_lines]
    print("  Phase3-A applied: okofor compassion (6 tiers) + strained/wisdom L1")

    # Phase3-B: onyamesu strained/fraying/hollow compassion
    for tier, override_data in PHASE3_B["onyamesu"].items():
        if "onyamesu" not in assembled:
            assembled["onyamesu"] = {}
        if tier not in assembled["onyamesu"]:
            assembled["onyamesu"][tier] = {}
        if "compassion" in override_data:
            assembled["onyamesu"][tier]["compassion"] = override_data["compassion"]
        if "_alignment" in override_data:
            if "_alignment" not in assembled["onyamesu"][tier]:
                assembled["onyamesu"][tier]["_alignment"] = {}
            if "compassion" in override_data["_alignment"]:
                assembled["onyamesu"][tier]["_alignment"]["compassion"] = override_data["_alignment"]["compassion"]
    print("  Phase3-B applied: onyamesu strained/fraying/hollow compassion")

    # Phase3-C: uncalled compassion (all 6 tiers)
    for tier, override_data in PHASE3_C["uncalled"].items():
        if "uncalled" not in assembled:
            assembled["uncalled"] = {}
        if tier not in assembled["uncalled"]:
            assembled["uncalled"][tier] = {}
        if "compassion" in override_data:
            assembled["uncalled"][tier]["compassion"] = override_data["compassion"]
        if "_alignment" in override_data:
            if "_alignment" not in assembled["uncalled"][tier]:
                assembled["uncalled"][tier]["_alignment"] = {}
            if "compassion" in override_data["_alignment"]:
                assembled["uncalled"][tier]["_alignment"]["compassion"] = override_data["_alignment"]["compassion"]
    print("  Phase3-C applied: uncalled compassion (6 tiers)")

    # Phase3-D: sum_okwanfo strained/fraying/hollow compassion
    for tier, override_data in PHASE3_D["sum_okwanfo"].items():
        if "sum_okwanfo" not in assembled:
            assembled["sum_okwanfo"] = {}
        if tier not in assembled["sum_okwanfo"]:
            assembled["sum_okwanfo"][tier] = {}
        if "compassion" in override_data:
            assembled["sum_okwanfo"][tier]["compassion"] = override_data["compassion"]
        if "_alignment" in override_data:
            if "_alignment" not in assembled["sum_okwanfo"][tier]:
                assembled["sum_okwanfo"][tier]["_alignment"] = {}
            if "compassion" in override_data["_alignment"]:
                assembled["sum_okwanfo"][tier]["_alignment"]["compassion"] = override_data["_alignment"]["compassion"]
    print("  Phase3-D applied: sum_okwanfo strained/fraying/hollow compassion")

    # Phase3-E: Temp Ally npc_followup fixes
    if "npc_followup" in assembled and "temporary_ally" in assembled["npc_followup"]:
        ta = assembled["npc_followup"]["temporary_ally"]
        if "steadied" in ta and isinstance(ta["steadied"], list) and len(ta["steadied"]) > 0:
            ta["steadied"][0] = PHASE3_E_STEADIED_0
        if "withdrawn" in ta and isinstance(ta["withdrawn"], list):
            if len(ta["withdrawn"]) > 0:
                ta["withdrawn"][0] = PHASE3_E_WITHDRAWN_0
            if len(ta["withdrawn"]) > 2:
                ta["withdrawn"][2] = PHASE3_E_WITHDRAWN_2
        print("  Phase3-E applied: temp_ally steadied[0] + withdrawn[0]/[2]")
    else:
        print("  WARNING: npc_followup.temporary_ally not found for Phase3-E")

    # ── Preserve calling_recognition from live file ──────────────────────────
    if "npc_followup" in assembled and "calling_recognition" not in assembled.get("npc_followup", {}):
        if "npc_followup" in live and "calling_recognition" in live["npc_followup"]:
            assembled["npc_followup"]["calling_recognition"] = live["npc_followup"]["calling_recognition"]
            print("\n  Preserved calling_recognition from live file")

    # ── Validation ───────────────────────────────────────────────────────────
    print("\nValidation:")
    EXPECTED_CALLINGS = ["okomfo", "aduro", "onyamesu", "kra_soro", "sum_okwanfo", "okofor", "uncalled"]
    EXPECTED_TIERS = ["radiant", "whole", "grounded", "pressed", "burdened", "strained", "fraying", "hollow"]
    EXPECTED_VIRTUES = ["courage", "wisdom", "leadership", "acceptance", "humility", "forgiveness",
                        "compassion", "empathy", "truth", "generosity"]

    all_ok = True
    for calling in EXPECTED_CALLINGS:
        if calling not in assembled:
            print(f"  MISSING calling: {calling}")
            all_ok = False
            continue
        for tier in EXPECTED_TIERS:
            if tier not in assembled[calling]:
                print(f"  MISSING tier: {calling}/{tier}")
                all_ok = False
                continue
            tier_data = assembled[calling][tier]
            for virtue in EXPECTED_VIRTUES:
                if virtue not in tier_data:
                    print(f"  MISSING virtue: {calling}/{tier}/{virtue}")
                    all_ok = False
                elif not isinstance(tier_data[virtue], list):
                    print(f"  NOT ARRAY: {calling}/{tier}/{virtue} = {type(tier_data[virtue])}: {tier_data[virtue]!r:.80s}")
                    all_ok = False
                elif len(tier_data[virtue]) != 3:
                    print(f"  WRONG COUNT: {calling}/{tier}/{virtue} = {len(tier_data[virtue])} lines (expected 3)")
            # Check _reactive
            if "_reactive" not in tier_data:
                print(f"  MISSING _reactive: {calling}/{tier}")
                all_ok = False
            elif not isinstance(tier_data["_reactive"], list) or len(tier_data["_reactive"]) != 3:
                print(f"  BAD _reactive: {calling}/{tier}")
                all_ok = False
            # Check _npc_withdrawn
            if "_npc_withdrawn" not in tier_data:
                print(f"  MISSING _npc_withdrawn: {calling}/{tier}")
                all_ok = False
            # Check _alignment
            if "_alignment" not in tier_data:
                print(f"  MISSING _alignment: {calling}/{tier}")
                all_ok = False

    if all_ok:
        print("  All callings/tiers/virtues present and correctly formatted.")
    else:
        print("\n  Some issues found above — review before shipping.")

    # Check npc_followup structure
    if "npc_followup" not in assembled:
        print("  MISSING npc_followup section")
        all_ok = False

    # ── Write output ─────────────────────────────────────────────────────────
    print(f"\nWriting to {OUTPUT_FILE}...")
    with open(OUTPUT_FILE, 'w') as f:
        json.dump(assembled, f, indent=2, ensure_ascii=False)
    print(f"Done. File size: {OUTPUT_FILE.stat().st_size:,} bytes")

    # Summary stats
    echo_callings = [c for c in assembled if c != "npc_followup"]
    print(f"\nSummary: {len(echo_callings)} callings × {len(EXPECTED_TIERS)} tiers assembled")
    if "npc_followup" in assembled:
        roles = [k for k in assembled["npc_followup"] if k != "calling_recognition"]
        print(f"  npc_followup: {roles}")


if __name__ == "__main__":
    main()
