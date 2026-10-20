# 人物资产来源筛选与生产决策

日期：2026-10-07  
适用范围：`player-character`、`office-npc-set`、`city-crowd-set`

## 结论

目前没有发现一个可以直接满足“参考视频级别写实度、商业发布权利、完整游戏动画、稳定导出、单人零预算”的现成开源人物包。

当前最稳妥的生产路线是：

```text
有明确权利的基础人物
→ 原创服装、背包、胸牌和材质
→ 独立动作来源与重定向
→ Godot 导入、挂点、碰撞和状态机验收
→ 固定镜头逐项视觉签收
```

任何来源都不能绕过最后的视觉验收；“开源”只解决部分权利和生产成本问题，不等于符合参考画面。

## 候选对照

| 候选 | 权利/来源 | 已确认能力 | 当前风险 | 决策 |
|---|---|---|---|---|
| MakeHuman 社区资产包 + MPFB2 | MakeHuman 核心与系统资产按当前登记为 CC0；MPFB2 是制作工具，源码授权单独处理 | 能生成男性基础人物、皮肤、服装和骨骼；当前候选已通过隔离 Godot 导入和状态桥接 | 官方文档说明 MakeHuman 本身没有正式人物动画支持；本机 Blender 5.2.0 Metal 初始化崩溃；当前服装和近景比例仍不够 | 保留为首选基础人物来源，但不直接发布，继续走隔离候选链 |
| MB-Lab | 工具仓库为 GPL-3.0；模型/附加资产必须逐包核对，不能把工具许可证当作人物资产许可证 | 有人体比例、面部和骨骼生成能力，适合制作参数化基础人物 | 当前 Blender 环境同样可能触发图形后端问题；需要单独核对每个模型和资产包的商业发布范围 | 作为备用制作工具候选，不下载、不接入正式运行时，除非完成权利和导出验证 |
| Quaternius CC0 基础人物 | 已登记 CC0 来源 | 导入、骨骼、服装覆盖和运行时状态桥接稳定 | 低面数和卡通比例与参考近景差距大 | 继续作为行为/挂点/动画接口基准，不作为最终写实角色 |
| OpenGameArt CC0 人物 | 可找到 CC0、带骨骼的基础人物 | 成本低，适合原型 | 公开候选多为风格化低面数，不符合当前参考的男性近景和写实服装 | 仅作为动画/骨骼实验备用，不作为视觉主路线 |
| Blender Studio 工具链 | 官方强调是开源生产管线 | 适合规范 Blender 项目、资产导出和协作 | 它是工具与管线文档，不是可直接发布的人物资产；不能解决本机 Blender 崩溃 | 只借鉴管线规范，不作为人物来源 |

## 已核对的外部证据

- MakeHuman 官方资产包文档说明 MPFB2 用户需要系统资产包，并持续提供服装、头发、姿势等资产包：[MakeHuman Asset Packs](https://static.makehumancommunity.org/assets/assetpacks.html)。
- MakeHuman 官方导出文档说明 MakeHuman 本身没有正式的人物动画支持，动画通常需要其他程序或动作来源：[Exports and File Formats](https://static.makehumancommunity.org/makehuman/docs/exports_and_file_formats.html)。
- MB-Lab 项目公开说明其是 Blender 人物创建工具，仓库包含 GPL-3.0 许可证；这证明工具可审计，不等于所有生成内容或附加资产自动获得同一发布许可：[MB-Lab GitHub](https://github.com/animate1978/MB-Lab)。
- Blender Studio 官方文档定位为基于 Blender 的开源生产管线，而不是现成的游戏人物库：[Blender Studio Tools](https://studio.blender.org/tools/)。

## 对当前项目的实际影响

1. 不再把“继续找一个现成免费人物”当成主要解决方案；现有 MakeHuman 候选已经证明，人物质量仍需要服装、面部、动作和镜头级返工。
2. 不把 MPFB2 或 MB-Lab 的工具源码复制进游戏发布包；只保留生成结果、许可证副本、来源哈希和生成记录。
3. 下一次人物生产优先验证“稳定导出与动作重定向”，然后再做服装细节；如果基础人物仍无法通过近景验收，就放弃该候选，不进入正式运行时。
4. Quaternius 继续承担行为和挂点基准，MakeHuman 继续承担写实比例候选；两者都保持 `visual_status=unverified`，不改变 `release_allowed=false`。

## 下一次验收门槛

新的候选必须同时满足以下证据，才允许进入用户视觉评审：

- 生成过程不依赖当前已知会崩溃的 Blender Metal 初始化路径，或已在隔离环境复现成功。
- GLB 在 Godot OpenGL Compatibility 下稳定加载，且能驱动 `idle_default`、`walk_default`、`search_default`、`alert_default`。
- 至少生成办公室近景、侧面行走和背包交互三张真实图形截图。
- 服装、人物比例、背包、头发、手臂和动作与参考帧逐项记录差异；没有截图就保持 `unverified`。
- 完成来源、许可证、生成工具、文件哈希和目标平台导入记录。
## 2026-10-07 新增办公室工位候选

- `Poly Haven Metal Office Desk`：官方页面明确标注 CC0，提供 glTF/纹理和官方文件接口；适合作为办公室近景工位候选。
- 工程处理：保留官方 1K glTF 与纹理，另生成带切线、内嵌纹理的 GLB；原始文件哈希、转换后哈希、导入测试和封装场景均已登记。
- 当前判断：进入 `office-environment-kit` 候选池，不得直接替换正式灰盒；还需要真实办公室挂载、遮挡/碰撞、固定镜头截图、Windows 设备性能和最终权利复核。
