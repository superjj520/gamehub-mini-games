# 第三方声明

当前运行时使用 Godot Engine `4.7.1.stable`。

- 项目地址：[Godot Engine](https://godotengine.org/)
- 许可证：MIT
- 使用范围：运行时引擎；本项目没有把候选插件、示例模型、示例音频或被拒绝的车辆项目带入运行时。

当前内部候选还保存了一份 Quaternius Universal Base Characters 角色 GLB，用于真实角色接入验证：

- 来源：[Universal Base Characters](https://quaternius.com/packs/universalbasecharacters.html)
- 下载页：[Quaternius Itch 页面](https://quaternius.itch.io/universal-base-characters)
- 许可证：CC0 1.0 Universal
- 基础候选文件：`assets/characters/quaternius-superhero-male/character.glb`
- 基于该基础骨架导出的本项目原创服装候选：`assets/characters/quaternius-superhero-male/character_outfitted.glb`、`assets/characters/quaternius-superhero-male/character_npc_outfitted.glb`
- 对应 Blender 源文件和导出脚本：`art-source/characters/quaternius-superhero-male/`
- 许可证副本：`assets/characters/quaternius-superhero-male/QUATERNIUS-LICENSE.txt`
- 当前状态：仅内部候选，未进入正式资产目录，未通过视觉和目标设备门禁。

当前内部候选还保存了 Quaternius Downtown City MegaKit 标准版的少量城市模型，用于城市环境导入验证：

- 来源：[Downtown City MegaKit](https://quaternius.com/packs/downtowncitymegakit.html)
- 下载页：[Quaternius Itch 页面](https://quaternius.itch.io/downtown-city-megakit)
- 许可证：CC0 1.0 Universal
- 候选文件：`assets/environment/quaternius-downtown/`
- 许可证副本：`assets/environment/quaternius-downtown/LICENSE-quaternius.txt`
- 当前状态：仅内部候选，文件来自公开镜像，尚未与官方标准包逐文件核对，未进入正式资产目录，未通过视觉和目标设备门禁。

三轮配送车候选 `assets/vehicles/three-wheel-delivery/three_wheel_delivery.glb` 为本项目原创几何生成资产，不含第三方网格或纹理；生成器及 Blender 尝试脚本位于 `art-source/vehicles/three-wheel-delivery/`。当前仅用于内部候选接入，尚未通过最终视觉、动态和目标设备门禁。

写实店铺立面候选 `assets/environment/generated/urban_storefront_v1.png` 为本项目内部生成的原创位图候选，不含品牌、商标或参考视频帧；当前仅用于店铺门面覆盖预览，尚未通过最终视觉、性能和目标设备门禁。

写实办公室玻璃隔断候选 `assets/environment/generated/office_glass_partition_v1.png` 为本项目内部生成的原创位图候选，不含品牌、商标或参考视频帧；当前仅用于办公室墙面覆盖预览，尚未通过最终视觉、性能和目标设备门禁。

城市道路候选材质 `assets/environment/cc0/worn_asphalt/` 来自 [Poly Haven Worn Asphalt](https://polyhaven.com/a/worn_asphalt)，作者为 Amal Kumar，许可证为 CC0 1.0；官方许可证说明见 [Poly Haven License](https://polyhaven.com/license)。当前仅接入城市道路视觉候选，仍未通过最终视觉、性能和目标设备门禁。

正式发布包必须随附 Godot 官方 MIT 许可证原文和版权声明，并按照目标平台的商店要求提供第三方声明入口。本文件是当前内部候选工程的声明索引，不构成平台提交完成证明。

本项目的角色、场景、界面、提示音和任务内容目前均为程序化灰盒或原创开发；参考视频、抽帧证据和未授权商业资产仅存放在工程外部的内部验收目录，不得复制进发布包。
