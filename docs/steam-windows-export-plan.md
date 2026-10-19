# Steam Windows 导出准备单

版本：`0.1.0-dev`

状态：产品基线已确认，平台导出待工具链与目标设备验证。

当前运行时源码：`99953a23ef72af940d5089e8faff36db816769c3ab5234379d23c62a2cedb50f / 305`。
当前可交付的是原创边界内部候选，不是 Steam 上传包；真实 Windows 设备、视觉签收、最终资产权利和运营主体仍未完成。

## 已冻结的目标

- 平台：Steam Windows
- 设备：Windows 10/11，1080p，键鼠与手柄
- 首发范围：办公室垂直切片
- 商业化：首发免费测试版，不接真实支付
- 发布包：只包含原创可发布资产，不包含参考视频、抽帧、内部验收证据和未授权资产

## 当前可验证事实

- Godot 运行时可在本机启动，办公室任务行为回放通过。
- 21/21 行为分段通过；视觉分段仍需人工签收。
- 工程已加入 `新时代觉醒者 Windows 内部测试` 导出预设，目标架构为 `x86_64`，窗口基准为 1280×720。
- 已安装官方 Godot 4.7.1 Windows x86_64 Debug/Release 模板，并成功生成 `build/windows/新时代觉醒者.exe` 与排除测试目录的 `build/windows/新时代觉醒者-首发候选.exe`；构建物均已通过 PE x86_64 结构检查。
- 构建物和模板哈希记录在 `docs/windows-build-manifest.json`；当前构建仍未在 Windows 10/11 目标设备启动，因此不能标记为设备通过或 Steam 可上传。
- `npm run verify:windows-build-manifest` 会核验两个 Windows 构建的体积、SHA-256、PE x86_64 结构、运行时源指纹和 Godot 导出模板哈希；它只证明构建物可追溯，不替代 Windows 真机回归。
- 当前候选树是平台无关源码树，不是 `.exe`、Steam depot 或商店上传包。
- 本机已经形成带体积、SHA-256、PE 结构、源指纹和模板哈希的可追溯 Windows 导出物；这些静态证据仍不能替代目标设备验收。
- 产品基线要求 `original_assets_only`；因此当前人工平台验收入口应使用 `新时代觉醒者-原创边界候选.exe` 及其独立构建清单，包含其他候选变体的完整包只用于内部技术对照，不得作为首发版权边界结论。
- 当前原创边界候选 QA 包：`build/新时代觉醒者-原创边界候选-windows-qa.zip`；对应构建清单和 SHA-256 以 `reference-evidence/candidate-runtime/full-candidate-windows-original-only-build.json` 与 `reference-evidence/candidate-runtime/full-candidate-windows-original-only-qa-bundle.json` 为准。

## 导出前必须完成

1. 在受控环境安装并锁定与 Godot 4.7.1 匹配的 Windows export templates。
2. 建立只包含办公室首发入口的 Windows export preset，并记录模板版本和构建机信息。
3. 生成 Windows 构建后，在干净 Windows 10/11 机器完成启动、分辨率、键鼠、手柄、暂停、存档和异常退出恢复测试。
4. 记录帧时间、内存、加载时间、窗口缩放、字体、音频和输入设备证据。
5. 用最终资产重新采集首发范围截图，并由人工完成视觉逐项签收。
6. 运行发布前置检查，确认状态从 `internal_no_go` 变为 `release_go` 后，才允许准备 Steamworks 上传。

## 明确禁止

- 不把没有 Windows 目标设备证据的源码包标为 Steam 版本。
- 不把灰盒、候选角色夹具或未登记权利的资产放入商店构建。
- 不把参考视频、抽帧、调试日志或内部视觉对照图放入发布包。
- 不在真实支付、账号、广告或分析接入未完成隐私审查前加入商业化 SDK。

## 当前阻断

```text
最终角色、环境、动画、音频和载具资产：未完成
21/21 参考视觉分段人工签收：未完成
扩展视觉验收：未完成
Windows export templates：已安装并验证 Godot 4.7.1 Windows x86_64 Debug/Release 模板
Windows 目标设备回归：未完成
Steam 商店材料与上传：未开始
```

这份文件允许我们从现在开始准备导出契约，但不把“准备”误报为“已导出”或“可上架”。
