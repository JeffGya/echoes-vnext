extends RefCounted
class_name SanctumNameService

static func suggest(seed: CampaignSeed, roll_index: int) -> String:
	var objects := SanctumNameList.OBJECTS
	var places := SanctumNameList.PLACES
	if objects.is_empty() or places.is_empty():
		return "Sanctum"

	var obj_path := "sanctum.name.object.%d" % roll_index
	var place_path := "sanctum.name.place.%d" % roll_index

	var obj_s := int(seed.derive(obj_path))
	var place_s := int(seed.derive(place_path))

	var obj_idx := int(obj_s % objects.size())
	var place_idx := int(place_s % places.size())

	return "%s %s" % [objects[obj_idx], places[place_idx]]
