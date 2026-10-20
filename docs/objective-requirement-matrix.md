# 项目目标逐项完成矩阵

版本：`0.1.0-dev`  
更新时间：2026-10-18
状态：产品基线与首发平台已确认；正式资产、视觉验收、目标设备和上架目标未完成。

当前运行时源码：`99953a23ef72af940d5089e8faff36db816769c3ab5234379d23c62a2cedb50f / 305`。
当前候选证据：行为 `21/21`、扩展行为 `10/10`、正式视觉 `0/21`、扩展视觉 `0/18`；以下“通过”均不代表最终上架通过。

本表是当前目标的审计入口。`通过`只表示对应范围的证据已经存在；`未完成`表示仍不能宣称最终游戏可上架。

| 目标要求 | 当前状态 | 权威证据 | 仍缺什么 |
|---|---|---|---|
| 两个参考视频本地化并建立证据库 | 通过 | `reference-evidence/manifest.json`、`scripts/verify_reference_media.mjs` | 参考媒体商业使用权仍待确认；媒体不得进入发布包 |
| 原创产品定义、范围和版权边界 | 已确认，发布资料未完成 | `docs/product-confirmation-packet.md`、`docs/product-baseline-decision.json` | 最终资产逐项权利、商店材料、隐私政策和地区发布资料仍未闭环 |
| GTA 类型第三人称底层运行时 | 内部候选通过 | `gta-reference-runtime/`、`docs/runtime-architecture.md`、`reference-evidence/current-runtime-behavior/manifest.json` | 不得使用 GTA 或其他商业游戏的可识别资产；最终资产尚未生产 |
| 第三人称角色与移动 | 灰盒通过 | `scripts/player_controller.gd`、办公室/城市集成回放 | 原创角色模型、动作、目标设备回归 |
| 第三人称镜头与遮挡处理 | 灰盒通过 | `scripts/third_person_camera.gd`、镜头状态回放 | 最终镜头构图和平台窗口校准 |
| NPC 感知、搜索和冲突 | 灰盒通过 | `scripts/perception_state.gd`、办公室/城市冲突测试 | 最终 NPC 资产、动画、音频和视觉签收 |
| 任务状态机与失败重试 | 灰盒通过 | `scripts/mission_state.gd`、`scripts/mission_chain.gd`、端到端回放 | 最终内容文本、表现和视觉签收 |
| 城市空间、人群、交通和载具 | 内部候选通过 | `scenes/city.tscn`、城市任务/冲突回放、`docs/internal-playtest-handoff.md` | 最终城市环境、人群、车辆和 Windows 性能设备证据 |
| 交互、库存和任务反馈 | 灰盒通过 | `scripts/interaction_target.gd`、`scripts/inventory_state.gd`、城市回放 | 原创道具、界面层级和最终音频 |
| HUD、暂停和输入抽象 | 灰盒通过 | HUD/暂停集成测试、`scripts/input_actions.gd`、`docs/platform-input-matrix.md` | 目标平台安全区、真实手柄/触屏和最终视觉 |
| 存档、检查点和异常恢复 | 通过当前基线 | `scripts/save_store.gd`、`scripts/session_journal.gd`、异常退出恢复测试 | 目标设备断电/后台恢复和正式发布构建回归 |
| 行为逐项验收 | 通过 | `reference-evidence/acceptance-status.json` | 当前 21/21 是自动化回放签收，不等于视觉完成 |
| 视觉逐项验收 | 未完成 | `reference-evidence/runtime-matrix/manifest.json`、`docs/visual-gap-register.md` | 当前 0/21；必须在最终资产和目标平台截图上逐段人工签收 |
| 最终资产与商业权利 | 未完成 | `docs/asset-production-manifest.json`、`docs/asset-candidate-adoption-matrix.json`、`gta-reference-runtime/content/rights-manifest.json` | 8 个正式资产槽位仍是灰盒；候选已隔离接入，但原创来源、视觉签收、平台验证和最终许可证据未闭环 |
| 目标平台导出与真机 QA | 静态导出已完成，真机未验证 | `docs/windows-build-manifest.json`、`reference-evidence/candidate-runtime/full-candidate-windows-build.json`、`docs/platform-input-matrix.md` | Windows 10/11、1080p、键鼠/手柄实机证据缺失 |
| 商店、隐私、商业化和回滚 | 基线已确认，发布资料未完成 | `docs/store-submission-checklist.md`、`docs/privacy-data-inventory.md` | Steam 商店材料、正式隐私政策、客服、年龄分级和回滚演练仍未闭环 |
| 可上架发布 | 未完成 | `npm run release:preflight` | 当前 `internal_no_go`，仍阻断产品、平台、资产、视觉和报告条件 |

## 当前硬结论

1. 运行时能力已经足以继续做灰盒回放和平台无关质量工作。
2. 21/21 行为通过不能替代最终资产、逐帧视觉签收和目标设备测试。
3. 产品基线已经确认；仍不得把候选资产、灰盒截图或未验证 Windows 构建宣称为可上架产品。
