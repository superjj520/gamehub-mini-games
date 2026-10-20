# P0 办公室 NPC 候选审阅记录

日期：2026-10-07  
候选：`office-npc-quaternius-cc0-candidate`  
源指纹：`8f260597a1c8c3a65514bb9979f68c7191bbe0bf46312aabdd17a1154a2811b2`

## 已验证

- 与主角候选共用已登记的 Quaternius CC0 基础网格和许可证副本。
- 角色实例按局部 `-Z` 前进方向旋转，65 根骨骼可被 Godot 导入。
- 已导出独立制服 GLB，包含原创制服、胸牌、袖子、裤腿、鞋子和头发；它不包含主角背包，并保留 `idle_default`、`walk_default`、`search_default`、`alert_default` 状态桥接。
- `inspect_npc_outfitted_asset.gd` 已验证独立 GLB 的骨架、必需骨骼、13 个制服对象和无 `Outfit_Backpack`。
- 办公室上司和走廊巡查两个挂载点均能通过现有资产覆盖目录加载，原有感知、失败、巡查和灰盒回退测试通过。
- `p0-candidate-office-06.png` 已由真实图形运行时重新生成。

## 未通过或待补

- 侧面近景显示制服仍偏低面数候选，体型、袖口、裤腿、胸牌和材质需要进一步建模与返工。
- 当前已完成独立 GLB 导入与静态骨骼结构验收，尚未完成动态巡逻、搜索、警觉和受击过程中的穿插与变形验收。
- 尚未完成视线起点、搜索目标点、警觉标记点随骨骼移动的联合验收。
- 尚未完成远近 LOD、人群密度、目标 Windows 设备性能和人工视觉签收。

## 结论

`integration_status=verified_in_isolated_asset_override_test`、`visual_status=unverified`、`release_allowed=false`。候选只用于 NPC 感知与镜头调校，不进入正式资产目录。

## 新增离线人物候选：MakeHuman/MPFB2

- 候选文件：`art-source/characters/makehuman-office-worker/makehuman_office_worker_candidate.glb`。
- 当前结果：已由 Blender 离线生成，GLB 结构校验通过，源文件哈希为 `85f649bb5200aa763cbdab152b7a528ea6b83aaa71bf44096d3a21c4aa7f26a6`。
- 权利状态：MakeHuman 核心/系统资产按 CC0 记录；MPFB2 仅作为制作工具，源码授权单独登记，不进入游戏包。
- 接入状态：未接入正式运行时。原始候选和清洗候选都可以通过 Godot 编辑器导入；在隔离复制工程中使用 Godot OpenGL Compatibility 后端已完成原始材质挂载和图形渲染，候选仍保留在正式运行时之外，尚未完成默认渲染后端与 Windows 目标设备复核。
- 临时接入证据：在独立复制工程中，原始材质候选已实际挂载到办公室 NPC 槽位并生成 `reference-evidence/candidate-makehuman-office-01.png`、`reference-evidence/candidate-makehuman-office-06.png`；这两张图只证明挂载和渲染成功，不代表视觉通过。
- 动画状态：在隔离复制工程中为候选实例挂载 `AnimationPlayer`，并通过共享 `AssetRuntimeCatalog.drive_animation_state()` 逐一驱动 `idle_default`、`walk_default`、`search_default`、`alert_default`；四个状态均返回 `driven=true`，且动画标记实际发生旋转，证据为 `reference-evidence/candidate-makehuman-animation-contract.json`。这只证明接口可接入，不代表最终骨骼动画质量。
- 视觉返工：生成 `art-source/characters/makehuman-office-worker/makehuman_office_worker_candidate_recolor.glb`，将服装材质压到灰色办公室色调，并在隔离预览脚本中补上背包挂点；真实图形对照显示比原始蓝色工装更接近参考轮廓，但仍未达到参考人物的比例、面部、材质和动作要求。
- 视觉状态：未验收。近距离截图仍显示人物体型、服装、面部气质、手臂比例和动作姿态与参考男性办公室角色不一致，当前服装颜色与轮廓也不符合参考镜头。
- 结论：它是下一轮人物写实化的候选来源，不是当前 NPC 的替换结论；`integration_status=verified_editor_import_runtime_graphics_animation_contract_unverified_external_only`、`visual_status=unverified`、`release_allowed=false`。

## 2026-10-07：第二套系统服装生成尝试

- 尝试使用同一已登记的男性基础人物和 MakeHuman 系统服装 `male_elegantsuit01.mhclo` 生成第二版办公室人物候选，用于改善参考帧中的灰色长袖、深色长裤和背包轮廓。
- Blender `5.2.0` 在 macOS Metal 后端初始化阶段发生段错误，未进入 MPFB2 生成脚本，未生成新 GLB；本次不改变现有候选文件、运行时目录或发布状态。
- 下一次人物候选改走可复现的 Godot/GLB 处理链路或经过独立审计的新来源；在获得真实图形截图并完成人工视觉验收前，现有候选继续保持 `visual_status=unverified`、`release_allowed=false`。

## 2026-10-07：隔离预览返工准备

- 在 `makehuman_office_npc_retouch.gd` 中增加浅色长袖、深色肩带、领口和腰带叠层，用于更接近参考帧中的办公室人物服装关系；改动只存在于 `art-source` 的隔离预览脚本。
- workspace 与临时候选工程的 Godot 脚本语法检查均通过；图形截图探针本轮未正常结束，因此没有生成新的视觉证据，也没有改变 `visual_status`、正式运行时或发布候选树。
- 已读取候选 GLB 的真实骨骼清单，共 53 根骨骼，包含 `spine_01/02/03`、双侧上臂/前臂/手、双侧大腿/小腿/脚和头部；隔离预览脚本现在按这些骨骼提供待机、行走、搜索和警觉姿态驱动。该代码已通过 Godot 语法检查，但尚未取得真实图形动作截图，因此仍不构成视觉通过。
- 使用正式回归同样的独立 `--log-file` 启动边界后，四种姿态均在真实 `Skeleton3D` 上产生骨骼变化：待机 `spine_02`、行走 `upperarm_l/thigh_l`、搜索 `head/spine_02`、警觉 `head/spine_03`；证据为 `reference-evidence/candidate-makehuman-bone-animation-contract.json`。这证明动画驱动接口，不替代图形动作质量和视觉签收。
