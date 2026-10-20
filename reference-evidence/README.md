# 参考证据库

这里保存两个外部视频的内部原始副本与抽帧证据，只服务于参考行为、镜头、构图和 HUD 的逐项验收。

- `video-1/video-1-china-gta-480.mp4` 与 `video-2/video-2-off-work-480.mp4` 是本项目内的原始证据副本；`manifest.json` 同时保留原始下载路径，便于核对来源。
- `manifest.json` 记录本地证据路径、来源链接、时长、帧率、分辨率、文件大小、视频/音频流元数据、分段、代表时间和估算帧号。
- `manifest.json` 同时记录两个本地原始视频和每张代表帧的 SHA-256；权利检查会在来源文件存在时逐一复核。
- `node scripts/verify_reference_media.mjs` 会复核本地视频存在性、源文件 SHA-256、文件大小、H.264/AAC 单声道流登记、分段时间边界和抽帧 SHA-256。
- `runtime-matrix/manifest.json` 记录 21 个对应运行时状态截图及其 SHA-256，并绑定当前 `gta-reference-runtime` 源文件指纹；这些截图只是视觉验收输入，全部保持 `unverified`。
- 运行时代码变化后，必须先用图形 Godot 重新执行 `tests/reference_capture_matrix.gd`，复制当前 PNG，再执行 `node scripts/sync_runtime_matrix_manifest.mjs` 和视觉对比报告生成；矩阵门禁会拒绝源指纹过期的截图。
- `video-1/` 是城市任务视频的分段代表帧。
- `video-2/` 是办公室视频的分段代表帧。
- 原始视频、代表帧和可玩背景编辑版均为 `reference_only` 或 `internal_candidate_only`，不得进入游戏发布包、商店截图、宣传片或最终美术资产。
- 每张代表帧的 SHA-256 已记录在 `manifest.json`，验收脚本会拒绝文件替换或内容漂移。

代表帧是低码率视频的抽样证据，不等于原始视频的像素级基准。获得原始分辨率或授权素材后，必须重新抽帧并更新清单。
