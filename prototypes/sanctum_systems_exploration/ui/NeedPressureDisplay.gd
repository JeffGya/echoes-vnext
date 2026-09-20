extends VBoxContainer

const FAMILIES: Array[String] = ["rest", "company", "purpose"]
const QUIET := Color("40584d")
const ACTIVE := Color("e8c47b")

func set_model(model: Dictionary) -> void:
	var needs: Dictionary = model.get("needs", {})
	for family: String in FAMILIES:
		var row: HBoxContainer = get_node("%sRow" % family.capitalize())
		var need: Dictionary = needs.get(family, {})
		row.get_node("Name").text = str(need.get("name", family.capitalize()))
		row.get_node("State").text = str(need.get("state", "Settled"))
		var level: int = clampi(int(need.get("level", 0)), 0, 5)
		for index: int in range(5):
			row.get_node("Segments/Segment%d" % index).color = ACTIVE if index < level else QUIET
