# 原创程序化音频候选

本目录由 `build_audio_library.mjs` 按 `gta-reference-runtime/content/audio_cues.json` 确定性生成 12 个短音效，用于事件路由的内部候选试听。

- 不含第三方录音、采样、参考视频音频或受保护旋律。
- 采样格式为 22050 Hz、16-bit、单声道 PCM WAV。
- `audio-library-manifest.json` 记录每个文件的大小、哈希和生成器哈希。
- 当前只允许内部候选接入，仍需人工听感、混音、目标设备和最终发布复核。
