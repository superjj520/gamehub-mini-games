# 视觉逐项对照工具

`tests/visual_compare.gd` 用于把本地参考帧与运行时截图统一到参考帧尺寸，输出可审计的像素级对照指标：

- 参考帧和运行时截图的 SHA-256。
- 原始尺寸和实际比较尺寸。
- 完全一致像素比例。
- RGB 通道误差不超过 8 个等级的像素比例。
- 平均通道误差和最大通道误差。

工具只输出证据，不会自动把视觉状态改成通过。只有完成构图、镜头、角色、环境、HUD、动作节奏和版权检查后，才能由人工把对应分段从 `unverified` 改成 `passed`；通过时必须同时填写 `visual_review.reviewer`、规范 UTC 时间 `visual_review.reviewed_at`（例如 `2026-10-06T12:34:56.000Z`，不得为未来时间）和 `visual_review.method`，审阅方式使用 `manual_frame_review` 或 `manual_device_review`。另外必须绑定参考帧 SHA-256、当前运行时源指纹，`decision` 必须为 `passed`，`findings` 必须为空；截图哈希必须与当前运行时矩阵一致。行为标记为 `passed` 时也必须绑定回放审阅人、`replay_id`、审阅方式和当前源指纹。

推荐使用 `npm run review:visual -- --segment office-01 --reviewer "审阅人或团队" --method manual_frame_review --reviewed-at 2026-10-06T12:34:56.000Z` 先生成不写入的签收预览；只有真实完成该分段人工复核后，才允许追加 `--write`。工具不会自动替用户判断画面是否达到 100% 还原。

视频样本之外的扩展状态使用独立入口，不得借用 21 段参考验收的通过状态：

```bash
npm run review:visual:expansion -- --id city-crowd-variants --reviewer "审阅人或团队" --method manual_device_review --device "Windows 11 / 1920x1080 / 显卡型号" --reviewed-at 2026-10-10T12:34:56.000Z --decision passed
```

该命令默认只输出预览；只有完成真实运行时截图、目标设备对照和人工判断后才追加 `--write`。不通过时必须追加至少一个 `--finding`，例如 `--finding "人群轮廓仍互相遮挡，需要降低密度"`。工具会绑定扩展截图哈希和源指纹，源指纹过期或截图哈希不一致时拒绝写入。

当前 21 段可视化复核面板可用以下命令生成：

```text
npm run visual:dashboard
```

输出位置：`reference-evidence/runtime-matrix/visual-review-dashboard.html`。面板中的勾选框只是人工审阅记录，不会改写 `manifest.json` 或对比报告。

示例：

```text
./scripts/compare_visual_evidence.sh \
  reference-evidence/video-2/office-01.jpg \
  reference-evidence/runtime-captures/office-test.png \
  reference-evidence/runtime-captures/compare-reports/office-01.json
```

行为回放签收使用：

```text
npm run review:behavior -- \
  --segment office-04 \
  --reviewer "行为验收负责人" \
  --replay-id "office-04-replay-20261006" \
  --method automated_replay
```

行为工具同样默认只预览；只有完成真实回放审阅后才允许追加 `--write`。它会检查当前事件轨迹、声明事件、输入计数和运行时源指纹，再写入 `behavior_review`，不会因为事件轨迹存在就自动把 `graybox` 提升为 `passed`。

由于当前运行时截图仍是原创灰盒，生成的报告只能证明差异存在，不能作为视觉通过证据。
