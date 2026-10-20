#!/bin/zsh
# 强制使用无窗口、兼容渲染路径，规避 macOS Vulkan/MoltenVK 图形服务崩溃。
exec godot --headless --display-driver headless --rendering-method gl_compatibility "$@"
