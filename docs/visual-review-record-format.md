# 人工视觉复核记录

参考视觉看板现在可以导出一份 `visual-review-record.json`。它只记录人工判断，不会自动把任何画面标记为通过。

使用流程：

1. 运行 `npm run visual:dashboard`，打开 `reference-evidence/runtime-matrix/visual-review-dashboard.html`。
2. 逐项对照参考帧与当前运行时截图，填写审阅人、审阅方式、UTC 时间和每段结论。
3. 通过项必须没有差异与返工项；不通过项必须填写具体差异。
4. 导出记录后，先预览严格应用结果：

```text
npm run review:visual:apply -- --file /绝对路径/visual-review-record.json
```

5. 确认记录确实来自真实人工复核后，才允许写入：

```text
npm run review:visual:apply -- --file /绝对路径/visual-review-record.json --write
```

写入后必须运行 `npm run verify:visual-matrix` 和 `npm run test:reference`。记录必须覆盖全部 21 个分段，并绑定当前运行时源指纹；遗漏、未来时间、截图哈希变化或重复签收都会被拒绝。

如果已经通过的画面需要返工，必须显式追加 `--allow-reset`，不能静默撤销视觉通过状态。当前视觉仍以 `unverified` 为真实状态，任何机器像素差异都不能替代人工判断。
