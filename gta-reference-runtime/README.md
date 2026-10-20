# 参考还原基准

这是一个 Godot 4.7 的原创灰盒研发工程，用于验证两个本地参考视频对应的第三人称任务游戏运行时。产品基线已确认：新时代觉醒者、Steam Windows、办公室垂直切片、原创写实中等细节。

## 启动

```text
godot --path gta-reference-runtime
```

如果使用扁平内部源码试玩包，解压后在包根目录执行：

```text
godot --path .
```

如需在内部试玩中查看候选角色、办公室环境、城市建筑和三轮车，可显式启用候选资产目录；这不会改变默认灰盒入口，也不会进入正式 Windows 首发候选：

```text
REFERENCE_ASSET_CATALOG_PATH=res://tests/asset-runtime-catalog-override.json godot --path gta-reference-runtime
```

也可以开启启动器中的显式内部预览入口。开启后按 `3`，或选择“候选资产预览 · 办公室（仅内部）”，启动器会把隔离候选目录传给真实办公室场景；默认不显示该入口：

```text
REFERENCE_ASSET_PREVIEW=1 godot --path gta-reference-runtime
```

该入口只用于视觉评估，候选目录位于 `tests/`，不会改变默认灰盒入口，也不会进入 Windows 首发候选导出。

Windows PowerShell 写法：

```powershell
$env:REFERENCE_ASSET_PREVIEW = "1"
$env:REFERENCE_ASSET_CATALOG_PATH = "res://tests/asset-runtime-catalog-override.json"
godot --path gta-reference-runtime
```

启动入口可以选择：

- `准点下班`：办公室潜行、NPC感知、准点条件、失败与重试。
- `中国街区任务`：任务链、物品携带、三轮车、行人、冲突、追踪和城市存档。

启动入口由 `content/launch-profile.json` 驱动。当前首发范围为 `office_vertical_slice`，因此正式入口收窄为办公室任务；城市内容仍保留为内部扩展测试入口的实现基础，但不属于首发承诺。该文件不是平台导出配置，也不代表已经获得上架许可。

当前桌面输入：键盘 `WASD` 移动、方向键和鼠标控制第三人称镜头、`C` 蹲伏、`E` 交互、`R` 重试、`Esc` 暂停；手柄左摇杆移动、右摇杆镜头。手机网页测试入口会显示屏幕左下虚拟摇杆、右侧拖动镜头、蹲伏、交互、暂停和终态重试按钮；触控输入与桌面输入进入同一套任务状态机。

手机网页测试导出：

```text
godot --path gta-reference-runtime --export-release "新时代觉醒者 手机网页测试" build/mobile-web/index.html
```

导出后需要通过 HTTP 服务访问 `build/mobile-web/`，不能直接用 `file://` 打开；手机与电脑处于同一网络时，可用电脑局域网地址访问。当前网页测试只覆盖办公室垂直切片，不代表 Android/iOS 商店包已经完成。

## 自动化验证

推荐使用单条全量验证脚本：

```text
从工作区根目录执行：npm run test:reference
```

全量验证会同时生成平台无关的候选构建清单 `docs/release-manifest.json`。该清单记录源文件指纹、内容包版本和权利边界；即使产品基线和首发平台已经确认，在最终资产、视觉签收、目标设备回归和商店门禁完成前仍保持 `internal_no_go`，不代表可发布导出包。

视觉逐段人工复核面板：

```text
从工作区根目录执行：npm run visual:dashboard
输出：reference-evidence/runtime-matrix/visual-review-dashboard.html
```

正式发布前置检查：

```text
从工作区根目录执行：npm run release:preflight
```

当前该命令应当失败并列出阻断项；只有产品基线、最终资产、视觉矩阵、平台、权利和商店门禁全部完成后才允许通过。

也可以从工作区根目录单独运行以下测试：

```text
godot --headless --path gta-reference-runtime --editor --quit
godot --headless --path gta-reference-runtime -s res://tests/launcher_integration_test.gd
godot --headless --path gta-reference-runtime -s res://tests/smoke_test.gd
godot --headless --path gta-reference-runtime -s res://tests/office_integration_test.gd
godot --headless --path gta-reference-runtime -s res://tests/city_integration_test.gd
godot --headless --path gta-reference-runtime -s res://tests/city_conflict_integration_test.gd
```

## 研发边界

- 当前版本是开发基准版，不是上架版本。
- 当前只使用原创灰盒几何体、程序化 UI 和隔离的 P0 候选角色夹具。
- 参考视频只用于行为、镜头、流程和 HUD 验收，不进入游戏或商店发布包。
- 最终角色、动画、音频、场景和平台导出仍需单独验收。
- 当前 `launch-profile.json` 只负责产品范围到场景入口的映射；Steam Windows 导出模板、商店材料和真实设备回归仍需单独完成。

## 资产接入约定

单位、朝向、原点、目录、性能预算和导入检查见工作区文档：[3D 资产管线约定](/Users/superjj/gamehub-mini-games/docs/3d-asset-pipeline-conventions.md)。最终资产进入运行时前必须完成权利登记、尺寸/原点检查和真实交互回放。
