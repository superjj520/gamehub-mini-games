# Poly Haven Metal Office Desk 候选

这是办公室环境的 P0 资产候选，不属于正式运行时或发布包。

- 来源：Poly Haven `metal_office_desk`
- 官方页面：https://polyhaven.com/a/metal_office_desk
- 官方文件接口：https://api.polyhaven.com/files/metal_office_desk
- 许可：CC0；仍需在进入最终发布包前完成本项目逐文件权利复核。
- 版本：官方 glTF 1K，模型约 7K 三角面，适合办公室近景工位候选。
- 为适配 Godot 无编辑器导入探针，另生成了内嵌纹理的 `metal_office_desk_1k.glb`；它是可复现的格式转换产物，不替代官方原始文件。
- 纹理：1K 漫反射、法线和 ARM，路径保持在 `textures/`，与 glTF 相对引用一致。
- 已用 `gltf-transform tangents` 生成切线，最终候选 GLB 的 glTF 校验为“无错误、无警告”。
- 已完成候选场景封装：运行时根节点 `Visual`、内部 `Geometry`、近似碰撞体、`交互挂点` 和 `显示器挂点`，并通过隔离 Godot 场景测试。
- 已完成 5 工位办公室组合探针，包含玻璃隔断、显示器、办公椅、固定审阅镜头和灯光；组合仍未接入正式任务场景。
- 已新增嵌入式完整环境覆盖目录 `asset-runtime-catalog-office-full-kit-override.json`：在真实办公室运行时中挂载 5 个工位时不创建自己的固定镜头，不抢占正式第三人称相机；加固契约测试已验证任务、NPC、玩家、内容包、碰撞和挂点保持完整。
- 已在隔离运行时镜像中通过真实办公室单工位和五工位覆盖测试；候选仍未进入正式运行时资产槽位。
- 候选截图入口使用 `candidate_capture_guard.gd`，输出只允许进入候选目录，并强制写入 `candidate_only=true`、`visual_status=unverified`、`formal_acceptance=false` 元数据。

当前已完成官方来源读取、文件哈希登记、glTF 文件结构检查和隔离 Godot 运行时接入；尚未通过固定镜头视觉验收、碰撞精度验收、目标设备性能验收或最终发布权利签收。
