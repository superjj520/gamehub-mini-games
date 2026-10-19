# 原创交互道具候选包

状态：`candidate_only`，不可直接发布。

本包使用 Blender 脚本生成，不引用参考视频帧、品牌、商标或第三方网格，包含：

- 鸡蛋托盘与鸡蛋；
- 扫码台、扫码屏和状态灯；
- 交付标识柱与标识牌；
- 免费鸡蛋购物篮。

坐标遵循 1 单位等于 1 米、`+Y` 向上，根节点为 `InteractionPropsKit`，表现对象按 `EggTray_Interaction`、`ScanBoard_Interaction`、`DeliveryMarker_Interaction` 和 `ShopBasket_Interaction` 分组。它只承担表现层，不承担任务阶段、库存、奖励、碰撞或存档逻辑。

执行：

```bash
node build_interaction_props_glb.mjs
godot --headless --path . -s res://inspect_interaction_props_kit.gd
node run_isolated_runtime_integration.mjs
```

`build_interaction_props.py` 是可选的 Blender 源生成器；当前 macOS Blender 图形初始化可能发生工具级段错误，默认构建路径使用不依赖 Blender 启动的 Node.js GLB 构建器。

当前验收范围仅包括源脚本可复现、GLB 可导入、命名/单位/挂点契约和运行时隔离接入；固定镜头、动画音频、目标设备性能、人工视觉和最终权利签收仍未通过。

`run_isolated_runtime_integration.mjs` 会复制正式 `gta-reference-runtime` 到临时目录，挂载候选 GLB，验证城市 Visual 覆盖、鸡蛋交互、库存/任务推进、角色/镜头保持，以及完整城市任务回放；不会修改正式运行时目录。
当前 GLB 使用一个 512×512 内嵌颜色图集和一个共享材质，托盘、鸡蛋、扫码台、交付标识和购物篮仍按原节点命名导出；技术预算不超过 3 个材质槽，视觉、权利和目标设备状态仍保持未签收。
