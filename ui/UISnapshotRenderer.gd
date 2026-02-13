extends Node

class_name UISnapshotRenderer

# Renderer is responsible only for taking snapshots and updating UI.
# It must not know anything about game logic systems.

var snapshot_view: RichTextLabel

func bind_view(view:RichTextLabel) -> void:
	# AppRoot provides the UI nodes this renderer can write to.
	snapshot_view = view
	
func render(snapshot: Dictionary) -> void:
	if snapshot_view == null:
		push_warning("UISnapShotRenderer has no bound SnapshotView.")
		return
	var json_string := JSON.stringify(snapshot, "\t")
	snapshot_view.text = json_string
