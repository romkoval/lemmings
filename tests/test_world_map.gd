extends "res://addons/gut/test.gd"

# US-2.6: the campaign world map. Levels are an ordered journey across biome
# zones; nodes unlock in sequence and a frontier marker tracks progress. The
# layout/progress logic is data-driven and testable without rendering.

const CAMPAIGN_TOTAL: int = 17   # fun 6 + tricky 10 + taxing 1


func before_each() -> void:
	SaveManager.completed_levels.clear()
	SaveManager.level_results.clear()


func after_all() -> void:
	SaveManager.completed_levels.clear()
	SaveManager.level_results.clear()
	SaveManager.save_progress()


func _map() -> WorldMap:
	var m: WorldMap = (load("res://scenes/menu/world_map.tscn") as PackedScene).instantiate() as WorldMap
	add_child_autoqfree(m)
	return m


func test_campaign_order_spans_every_rank_in_sequence() -> void:
	var order: Array = LevelManager.campaign_order()
	assert_eq(order.size(), CAMPAIGN_TOTAL, "every campaign level is in the journey")
	assert_eq(str(order[0]["category"]), "fun", "journey starts in the grass")
	assert_eq(int(order[0]["number"]), 1)
	assert_eq(str(order[0]["biome"]), "grass")
	assert_eq(str(order[6]["category"]), "tricky", "then the dungeon")
	assert_eq(str(order[6]["biome"]), "dungeon")
	assert_eq(str(order.back()["category"]), "taxing", "ending in the inferno")
	assert_eq(str(order.back()["biome"]), "inferno")


func test_nodes_unlock_one_at_a_time_along_the_trail() -> void:
	var m := _map()
	await wait_physics_frames(1)
	assert_eq(m.nodes.size(), CAMPAIGN_TOTAL)
	assert_true(m.nodes[0]["unlocked"], "the first node is always open")
	assert_false(m.nodes[0]["complete"])
	assert_false(m.nodes[1]["unlocked"], "the second is locked until the first is cleared")
	assert_eq(m.frontier_index(), 0, "frontier sits on the first node")

	# Clear the first level → the next opens and the frontier advances.
	SaveManager.mark_level_complete("fun_01")
	m.rebuild()
	assert_true(m.nodes[0]["complete"], "first cleared")
	assert_true(m.nodes[1]["unlocked"], "second unlocked")
	assert_false(m.nodes[2]["unlocked"], "but only the very next one")
	assert_eq(m.frontier_index(), 1, "frontier stepped forward")


func test_frontier_is_last_node_when_all_cleared() -> void:
	for e in LevelManager.campaign_order():
		SaveManager.mark_level_complete(str(e["id"]))
	var m := _map()
	await wait_physics_frames(1)
	assert_eq(m.frontier_index(), CAMPAIGN_TOTAL - 1, "frontier rests at the end")
	for n in m.nodes:
		assert_true(n["unlocked"] and n["complete"], "everything open and done")


func test_node_hit_testing_picks_the_disc_under_a_point() -> void:
	var m := _map()
	await wait_physics_frames(1)
	var target: Dictionary = m.nodes[3]
	var hit: Dictionary = m.node_at_content(target["pos"])
	assert_false(hit.is_empty(), "a point on a node hits it")
	assert_eq(int(hit["index"]), 3)
	# A point far from every node hits nothing.
	assert_true(m.node_at_content(Vector2(-500, -500)).is_empty(), "empty space hits nothing")


func test_biome_zones_are_contiguous_blocks() -> void:
	# The journey never flips back to an earlier biome — zones are solid blocks,
	# which is what lets the map draw one band per biome.
	var m := _map()
	await wait_physics_frames(1)
	var seen: Array = []
	var prev: String = ""
	for n in m.nodes:
		if str(n["biome"]) != prev:
			assert_false(seen.has(n["biome"]), "biome %s is one contiguous zone" % n["biome"])
			seen.append(n["biome"])
			prev = str(n["biome"])


func test_content_taller_than_one_screen_so_it_scrolls() -> void:
	var m := _map()
	await wait_physics_frames(1)
	assert_gt(m.content_height, m.size.y, "a 17-stop trail is taller than the viewport")
