# 图形采集环境诊断记录

日期：2026-10-15  
产品：新时代觉醒者  
当前运行时源：`0e417fdb5ef529d43968a5c9aece7a2441ebf1ef727845b294146bf96345a532 / 257`

## 已验证事实

1. `/Applications/Godot.app/Contents/MacOS/Godot` 文件存在，是包含 arm64 与 x86_64 的有效 Mach-O 二进制。
2. `godot --version` 可以返回 `4.7.1.stable.official.a13da4feb`。
3. 对原始应用包执行代码签名校验返回：签名无效（代码或签名已被修改）。
4. 使用 `open` 启动原始应用包返回 macOS `kLSNoExecutableErr`，因此 LaunchServices 入口不可用。
5. 直接启动原始二进制时，Godot 输出 `com.apple.hiservices-xpcservice` 连接无效，并在 90 秒内没有生成采集进度或 PNG。
6. 将应用复制到临时目录、移除原签名并使用临时签名后，直接启动仍以退出码 134 结束，没有生成采集进度或 PNG。
7. 原始 `/Applications/Godot.app` 没有被修改；当前正式矩阵没有写入新的图形证据。

## 当前结论

这是当前 macOS 图形运行环境问题，不是项目源码指纹、候选资源目录或行为回放问题。正式图形门禁继续保持阻断：当前源有效 PNG 为 `0/21`，视觉状态保持 `unverified`。

## 复现入口

失败记录保存在 `reference-evidence/candidate-runtime/graphical-capture-failure-*.json`。采集脚本支持显式设置 `GODOT_BIN`，并记录实际可执行文件和完整参数：

```bash
GODOT_BIN=/opt/homebrew/bin/godot npm run capture:reference:editor:original-only
```

在 Windows 10/11 目标设备上，应优先使用 `docs/windows-device-qa-runbook.md` 中绑定当前原创边界候选构建的采集流程。任何新 PNG 在人工逐帧复核前都只能保持 `unverified`。

