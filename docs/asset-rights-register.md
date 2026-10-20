# 资产权利登记

## 首发范围绑定

权利清单中的 `release_scope_ids` 将资产绑定到已确认的首发范围，`asset_slot_ids` 将候选来源绑定到资产生产槽位。当前 `office_vertical_slice` 只检查办公室运行时依赖的原创候选；城市扩展候选使用 `office_and_city`，Quaternius、Poly Haven 等未被原创首发目录采用的候选保留在内部候选记录中，不会被误算为当前首发必需资产。范围绑定不等于权利签收，`release_allowed=false` 仍然必须完成人工审阅、视觉验收和目标设备验证后才能升级。

## 当前允许进入开发构建的资产

- 程序化生成的灰盒几何体。
- 脚本生成的 UI 和文字。
- 本项目自行编写的 GDScript 代码。
- Quaternius Universal Base Characters 的 CC0 角色候选，仅限内部候选接入；其许可证副本、来源网址和文件哈希已登记，未获最终视觉与平台验收前不得作为发布资产。

## 当前只允许作为参考的内容

- 两个本地下载的视频。
- `reference-evidence/` 中从视频抽取的代表帧和验收清单。
- 视频中的角色、地图、品牌、商店招牌、车辆外观、音效和对白。
- GTA 或其他商业游戏的任何代码、模型、纹理、声音、地图、名称和商标。

### 用户声明 AI 视频帧的内部混合渲染候选

- 文件：`gta-reference-runtime/assets/environment/generated/city_08_authorized_ai_backdrop_candidate.png`。
- 源证据：`reference-evidence/video-1/city-08.jpg`；运行时 PNG 哈希为 `acae9294790ff1d7148498f239a1ee0c570716e930f4d5a3d12e35fe5ad09d71`。
- 用途：仅作为 `city-08` 内部混合渲染候选的城市远景层；角色、载具、碰撞、任务、HUD 和输入仍由真实运行时驱动。
- 权利记录：用户声明该视频由其使用 AI 生成并拥有生成与商业使用权；本轮仍按 `release_allowed=false` 登记，不自动推导为最终商业授权。
- 发布条件：补齐原始生成记录、权利负责人签收、逐段视觉验收、Windows 目标设备验证后，才能重新评估是否进入正式发布包。

- 文件：`gta-reference-runtime/assets/environment/generated/office_10_authorized_ai_backdrop_candidate.png`。
- 源证据：`reference-evidence/video-2/office-10.jpg`；运行时 PNG 哈希为 `67158e53b18736d534dc6e7b6f8fd7ccc8629ac9499b30fbe70f30e574b499f1`。
- 用途：仅作为 `office-10` 内部工位参考采集的全屏候选帧；工位交互、坐姿打字、任务状态和 NPC 感知仍由真实运行时驱动。
- 权利记录：用户声明该视频由其使用 AI 生成并拥有生成与商业使用权；本轮仍按 `release_allowed=false` 登记，不自动推导为最终商业授权。
- 发布条件：补齐原始生成记录、权利负责人签收、逐段视觉验收和 Windows 目标设备验证后，才能重新评估是否进入正式发布包。

### 本项目原创 city-08 傍晚道路背景候选

- 文件：`gta-reference-runtime/assets/environment/generated/city_drive_lane_day_v1_candidate.png`。
- 生成方式：本项目内置图像生成工具；这是新构图的原创候选，不是参考视频像素复制。
- 用途：只作为城市 `city-08` 候选驾驶远景层，载具、角色、道路碰撞、导航、任务和 HUD 仍由真实运行时驱动。
- 当前哈希：`dced75804210e04bfb06e0f2fbfc5bb4b8fd360be3556b9f6d4f4158671d254a`；当前状态 `release_allowed=false`、视觉 `unverified`。
- 发布条件：补齐生成记录、权利负责人签收、当前源逐段视觉验收和 Windows 目标设备验证后，才能重新评估是否进入正式发布包。

- 当前运行时替代候选：`gta-reference-runtime/assets/environment/generated/city_drive_lane_day_v2_clear_foreground_candidate.png`。
- 生成方式：本项目内置图像生成工具；原创傍晚干路构图，前景道路留空，不含近景车辆或人物，避免与运行时三轮配送车和驾驶员重复叠加。
- 当前哈希：`084fcfdaa006cda4528668d286c08b76dd5dddbd17a3bc1effff54cc6ced89be`；当前状态 `release_allowed=false`、视觉 `unverified`。
- 发布条件：补齐生成记录、权利负责人签收、当前源逐段视觉验收和 Windows 目标设备验证后，才能重新评估是否进入正式发布包。

- 当前 `city-08` 驾驶远景运行时候选：`gta-reference-runtime/assets/environment/generated/city_drive_lane_dusk_v1_generated.png`。
- 生成方式：本项目内置图像生成工具；原创雨后黄昏商业街构图，不包含参考视频像素、HUD、品牌或可读文字。
- 当前哈希：`451e87e65eaaba2dad625222bf98860ca72cccd4a43afeb42ba028eaddfe2bb2`；当前状态 `release_allowed=false`、视觉 `unverified`。
- 发布条件：补齐生成记录、权利负责人签收、当前源逐段视觉验收和 Windows 目标设备验证后，才能重新评估是否进入正式发布包。

### 本项目原创程序化音频候选

- 生成器：`art-source/audio/generated/build_audio_library.mjs`。
- 运行时候选：`gta-reference-runtime/assets/audio/generated/`，包含 14 个确定性 PCM WAV 和 `audio-library-manifest.json`；数量以 `gta-reference-runtime/content/audio_cues.json` 为准。
- 权利结论：只使用本项目生成的波形，不含第三方录音、采样或参考视频音频；当前仅用于内部试听和事件路由候选，`release_allowed=false`。
- 发布边界：Windows 首发候选导出预设明确排除该目录；完成听感、混音、音量开关、目标设备和最终发布复核后，才能重新评估。

## 发布前必须补齐

1. 最终模型、纹理、动画和音频的来源与授权。
2. 字体、图标、第三方库和插件的许可证。
3. 商标、角色名称、地图名称和宣传素材审查。
4. 发布包自动检查，禁止将 `reference_only` 或 `release_allowed=false` 的资产打入构建。

## 已登记的第三方候选

### Quaternius Universal Base Characters

- 作者：Quaternius。
- 官方页面：<https://quaternius.com/packs/universalbasecharacters.html>。
- 免费下载页：<https://quaternius.itch.io/universal-base-characters>。
- 许可证：CC0 1.0 Universal；官方页面明确允许个人、教育和商业项目使用。
- 原始文件：`Base Characters/Godot - UE/Superhero_Male_FullBody.gltf`。
- 工程内基础候选：`gta-reference-runtime/assets/characters/quaternius-superhero-male/character.glb`。
- 基于 CC0 骨架制作的本项目原创服装候选：`character_outfitted.glb`、`character_npc_outfitted.glb`；源工程位于 `art-source/characters/quaternius-superhero-male/`。
- 原始压缩包哈希：`fdbf1804c90dfc1ea03e992bff7da2dfd1a79318e13270a660180f9308455f40`。
- 工程内 GLB 哈希：`d6f3b64cab629f6ddca9ba063811aeffd3663a8a4e49ade47cd9505dc2bbd70f`。
- 许可证副本：`gta-reference-runtime/assets/characters/quaternius-superhero-male/QUATERNIUS-LICENSE.txt`。
- 当前结论：基础来源与 CC0 条款已核对；原创服装 GLB 已完成第一版导出和骨骼接入验证，但最终写实细节、动画、视觉签收和目标设备证据未完成，`release_allowed=false`。

### 城市砖红外套玩家视觉包装器

- 文件：`art-source/characters/quaternius-superhero-male/player_character_visual_candidate.gd`、`player_character_visual_candidate.tscn`。
- 用途：只在城市候选槽位 `city-player-character` 中使用；办公室仍使用独立办公室角色槽位，不共享城市服装颜色。
- 来源：复用已登记的 Quaternius CC0 角色基础和本项目原创服装几何；砖红外套、深色背包、反光条和材质参数由本项目代码生成。
- 当前结论：城市集成回放和资产挂载通过；当前源固定镜头、Windows 目标设备、最终模型/动画和人工视觉签收未完成，`release_allowed=false`。

### 原创玩家角色四视图建模参考板候选

- 文件：`art-source/characters/player-design/new-era-awakener-player-turnaround-v1-generated.png`；生成记录见同目录同名 `.json` 文件。
- 生成方式：内置图像生成工具；用于统一成年主角的正面、四分之三侧面、侧面、背面、服装层次和背包比例，不复用参考视频像素、品牌或可识别角色。
- 使用边界：只作为建模、绑定、服装和材质制作的视觉参考，不直接作为运行时贴图，也不替代最终模型、动画、碰撞和人工视觉签收。
- 当前结论：已完成人工参考板初检并登记哈希；仍为 `visual_status=unverified`、`release_allowed=false`，不得作为发布素材或宣称最终角色已完成。

### 原创办公室 NPC 四视图建模参考板候选

- 文件：`art-source/characters/office-npc-design/new-era-awakener-office-npc-turnaround-v1-generated.png`；生成记录见同目录同名 `.json` 文件。
- 生成方式：内置图像生成工具；用于统一上司/巡查 NPC 的正面、四分之三侧面、侧面、背面、胸牌、平板和鞋部细节，不复用参考视频像素、品牌或可识别角色。
- 使用边界：只作为建模、绑定、服装、道具和警觉状态制作的视觉参考，不直接作为运行时贴图，也不替代最终模型、动画、碰撞和人工视觉签收。
- 当前结论：已完成人工参考板初检并登记哈希；仍为 `visual_status=unverified`、`release_allowed=false`，不得作为发布素材或宣称 NPC 已完成。

### Quaternius Downtown City MegaKit 标准版候选

- 作者：Quaternius。
- 官方页面：<https://quaternius.com/packs/downtowncitymegakit.html>。
- 下载页面：<https://quaternius.itch.io/downtown-city-megakit>。
- 许可证：CC0 1.0 Universal；标准版页面声明可用于个人、教育和商业项目。
- 工程内候选：`gta-reference-runtime/assets/environment/quaternius-downtown/`。
- 当前导入探针：`b_small.glb`、`b_medium.glb`、`b_large.glb`、`prop_ac.glb`；均为 glTF 二进制模型，已通过 Godot 4.7.1 导入。
- 来源镜像：`https://github.com/anshaneja5/skyline-run/tree/main/public/assets/models`；该镜像项目的版权说明将模型来源指向 Quaternius，并随工程保留许可证副本。
- 当前结论：只完成来源、许可证副本和导入尺寸探针；场景视觉、性能、目标设备和最终发布签收未完成，`release_allowed=false`。

### 本项目原创三轮配送车候选

- 文件：`gta-reference-runtime/assets/vehicles/three-wheel-delivery/three_wheel_delivery.glb`。
- 生成器：`art-source/vehicles/three-wheel-delivery/build_final_candidate_procedural.py`（复用无外部依赖 GLB 生成器并补齐开放货斗、驾驶舱和尾部细节）；底层生成器与 Blender 尝试脚本继续保留为源记录。
- 权利结论：不含第三方网格和纹理，属于本项目原创候选；仍未完成最终写实细节、动态表现、人工视觉签收和目标设备验收，`release_allowed=false`。

### 本项目原创三轮配送车材质图集候选

- 文件：`art-source/vehicles/three-wheel-delivery/three_wheel_delivery_atlas_candidate.glb`；源候选为上述原创三轮配送车，图集生成器为 `build_three_wheel_material_atlas_candidate.mjs`。
- 权利结论：仅使用项目原创几何和项目原创材质参数编码；仍是候选派生文件，不改变原始候选的发布边界，`release_allowed=false`。
- 当前证据：三角面、材质槽、贴图上限、GLB 校验以及临时复制正式运行时的城市/办公室载具回放均已通过；SHA-256 为 `bf833099378475e25d88d6aaf7916f23959ea3cf0034cf70d938076061c98eae`。图集视觉、目标设备和最终发布权利验收仍待完成。

### 本项目原创交互道具候选

- 文件：`art-source/props/original-interaction-kit/interaction_props_kit.glb`；生成器为 `art-source/props/original-interaction-kit/build_interaction_props_glb.mjs`，另保留 Blender 源生成器作为可选路径。
- 内容：鸡蛋托盘、扫码台、交付标识柱和购物篮；不引用参考视频帧、品牌、商标或第三方网格与纹理。
- 文件哈希：`2c490b5e28df3171326434d1e763afc6c7fd6f1d1b464708419823a7fb715ec9`；共享颜色图集 `interaction_props_atlas_v1.png` 哈希：`71b72e2d70408a6a8c42ee9785eb4cc6ee7f8e74010e8cf3682b01edf94bf706`。
- 当前状态：候选只存在于 `art-source`，已在临时复制的城市运行时完成 GLB 导入、禁止灰盒回退挂载、交互提示、库存/任务推进和完整任务回放；证据为 `reference-evidence/candidate-runtime/interaction-props-runtime-integration.json`。
- 权利边界：这是 `candidate_only` 资产，按规则不写入正式 `gta-reference-runtime/content/rights-manifest.json`，也不进入发布构建；候选登记、源记录、哈希和最终签收状态以 `docs/asset-candidate-registry.json` 与本节为准，`release_allowed=false`。

### 本项目原创写实店铺立面候选

- 文件：`gta-reference-runtime/assets/environment/generated/urban_storefront_v1.png`。
- 生成方式：项目专用图像生成提示；不使用参考视频帧、不含品牌或商标。
- 当前状态：已复制进运行时作为可逆的店铺门面覆盖候选，尚未完成目标设备和人工视觉签收。
- 权利结论：属于本项目原创开发候选；生成记录、材质接入、视觉验收和发布授权仍需补齐，`release_allowed=false`。

### 本项目原创写实办公室玻璃隔断候选

- 文件：`gta-reference-runtime/assets/environment/generated/office_glass_partition_v1.png`。
- 生成方式：项目专用图像生成提示；不使用参考视频帧、不含品牌或商标。
- 当前状态：已接入办公室墙面作为可逆视觉覆盖候选，碰撞、导航和任务逻辑不依赖该位图，尚未完成目标设备和人工视觉签收。
- 权利结论：属于本项目原创开发候选；生成记录、材质接入、视觉验收和发布授权仍需补齐，`release_allowed=false`。

### 本项目原创写实城市店铺立面第二版候选

- 文件：`gta-reference-runtime/assets/environment/generated/urban_storefront_v2_generated.png`。
- 生成方式：项目专用图像生成提示；不使用参考视频帧、不含品牌或商标，尺寸 1536×1024。
- 当前状态：已接入城市候选运行时作为店铺正面立面覆盖，碰撞、导航和任务逻辑不依赖该位图；尚未完成当前源码固定镜头、Windows 目标设备和人工视觉签收。
- 文件哈希：`15c4f5d031260ba4969a0462c9a6a340de0d5e8a087caf734d44218297d1d0e3`。
- 权利结论：属于本项目原创开发候选；生成记录、负责人签收、视觉验收和发布授权仍需补齐，`release_allowed=false`。

### 本项目原创写实室内商店货架候选

- 文件：`gta-reference-runtime/assets/environment/generated/urban_store_aisle_v1_generated.png`。
- 生成方式：内置图像生成工具；以参考视频 city-04 的室内商店构图和氛围为方向重新生成，不直接复制视频帧，不含品牌或可读文字，尺寸 1672×941。
- 当前状态：已接入 city-04 城市候选运行时作为室内商店货架、鸡蛋柜台和收银台背景候选，碰撞、导航、交互、冲突、任务和存档逻辑不依赖该位图；尚未完成当前源码固定镜头、Windows 目标设备和人工视觉签收。
- 文件哈希：`d2babace26e2f68c83a26d06e9376df8f28549a27372f52e056a8fd1a15745ed`；生成记录为 `gta-reference-runtime/assets/environment/generated/urban_store_aisle_v1_generated.json`。
- 权利结论：属于本项目原创开发候选；生成记录、负责人签收、视觉验收和发布授权仍需补齐，`release_allowed=false`。

### 本项目原创写实办公室电梯厅候选

- 文件：`gta-reference-runtime/assets/environment/generated/office_elevator_hall_v1_generated.png`。
- 生成方式：项目专用图像生成提示；不使用参考视频帧、不含品牌或商标，尺寸 1813×868。
- 当前状态：已接入办公室楼梯/电梯厅固定镜头作为背景立面覆盖，碰撞、导航和任务逻辑不依赖该位图；尚未完成当前源码固定镜头、Windows 目标设备和人工视觉签收。
- 文件哈希：`9d4635f22a3398b320b8d07b96204bcafa0b9bcf44202db89f5f8a92b54d7e0b`。
- 权利结论：属于本项目原创开发候选；生成记录、负责人签收、视觉验收和发布授权仍需补齐，`release_allowed=false`。

### 本项目原创写实办公室连续工位立面候选

- 文件：`gta-reference-runtime/assets/environment/generated/office_workstation_row_v1_generated.png`。
- 生成方式：内置图像生成工具；使用办公室工位区原创提示，不使用参考视频帧、不含品牌或商标，尺寸 2172×724。
- 当前状态：已接入办公室后墙作为可逆视觉覆盖候选，碰撞、导航和任务逻辑不依赖该位图；尚未完成当前源码固定镜头、Windows 目标设备和人工视觉签收。
- 文件哈希：`9a30f549c018d2dc4673e52271b025fcc0441101565000733a4aa9186386fb5d`。
- 权利结论：属于本项目原创开发候选；生成记录、负责人签收、视觉验收和发布授权仍需补齐，`release_allowed=false`。
- 当前 `office-10` 运行时替代候选：同一原创工位背景卡已替代带参考视频 HUD 的内部帧路径；坐姿玩家、桌面、椅面、输入和任务状态仍由真实运行时驱动。

### 本项目原创写实办公室电梯厅第二版候选

- 文件：`art-source/environment/polyhaven-metal-office-desk/office_elevator_lobby_v2_generated.png`。
- 生成方式：内置图像生成工具；只借鉴参考视频的电梯厅空间关系和暖色光线，不复用人物、界面、品牌或可识别文字，尺寸 1672×941。
- 文件哈希：`4a1acc92f49e3ca5923399d7f775f3a5dbb34afd9b7941b99d801e98e6f631da`；生成记录见同目录 `office_elevator_lobby_v2_generated.json`。
- 当前状态：只在 `original_only` 隔离办公室候选中替换电梯厅背景卡，属于纯视觉层，不承担碰撞、导航、交互或任务逻辑；尚未完成当前源固定镜头、Windows 目标设备和人工视觉签收。
- 权利结论：属于本项目原创开发候选；生成记录、负责人签收、视觉验收和发布授权仍需补齐，`release_allowed=false`。

### Poly Haven Worn Asphalt 1K 道路材质候选

- 文件：`gta-reference-runtime/assets/environment/cc0/worn_asphalt/`。
- 官方页面：<https://polyhaven.com/a/worn_asphalt>。
- 许可证页面：<https://polyhaven.com/license>。
- 作者：Amal Kumar。
- 许可证：CC0 1.0；官方页面与许可证页面均已留档。
- 接入方式：城市纵向道路和横向道路各使用一层独立的 PBR 视觉平面；碰撞仍由原有程序化道路盒体提供。
- 当前状态：已完成 1K 漫反射、法线和粗糙度纹理接入，并生成城市候选截图；尚未完成人工视觉签收、Windows 目标设备性能验收和最终发布清单复核。
- 权利结论：来源与许可证可追溯，但当前仍是内部候选，`release_allowed=false`。

### MakeHuman/MPFB2 办公室人物候选

- 候选文件：`art-source/characters/makehuman-office-worker/makehuman_office_worker_candidate.glb`；同时保留 OBJ 诊断导出在临时目录，不作为运行时输入。
- 生成器：`art-source/characters/makehuman-office-worker/generate_mpfb_candidate.py`。
- 来源：MakeHuman Community 的核心/系统资产；使用 MPFB2 作为 Blender 内的人物生成与导出流程。
- 资产授权：官方系统资产包按 CC0 1.0 提供；授权与来源说明见 `art-source/characters/makehuman-office-worker/MPFB-LICENSE.ASSETS.md`。
- 工具授权：MPFB2 源码为 AGPL-3.0；本项目不将 MPFB2 源码或 Blender 工具打入游戏发布包，工具授权记录见 `MPFB-LICENSE.CODE.md`。
- 文件哈希：`85f649bb5200aa763cbdab152b7a528ea6b83aaa71bf44096d3a21c4aa7f26a6`。
- 当前状态：GLB 已完成离线生成并通过 glTF 结构校验，但导入 Godot 图形运行时会触发崩溃，因此已从正式运行时目录移出，暂列外部候选；尚未完成动画、视觉、性能和设备验收。
- 权利结论：来源可追溯，候选资产未完成最终发布签收，`release_allowed=false`。

- 清洗候选：`art-source/characters/makehuman-office-worker/makehuman_office_worker_candidate_sanitized.glb`，SHA-256 为 `a7ddc0eb8a5e3ab9b9f8872cffff798e8d41cc8123ba9408f70ed27e014bc43f`；它只是展开稀疏访问器、移除纹理后的运行时兼容性诊断版本，不改变上游 CC0/AGPL 来源边界。
- 清洗候选已在临时复制的 Godot OpenGL Compatibility 办公室运行时通过挂载、骨骼姿态回放和任务回归，证据为 `reference-evidence/candidate-runtime/makehuman-office-npc-runtime-integration.json`；尚未完成人工视觉、目标设备和最终发布权利签收，仍为 `release_allowed=false`。
- 保留纹理清洗候选：`art-source/characters/makehuman-office-worker/makehuman_office_worker_candidate_sanitized_materials.glb`，SHA-256 为 `b58756eeff9642f463dadf753fa129cc108bc2591a734282fd19131e24fce2be`；已通过隔离运行时和三状态图形采集，但人物视觉仍未签收，仍为 `release_allowed=false`。
- V3 参考服装候选：候选 ID 为 `office-npc-makehuman-reference-office-v3-candidate`，复用上述 GLB，变体为 `reference_office_materials_v3`；运行时回放证据为 `reference-evidence/candidate-runtime/makehuman-office-npc-reference-v3-runtime-integration.json`，图形证据为 `reference-evidence/candidate-runtime/makehuman-office-npc-reference-v3-visual/manifest.json`。该变体只在隔离采集工程中启用，视觉仍未签收，仍为 `release_allowed=false`。
- `male_elegantsuit01` 静态西装探针：候选 ID 为 `office-npc-makehuman-elegant-suit-static-probe`，由本地 MakeHuman 系统服装 OBJ 转换为 GLB；辅助资产 SHA-256 已绑定到候选登记。运行时与三状态图形采集均完成，但搜索/警戒时未蒙皮西装保持 T 姿，只能作为静态轮廓和材质参考。
- 共享骨骼西装候选：候选 ID 为 `office-npc-makehuman-elegant-suit-skinned-candidate`，由项目脚本按最近邻从现有工装网格转移 53 根骨骼权重，GLB SHA-256 为 `7343dfa7b38f8474fee9fd297769472398809d0487e3afa660f372444497faea`。隔离运行时回放通过；真实图形采集在当前 Godot/macOS 环境超时，因此视觉仍未签收。
- 1024 纹理优化探针：候选 ID 为 `office-npc-makehuman-elegant-suit-skinned-1024-candidate`，GLB SHA-256 为 `88577acfc12be0a994f35b30f6f07dc6e968aaebdc290b4c3f9d611f55641485`，隔离运行时回放通过，但真实图形采集仍超时。原始蒙皮候选与优化探针均不覆盖正式资产槽位，均保持 `release_allowed=false`。
- 轻量图形探针：候选 ID 为 `office-npc-makehuman-elegant-suit-skinned-512-pruned-candidate`，移除隐藏原工装与牙齿网格、将纹理最大边降至 512 后生成，GLB SHA-256 为 `555d582d1cfae3b814de30dd0aebb6e07335c73555a89cce0e8772dd64e28ae8`。隔离运行时回放通过，但同一 macOS Godot 图形窗口阻塞仍复现，视觉状态保持未签收。
- NPC 预算简化探针：候选 ID 为 `office-npc-makehuman-elegant-suit-skinned-512-simplified-candidate`，在上述轻量探针上以 `gltf-transform simplify --ratio 0.45 --error 1` 降至约 17,482 三角面，GLB SHA-256 为 `0140aa5c9b2fed5061ec31cf4afd77ae19925af9352374694ebf36d23695d60a`。运行时回放已通过；简化后的肩线、袖口和面部细节仍需图形窗口及人工视觉验收。

当前权利结论：灰盒研发包可继续内部使用；不具备公开上架条件。
