#!/usr/bin/env zsh
set -euo pipefail

project_dir="gta-reference-runtime"
log_file="/tmp/godot-reference-runtime.log"
godot_bin="${GODOT_BIN:-godot}"
settings_dir="$(mktemp -d /tmp/godot-reference-settings.XXXXXX)"
export REFERENCE_SETTINGS_PATH="$settings_dir/reference_settings.json"
trap 'rm -rf "$settings_dir"' EXIT

node scripts/verify_rights_manifest.mjs
node scripts/verify_reference_media.mjs
node scripts/verify_product_baseline.mjs
node scripts/verify_release_scope.mjs
node scripts/create_runtime_launch_profile.mjs
node scripts/verify_runtime_launch_profile.mjs
node scripts/verify_privacy_data_boundary.mjs
node scripts/verify_reference_acceptance.mjs
node scripts/verify_runtime_captures.mjs
node scripts/create_trace_gap_report.mjs
if [[ "${REFERENCE_RUNTIME_SKIP_VISUAL_MATRIX:-0}" == "1" ]]; then
	print "功能全量回归模式：保留视觉状态为 unverified，跳过当前源视觉矩阵绑定门禁"
else
	npm run verify:visual-matrix
fi
node scripts/verify_release_tree.mjs
node scripts/create_release_manifest.mjs
node scripts/verify_release_manifest.mjs
node scripts/create_internal_candidate.mjs --output build/internal-candidate --verify-reproducible
node scripts/verify_internal_candidate.mjs
node scripts/create_readiness_report.mjs
node scripts/verify_readiness_report.mjs
node scripts/verify_evidence_binding.mjs
node scripts/verify_candidate_visual_freshness.mjs
node scripts/verify_asset_production_manifest.mjs
node scripts/verify_asset_delivery_gate.mjs
node scripts/verify_session_crash_recovery.mjs
fingerprint_before="$(node scripts/source_fingerprint.mjs)"
fingerprint_after="$(node scripts/source_fingerprint.mjs)"
if [[ "$fingerprint_before" != "$fingerprint_after" ]]; then
	print -u2 "工程源文件指纹不稳定：验证期间发生未声明变化"
	exit 1
fi
print "工程源文件指纹稳定：$fingerprint_before"
run_godot_test() {
	local test_name="$1"
	shift
	local output_file="/tmp/godot-reference-${test_name}.out"
	local test_settings_dir="$settings_dir/$test_name"
	mkdir -p "$test_settings_dir"
	: > "$output_file"
	: > "$log_file"
	if ! REFERENCE_SETTINGS_PATH="$test_settings_dir/reference_settings.json" "$@" > "$output_file" 2>&1; then
		cat "$output_file"
		print -u2 "Godot 测试进程失败：$test_name"
		return 1
	fi
	cat "$output_file"
	if rg -n "SCRIPT ERROR|Parse Error|Failed to load script|Invalid type|Invalid access|Assertion failed|Cannot infer the type|ObjectDB instances were leaked|Leaked instance:|Orphan StringName" "$output_file" "$log_file" >/dev/null 2>&1; then
		print -u2 "Godot 测试出现脚本或断言错误：$test_name"
		return 1
	fi
}

run_godot_test "launcher" "$godot_bin" --headless --path "$project_dir" --log-file "$log_file" -s res://tests/launcher_integration_test.gd
run_godot_test "launcher-candidate-preview" "$godot_bin" --headless --path "$project_dir" --log-file "$log_file" -s res://tests/launcher_candidate_preview_test.gd
run_godot_test "launcher-session" "$godot_bin" --headless --path "$project_dir" --log-file "$log_file" -s res://tests/launcher_session_integration_test.gd
run_godot_test "launcher-checkpoint" "$godot_bin" --headless --path "$project_dir" --log-file "$log_file" -s res://tests/launcher_checkpoint_integration_test.gd
run_godot_test "launcher-new-game" "$godot_bin" --headless --path "$project_dir" --log-file "$log_file" -s res://tests/launcher_new_game_integration_test.gd
run_godot_test "launcher-settings" "$godot_bin" --headless --path "$project_dir" --log-file "$log_file" -s res://tests/launcher_settings_integration_test.gd
run_godot_test "session-journal" "$godot_bin" --headless --path "$project_dir" --log-file "$log_file" -s res://tests/session_journal_test.gd
run_godot_test "input-actions" "$godot_bin" --headless --path "$project_dir" --log-file "$log_file" -s res://tests/input_actions_integration_test.gd
run_godot_test "smoke" "$godot_bin" --headless --path "$project_dir" --log-file "$log_file" -s res://tests/smoke_test.gd
run_godot_test "audio-original-only" "$godot_bin" --headless --path "$project_dir" --log-file "$log_file" -s res://tests/audio_original_only_integration_test.gd
run_godot_test "content-pack-manifest" "$godot_bin" --headless --path "$project_dir" --log-file "$log_file" -s res://tests/content_pack_manifest_integration_test.gd
run_godot_test "asset-runtime" "$godot_bin" --headless --path "$project_dir" --log-file "$log_file" -s res://tests/asset_runtime_integration_test.gd
run_godot_test "asset-profile-preview" "$godot_bin" --headless --path "$project_dir" --log-file "$log_file" -s res://tests/asset_profile_preview_test.gd
run_godot_test "original-character-candidate" "$godot_bin" --headless --path "$project_dir" --log-file "$log_file" -s res://tests/original_character_candidate_test.gd
run_godot_test "asset-import" "$godot_bin" --headless --path "$project_dir" --log-file "$log_file" -s res://tests/asset_import_validation_test.gd
run_godot_test "player-outfitted-asset" "$godot_bin" --headless --path "$project_dir" --log-file "$log_file" -s res://tests/inspect_outfitted_asset.gd
run_godot_test "npc-outfitted-asset" "$godot_bin" --headless --path "$project_dir" --log-file "$log_file" -s res://tests/inspect_npc_outfitted_asset.gd
run_godot_test "three-wheel-asset" "$godot_bin" --headless --path "$project_dir" --log-file "$log_file" -s res://tests/inspect_three_wheel_asset.gd
run_godot_test "original-only-catalog-vehicle" "$godot_bin" --headless --path "$project_dir" --log-file "$log_file" -s res://tests/original_only_catalog_vehicle_test.gd
run_godot_test "presentation-animation" "$godot_bin" --headless --path "$project_dir" --log-file "$log_file" -s res://tests/presentation_animation_test.gd
run_godot_test "office" "$godot_bin" --headless --path "$project_dir" --log-file "$log_file" -s res://tests/office_integration_test.gd
run_godot_test "camera-volume-collision" "$godot_bin" --headless --path "$project_dir" --log-file "$log_file" -s res://tests/camera_volume_collision_test.gd
run_godot_test "hud-layout" "$godot_bin" --headless --path "$project_dir" --log-file "$log_file" -s res://tests/hud_layout_integration_test.gd
run_godot_test "pause" "$godot_bin" --headless --path "$project_dir" --log-file "$log_file" -s res://tests/pause_integration_test.gd
run_godot_test "runtime-capture" "$godot_bin" --headless --path "$project_dir" --log-file "$log_file" -s res://tests/runtime_capture_integration_test.gd
run_godot_test "offscreen-subviewport-probe" "$godot_bin" --headless --path "$project_dir" --log-file "$log_file" -s res://tests/offscreen_subviewport_capture_test.gd
run_godot_test "scene-lifecycle" "$godot_bin" --headless --path "$project_dir" --log-file "$log_file" -s res://tests/scene_lifecycle_smoke_test.gd
run_godot_test "city" "$godot_bin" --headless --path "$project_dir" --log-file "$log_file" -s res://tests/city_integration_test.gd
run_godot_test "city-extension" "$godot_bin" --headless --path "$project_dir" --log-file "$log_file" -s res://tests/city_extension_integration_test.gd
run_godot_test "city-conflict" "$godot_bin" --headless --path "$project_dir" --log-file "$log_file" -s res://tests/city_conflict_integration_test.gd
run_godot_test "city-side-activity" "$godot_bin" --headless --path "$project_dir" --log-file "$log_file" -s res://tests/city_side_activity_integration_test.gd
run_godot_test "city-market-delivery" "$godot_bin" --headless --path "$project_dir" --log-file "$log_file" -s res://tests/city_market_delivery_integration_test.gd
run_godot_test "determinism" "$godot_bin" --headless --path "$project_dir" --log-file "$log_file" -s res://tests/determinism_integration_test.gd
run_godot_test "performance" "$godot_bin" --headless --path "$project_dir" --log-file "$log_file" -s res://tests/runtime_performance_smoke_test.gd

print "参考还原基准全量验证通过"
