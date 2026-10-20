# P0 主角候选审阅记录

日期：2026-10-07  
候选：`player-character-quaternius-cc0-candidate`  
源指纹：`8f260597a1c8c3a65514bb9979f68c7191bbe0bf46312aabdd17a1154a2811b2`

## 已验证

- Quaternius Universal Base Characters 来源页和 CC0 1.0 许可证已登记。
- 工程内基础 GLB 为可读取的 glTF 2.0，并已导出第一版独立原创服装 GLB，文件哈希为 `6480065557eac5304dd0a019fcaf72726605d5e6253bbd2c44fa0208ee715bd1`。
- 65 根骨骼已被 Godot 导入，运行时角色前进方向已按项目约定修正为局部 `-Z`。
- 独立 GLB 已包含原创夹克、肩部护片、衬衣、领口、腰部饰条、胸牌、背包、袖子、裤腿、鞋子和头发，并按骨骼绑定到角色骨架。
- `inspect_outfitted_asset.gd` 已验证独立 GLB 的骨架、必需骨骼和 15 个服装对象；运行时导入与演示动画均通过。
- `asset_runtime_integration_test.gd` 通过；办公室和城市的玩家资产覆盖均未改变灰盒回退和任务逻辑。
- `p0-candidate-office-01.png` 已由真实图形运行时重新生成。

## 未通过或待补

- 当前仍是风格化低面数基础网格和程序化服装覆盖，不满足最终“原创写实、中等细节”资产标准。
- 当前已完成骨骼父级关系和静态导入验收，但尚未完成完整行走、奔跑、蹲伏、交互和受击过程中的穿插、变形与材质验收。
- 仍缺少最终行走、蹲伏、交互、上车、受击和失败动画的完整制作与逐段验收。
- 目标 Windows 10/11 设备截图、内存和输入证据尚未完成。

## 结论

`integration_status=verified_in_isolated_asset_override_test`、`visual_status=unverified`、`release_allowed=false`。该候选允许继续用于真实运行时和镜头调校，但不能替代最终资产，也不能触发视觉通过或发布 Go。
