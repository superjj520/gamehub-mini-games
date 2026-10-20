# 原创主角模型候选

`original_player_visual_v1.glb` 是本项目原创代码生成的主角视觉候选，服务于《新时代觉醒者》的角色比例、服装层次、背包和材质分层预览。

## 生成与边界

- 生成器：`../build_original_player_glb_fallback.mjs`
- 生成方式：项目内 `@gltf-transform/core` 纯 Node 生成，不依赖第三方网格、纹理或参考视频像素。
- 候选状态：`candidate_only`、`visual_status=unverified`、`release_allowed=false`。
- 参考板：`../new-era-awakener-player-turnaround-v1-generated.png` 只作为建模比例和服装层次参考，不作为运行时贴图。
- 正式运行时：当前未替换 `gta-reference-runtime` 的正式角色来源，也未改变发布包边界。

## 已完成的结构验证

- GLB 文件可由 `@gltf-transform/core` 重新读取。
- 结构包含 44 个节点、43 个网格、12 个材质和 10668 个三角面。
- 模型包含身体、夹克、红色内层、脸部、头发、手臂、手、工装裤、鞋、背包、肩带、口袋和胸牌等分层节点。
- 已在 Godot 4.7.1 的隔离测试目录实际导入，通过 `original_player_glb_import_test.gd` 验证 43 个网格和 12 个材质可实例化。

## 尚未完成

1. 在可见 Godot 窗口中完成固定镜头采集。
2. 接入角色骨骼、动画状态和碰撞契约。
3. 在 Windows 目标设备验证材质、性能、输入和导出包。
4. 逐帧对照参考证据并由负责人签收视觉结果。

