# 候选资产隔离 A/B 审阅记录

日期：2026-10-14  
产品：新时代觉醒者  
状态：内部候选审阅；不改变正式资产清单，不允许进入发布包。

## 目的

在不接管前台设备、也不改变正式原创边界运行时的前提下，对角色、载具和完整候选环境做真实 Godot 图形采集。采集使用同一套 18 项扩展状态脚本，结果用于判断哪些资产可以继续接入，哪些必须返工。

## 采集分组

| 分组 | 配置 | 结论 |
|---|---|---|
| 完整候选 | MakeHuman 角色、候选办公室、城市候选环境、候选三轮车 | 拒绝直接接入：办公室镜头被灰墙吞没，城市环境与角色出现空间错位，载具状态可读性不足 |
| 角色/载具隔离 | Quaternius 角色和候选三轮车，保留原创环境 | 办公室结构保持稳定，但角色风格偏低多边形，城市远景仍有平面化背景；保留为行为/挂点基准 |
| MakeHuman 角色隔离 | MakeHuman 玩家与办公室 NPC，保留原创环境和逻辑 | 办公室人物轮廓明显改善；初次复制出现外部资源 UID 回退警告，城市人群/载具构图仍未通过 |

## 证据目录

- [完整候选 18 项截图](../reference-evidence/candidate-runtime/asset-ab-20261014/full-candidate/)
- [Quaternius 角色/载具隔离截图](../reference-evidence/candidate-runtime/asset-ab-20261014/quaternius-character-vehicle/)
- [MakeHuman 角色隔离截图](../reference-evidence/candidate-runtime/asset-ab-20261014/makehuman-character/)

代表性结果：

- [MakeHuman 办公室成功状态](../reference-evidence/candidate-runtime/asset-ab-20261014/makehuman-character/office-success-feedback.png)
- [MakeHuman office-10 近景构图候选](../reference-evidence/candidate-runtime/asset-ab-20261014/makehuman-character/office-10-close-candidate.png)
- [MakeHuman office-10 专用镜头修正候选](../reference-evidence/candidate-runtime/asset-ab-20261014/makehuman-character/office-10-dedicated-typing-final-pass.png)
- [MakeHuman office-10 专用镜头修正证据](../reference-evidence/candidate-runtime/asset-ab-20261014/makehuman-character/office-10-dedicated-typing-final-pass.json)
- [MakeHuman 城市人群状态](../reference-evidence/candidate-runtime/asset-ab-20261014/makehuman-character/city-crowd-variants.png)
- [完整候选办公室成功状态](../reference-evidence/candidate-runtime/asset-ab-20261014/full-candidate/office-success-feedback.png)
- [Quaternius 载具损伤状态](../reference-evidence/candidate-runtime/asset-ab-20261014/quaternius-character-vehicle/city-vehicle-damage-feedback.png)

## 质量判定

本轮没有任何候选资产获得最终视觉通过，原因是：

1. 完整候选环境不能保证固定镜头构图，直接替换会破坏玩家对场景的空间理解。
2. 初次复制 MakeHuman 候选时出现无效 UID 回退到文本路径的警告；随后在干净隔离副本中删除旧 `.godot` 与资产 `.import` 缓存，先执行无头编辑器导入预热，再运行真实图形采集，`office-10` 成功生成且日志不再出现 `invalid UID`、`SCRIPT ERROR` 或资源加载错误。该结果只解除“导入可重复性”这一候选阻塞，不提升视觉签收或发布状态，证据见 [`import-reimport-evidence.json`](../reference-evidence/candidate-runtime/asset-ab-20261014/makehuman-character/import-reimport-evidence.json)。
3. 本轮进一步修正了 MakeHuman `typing_default` 的视觉身体纵深挂点，并在完整候选包中重新生成 office-10 专用截图；角色已能稳定落在椅面上，但显示器仍遮挡键盘，手部接触无法从最终镜头稳定确认，因此仍为 `unverified`。临时隐藏显示器的实验只用于定位遮挡，不计入通过证据。
4. 角色、城市人群和载具的比例、动作、遮挡关系尚未在办公室、城市、载具上下车、碰撞损伤和任务收束场景中同时稳定。
5. 所有截图只证明候选运行时状态可见，不代表最终权利签收、目标 Windows 设备验证或 Steam 发布许可。
6. 完整候选办公室集成回放已经通过 MakeHuman 打字接触距离检查；后续定位发现默认三轮车位与左侧工位碰撞盒重叠，已将正式出生点移到安全通道，并重新生成候选包。当前统一回放已通过办公室入口、NPC 感知、上下车、驾驶位移、驾驶中存档恢复、退出载具和任务流程；视觉状态不受此项自动升级，仍为 `unverified`。
7. 本轮把候选工位的显示器向桌面左侧错开并略微缩窄，同时将键盘移到角色正前方；该改动只在视觉细节层，候选行为和资产接入契约仍已通过。由于当前 macOS Godot 图形采集器仍未进入采集脚本，尚未把这项构图改动计入视觉通过。

## 下一步

继续沿用“单槽位接入 → 固定镜头采集 → 行为回归 → 视觉审阅”的顺序。下一步是用真实可见窗口或 Windows 目标设备重采集 21 段矩阵，逐项确认新的显示器/键盘构图和手部接触；未通过前不修改正式 `asset-production-manifest.json` 的灰盒状态。当前旧 PNG 保留为历史待重采集证据，不强行改写源指纹。
