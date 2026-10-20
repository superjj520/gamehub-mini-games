# MakeHuman 办公室人物候选

## 目录定位

这里保存的是人物写实化候选和可重复生成流程，不是正式发布资产目录。任何文件进入 `gta-reference-runtime/` 前，都必须经过权利、Godot 运行时、动画、目标设备和人工视觉五项验收。

## 当前文件

- `generate_mpfb_candidate.py`：使用 Blender 与 MPFB2 生成候选人物。
- `makehuman_office_worker_candidate.glb`：带原始材质的候选，SHA-256：`85f649bb5200aa763cbdab152b7a528ea6b83aaa71bf44096d3a21c4aa7f26a6`。
- `makehuman_office_worker_candidate_sanitized.glb`：去除纹理、展开稀疏访问器、保留基础蒙皮的诊断候选；它只用于验证 Godot 运行时兼容性，不代表最终视觉资产。当前 SHA-256：`a7ddc0eb8a5e3ab9b9f8872cffff798e8d41cc8123ba9408f70ed27e014bc43f`。
- `makehuman_office_worker_candidate_sanitized_materials.glb`：保留纹理、展开稀疏访问器并移除切线属性的兼容性候选；SHA-256：`b58756eeff9642f463dadf753fa129cc108bc2591a734282fd19131e24fce2be`，仍不是最终视觉资产。
- `makehuman_office_worker_candidate_recolor.glb`：服装色调返工候选，SHA-256：`f0de96ac46b5134f86a6049edbec8c243cb7bd22444cfc2a774bb0a7bcd71189`；只用于视觉对照，不代表视觉通过。
- `makehuman_office_npc_retouch.gd`：隔离预览用的服装材质覆盖、背包挂点和真实骨骼姿态驱动脚本，不进入正式运行时。
- `reference_office_materials_v3`：隔离验收变体，保留导入皮肤/头发纹理，将服装底色调整为办公室灰色并使用白鞋；不使用程序化服装盒体，避免姿态变化时产生穿插假象。对应候选登记为 `office-npc-makehuman-reference-office-v3-candidate`。
- `build_makehuman_obj_glb.mjs`：将 MakeHuman `male_elegantsuit01` OBJ/PNG 转为独立静态西装 GLB；静态探针只用于轮廓和材质判断。
- `skin_makehuman_elegant_suit.mjs`：将静态西装顶点按最近邻复制到现有人物 53 根骨骼权重，生成共享骨骼西装候选；当前图形采集仍受 Godot/macOS 导入超时阻塞，不能视为动作服装通过。
- `makehuman_office_worker_elegant_suit_skinned_1024.glb`：将蒙皮候选纹理最大边压到 1024 的快速测试探针，原始 28MB 级候选仍保留，不覆盖正式资产。
- `build_makehuman_visual_probe.mjs` 与 `makehuman_office_worker_elegant_suit_skinned_probe_512.glb`：移除隐藏原工装/牙齿网格并将纹理最大边压到 512 的图形导入探针；文件约 6.77MB，运行时回放通过，但当前 macOS Godot 图形窗口初始化仍超时。
- `makehuman_office_worker_elegant_suit_skinned_probe_512_simplified.glb`：在 512 探针上以 `gltf-transform simplify --ratio 0.45 --error 1` 生成的 NPC 预算探针，约 17,482 三角面、3.3MB；已通过隔离运行时回放，尚未完成图形验收。
- `build_makehuman_material_atlas_candidate.mjs` 与 `makehuman_office_worker_elegant_suit_skinned_probe_512_atlas_candidate.glb`：将 7 个角色材质按皮肤、头发细节和服装分成 3 个 1024 图集，并同步重映射 UV 与金属/粗糙度图集；技术预算通过，但仍是候选资产。
- `makehuman_bone_animation_contract.gd`：可复现的真实 `Skeleton3D` 姿态契约测试工具，不进入正式运行时。
- `makehuman_office_runtime_integration_test.gd` 与 `run_isolated_office_npc_runtime.mjs`：把清洗候选挂入临时复制的正式办公室场景，验证骨骼、四种姿态、背包挂点和办公室任务回放，不进入正式运行时。
- `reference-evidence/candidate-makehuman-bone-animation-contract.json`：在隔离 Godot 工程中对四种真实骨骼姿态的契约证据；仅证明候选姿态驱动可用，不代表视觉或发布通过。
- `MPFB-LICENSE.ASSETS.md`：人物资产来源与 CC0 记录。
- `MPFB-LICENSE.CODE.md`：MPFB2 工具源码授权记录；工具源码不随游戏发布。

## 生成和清洗

在安装了 Blender、MPFB2 和 MakeHuman 系统资产包的环境中运行：

```text
blender --background --python art-source/characters/makehuman-office-worker/generate_mpfb_candidate.py
node scripts/sanitize_mpfb_candidate.mjs 原始候选.glb 清洗候选.glb
GLTF_KEEP_TEXTURES=1 node scripts/sanitize_mpfb_candidate.mjs 原始候选.glb 保留纹理清洗候选.glb
```

生成器支持通过 `MPFB_CLOTHING_ASSET` 和 `MPFB_HAIR_ASSET` 选择系统资产包中的服装与发型，例如 `male_elegantsuit01.mhclo`；候选版本必须重新生成、重新计算哈希并重新截图，不能只修改登记文字。

清洗脚本只用于诊断兼容性，不代表最终材质方案。无纹理版和保留纹理版都已经通过 Godot 编辑器导入探针，并在隔离复制的 OpenGL Compatibility 办公室运行时完成挂载与回放；原始材质/返工版仍需单独解决当前 Godot 的 Sparse indices 导入兼容性问题。候选仍未进入正式运行时。

## 下一步验收

1. 清洗版已在隔离 Godot 图形环境中完成办公室挂载、骨骼检查、四状态回放和任务回归；证据为 `reference-evidence/candidate-runtime/makehuman-office-npc-runtime-integration.json`，正式运行时仍不接入。
2. 已验证四个状态名可以通过统一运行时桥接驱动；隔离预览脚本进一步按候选 GLB 的 53 根骨骼实现待机、行走、搜索和警觉姿态，但仍需在真实图形窗口完成动作质量验收，当前契约证据在 `reference-evidence/candidate-makehuman-animation-contract.json`。
3. 对比现有办公室 NPC 的身高、朝向、视线起点、搜索目标点和碰撞范围，并重新制作符合参考视频的服装、面部和动作。
4. 完成人工视觉签收、Windows 目标设备回归和最终权利复核后，才能替换灰盒。

图集候选的技术证据为 `reference-evidence/candidate-runtime/asset-budget-verification.json`；该证据只证明规模预算，不证明材质视觉或发布资格。

本轮返工对照图为 `reference-evidence/candidate-makehuman-recolor-office-01.png`、`reference-evidence/candidate-makehuman-recolor-office-06.png` 和 `reference-evidence/candidate-makehuman-retouch-office-06.png`。返工版比原始蓝色工装更接近参考的灰色办公室服装和背包轮廓，但仍未达到参考视频的人物比例、面部、材质和动作要求。

## 权利边界

MakeHuman 核心/系统资产按 CC0 记录；MPFB2 是制作工具，源码授权为 AGPL-3.0。本目录的候选模型不等于已完成游戏发布授权，发布门禁以 `docs/asset-candidate-registry.json` 和 `docs/asset-rights-register.md` 为准。
