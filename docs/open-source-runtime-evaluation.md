# 开源运行时与插件评估

评估日期：2026-10-16

本文件用于回答“是否可以用开源能力加速《新时代觉醒者》研发”，不等同于已经引入任何第三方代码。当前正式运行时仍以 Godot 4.7.1 和本项目自有 GDScript 为准；在视觉验收、目标设备 QA 和最终资产权利完成前，不把新插件直接并入候选或发布包。

## 结论

当前不更换引擎，也不迁移现有角色、镜头、任务和感知系统。现有运行时的行为矩阵已经达到 `21/21 + 10/10`，此时引入新的控制器、摄像机或 AI 框架会改变已冻结的行为基线，增加视觉重采集范围。

可以保留以下三类后续加速方向：

1. 以 MIT 代码为参考或隔离试验依赖，不直接替换当前正式实现。
2. 只在新功能确实超出现有状态机能力时，评估 LimboAI 作为 NPC 行为编辑工具。
3. 任何第三方模型、纹理、示例场景和演示素材必须单独审查，不能因为代码是 MIT 就推断美术资产可商用。

## 组件评估

| 组件 | 官方来源与许可证 | 可帮助的部分 | 当前决策 |
| --- | --- | --- | --- |
| Godot Engine | [Godot FAQ](https://github.com/godotengine/godot-docs/blob/master/about/faq.rst)；引擎 MIT | 桌面、Windows、macOS、移动端导出；GDScript、导航、渲染和物理基础 | 保持使用。Godot 官方说明允许商业使用，但引擎内第三方库仍需按各自许可证核对。 |
| Godot 内置 Jolt Physics | [Godot 第三方依赖说明](https://github.com/godotengine/godot/blob/master/thirdparty/README.md)；Jolt MIT | 刚体、碰撞、载具和更大场景的物理基础 | 不另加物理插件。当前载具和交互行为先保持现有实现，避免物理替换导致重测。 |
| GDQuest 3D Third-Person Controller | [官方仓库](https://github.com/gdquest-demos/godot-4-3d-third-person-controller)；代码 MIT，但示例模型和纹理为 CC-BY-NC-SA 4.0 | 可参考第三人称移动、瞄准和敌人结构 | 不直接引入。代码可作为隔离参考，演示美术资产不能进入本项目商业候选包。 |
| Phantom Camera | [官方仓库](https://github.com/ramokz/phantom-camera)；MIT | Camera3D 跟随、第三人称、SpringArm、优先级切镜 | 暂不引入。项目已有固定镜头契约；插件只在后续需要复杂镜头编排且通过 A/B 视觉回归后再评估。 |
| LimboAI | [官方仓库](https://github.com/limbonaut/limboai) 与 [许可证](https://github.com/limbonaut/limboai/blob/master/LICENSE.md)；源代码 MIT，演示美术另有 CC-BY 许可 | 行为树、黑板、状态机、NPC 行为编辑和调试；仓库当前列出 Godot 4.7 模块支持 | 暂不迁移。现有 NPC 感知、任务状态机和行为回放已经有直接证据；后续可在隔离分支验证复杂 NPC 行为，但不能替换已验收状态机。 |
| OpenKCC | [官方仓库](https://github.com/nicholas-maltbie/Godot-OpenKCC)；MIT | 运动学角色控制器和碰撞处理参考 | 不引入。项目已有玩家移动、蹲伏、交互和存档回放，替换控制器会扩大行为与视觉重测范围。 |

## 引入门禁

任何新的开源组件必须先满足以下条件：

- 锁定官方仓库、提交版本和许可证文件，并登记到权利来源清单。
- 分离代码、示例场景、模型、纹理、动画、音频和字体的权利状态。
- 在隔离候选目录验证，不直接写入正式运行时或发布包。
- 重跑行为矩阵、扩展行为、资产交接、发行边界和 Windows 构建清单。
- 如果影响镜头、角色控制、NPC 感知、物理或任务状态，必须重新采集当前源 21 段视觉矩阵；旧 PNG 不得复用。
- 只有目标设备和人工视觉签收通过后，才可以考虑进入最终资产或发布候选。

## 当前工程选择

本项目当前最合理的加速方式不是更换底层框架，而是继续使用已有 Godot 运行时，把外部开源项目限制在“参考实现或隔离实验”范围内。这样不会牺牲参考视频的逐项行为契约，也不会把第三方示例美术误带入原创边界候选包。

