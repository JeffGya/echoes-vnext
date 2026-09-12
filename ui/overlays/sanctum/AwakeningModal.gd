extends Control
class_name AwakeningModal

signal dismiss_requested()

@onready var dismiss_button: Button = %AwakeningDismiss
@onready var safe_frame: MarginContainer = %SafeFrame

func _ready() -> void:
	dismiss_button.pressed.connect(func() -> void:
		dismiss_requested.emit()
	)

## V2-INFRA-003 Phase 8C: this modal renders for the first time in this slice —
## FlowContext.pending_awakening_banner had never been set true by any production code.
##
## The "+%d Ase" grant line it used to render is GONE, together with its label node. It read
## `payload.awakening_grant`, sourced from `data.economy.awakening_ase_grant` (40), which no
## code has ever paid. The player leaves the keeper intro with the 40 Ase granted by the first
## trial and nothing else. The grant itself belongs to V2-ECONOMY-002; until it exists, the
## modal must not promise it. `awakening_grant` is still carried on the snapshot (removing it
## would move the recorded flow.sanctum data-key set for no gain) and is simply not rendered.
func present(payload: Dictionary) -> void:
	if payload.get("layout", {}) is Dictionary:
		set_layout(payload.get("layout", {}) as Dictionary)

func set_layout(layout: Dictionary) -> void:
	var frame := safe_frame if safe_frame != null else find_child("SafeFrame", true, false) as MarginContainer
	if frame != null and frame.has_method("set_layout"):
		frame.call("set_layout", layout)
