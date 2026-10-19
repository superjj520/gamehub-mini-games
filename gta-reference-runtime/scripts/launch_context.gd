extends Node

var pending_scene_path := ""
var pending_load_checkpoint := false
var pending_checkpoint_path := ""
var pending_asset_catalog_path := ""
var pending_content_pack_id := ""

func request_scene(scene_path: String, load_checkpoint: bool, checkpoint_path := "", asset_catalog_path := "", content_pack_id := "") -> void:
	pending_scene_path = scene_path
	pending_load_checkpoint = load_checkpoint
	pending_checkpoint_path = checkpoint_path
	pending_asset_catalog_path = asset_catalog_path
	pending_content_pack_id = content_pack_id

func consume_request(scene_path: String) -> Dictionary:
	if pending_scene_path != scene_path:
		return {}
	var request := {
		"load_checkpoint": pending_load_checkpoint,
		"checkpoint_path": pending_checkpoint_path,
		"asset_catalog_path": pending_asset_catalog_path,
		"content_pack_id": pending_content_pack_id,
	}
	clear()
	return request

func consume_checkpoint(scene_path: String) -> bool:
	return bool(consume_request(scene_path).get("load_checkpoint", false))

func clear() -> void:
	pending_scene_path = ""
	pending_load_checkpoint = false
	pending_checkpoint_path = ""
	pending_asset_catalog_path = ""
	pending_content_pack_id = ""
