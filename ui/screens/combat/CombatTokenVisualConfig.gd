class_name CombatTokenVisualConfig
extends Resource

@export var token_radius: float = 20.0
@export var structure_half_size: float = 20.0
@export var feet_offset_y: float = 0.0

@export var shadow_color: Color = Color(0.0, 0.0, 0.0, 0.28)
@export var shadow_size: Vector2 = Vector2(32.0, 10.0)
@export var shadow_offset: Vector2 = Vector2(0.0, 18.0)

@export var move_duration: float = 0.18
@export var telegraph_lead_time: float = 0.10
@export var telegraph_half_size: Vector2 = Vector2(64.0, 32.0)
@export var telegraph_fill_color: Color = Color(1.0, 0.9, 0.25, 0.18)
@export var telegraph_outline_color: Color = Color(1.0, 0.92, 0.45, 0.95)
@export var telegraph_outline_width: float = 3.0

@export var active_ring_color: Color = Color(1.0, 0.92, 0.35, 1.0)
@export var active_ring_width: float = 2.5
@export var active_ring_padding: float = 4.0

# V2-STAGE-004 P3c: GUIDE_SPIRIT halo — a soft radiant gold nimbus that marks the
# escorted spirit. Distinct from the PURSUE quarry's solid gold diamond: the spirit
# reads as "watched over / sacred," the quarry as "hunted." Renders over both the
# structure square and the joined echo-faction circle.
@export var spirit_halo_color: Color = Color(1.0, 0.85, 0.35, 0.85)
@export var spirit_halo_inner_color: Color = Color(1.0, 0.92, 0.55, 0.22)
@export var spirit_halo_padding: float = 6.0
@export var spirit_halo_width: float = 2.5

# V2-STAGE-004 Phase 4 (S15 UI-B): joined-ally ring — a single crisp Mist Blue ring
# (no fill, no double-line nimbus) so a temporary combat ally reads distinctly from
# the GUIDE_SPIRIT gold halo (soft filled nimbus) and the PURSUE quarry's solid gold
# diamond badge. Palette: Mist Blue #7AB5C8.
@export var ally_ring_color: Color = Color(0.4784314, 0.70980394, 0.78431373, 0.9)
@export var ally_ring_padding: float = 5.0
@export var ally_ring_width: float = 2.5

@export var hp_bar_offset_y: float = 10.0
@export var hp_bar_height: float = 4.0
@export var hp_bar_background_color: Color = Color(0.15, 0.15, 0.15, 1.0)

# Stop-short: cream stance cue, never red; Mist Blue / Akan Gold badges.
@export var stance_color: Color = Color(1.0, 0.9725, 0.8627, 1.0)
@export var cause_fear_badge_color: Color = Color(0.4784314, 0.70980394, 0.78431373, 1.0)
@export var cause_identity_badge_color: Color = Color(0.83137256, 0.6862745, 0.21568628, 1.0)
@export var stance_edge_color: Color = Color(0.1647, 0.1647, 0.2275, 1.0)
@export var motion_scale: float = 1.0  # stop-short motion time: 1 Normal, 1.6 Slow, 0 Fast (marker and pose still show)
@export var badge_delay: float = 0.10
@export var chip_min_zoom: float = 0.8
@export var settle_diamond_enabled: bool = false
