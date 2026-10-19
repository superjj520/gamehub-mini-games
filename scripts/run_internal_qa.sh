#!/usr/bin/env zsh
set -euo pipefail

# 单人研发的内部质量入口：验证当前源可以继续迭代，但不把内部通过
# 误报为视觉通过、最终资产通过或可发布。
print "《新时代觉醒者》当前版本内部质量验收开始"
print ""

run_step() {
  local label="$1"
  shift
  print "[内部验收] $label"
  "$@"
  print "[内部验收] $label：通过"
  print ""
}

run_report_step() {
  local label="$1"
  shift
  print "[阻断报告] $label"
  "$@"
  print "[阻断报告] $label：已生成并完成结构验证；不代表发布通过"
  print ""
}

run_step "产品基线" npm run verify:product-baseline
run_step "参考视频证据库" npm run verify:reference-media
run_step "原创生成位图来源证据" npm run verify:bitmap-provenance
run_step "原创边界运行时目录" npm run verify:asset-catalog:original-only
run_step "权利来源登记" npm run verify:rights-provenance
run_step "原创程序化音频候选生成" npm run build:audio-library
run_step "原创程序化音频格式" npm run verify:audio-library
run_step "原创程序化音频证据" npm run verify:audio-candidate

# 音频清单属于正式运行时源的一部分。音频生成、源码变更或 Godot 导出后，
# 旧的行为证据、候选包、Windows QA 包和审阅包都可能仍绑定上一版指纹；
# 内部 QA 必须自己完成这一轮同步，不能依赖人工按顺序补产物。
run_step "刷新当前行为证据" npm run test:behavior:current
run_step "刷新扩展行为证据" npm run test:expanded-behavior
run_step "刷新候选发布清单" npm run release:manifest
run_step "刷新内部候选树" npm run release:candidate
run_step "刷新完整候选包" npm run package:candidate:full
run_step "刷新原创角色候选包" npm run package:candidate:full:original
run_step "刷新原创边界候选包" npm run package:candidate:full:original-only
run_step "刷新完整候选 Windows 导出" npm run export:candidate:windows
run_step "刷新原创角色候选 Windows 导出" npm run export:candidate:windows:original
run_step "刷新原创边界候选 Windows 导出" npm run export:candidate:windows:original-only
run_step "刷新完整候选 Windows QA 包" npm run package:candidate:windows:qa
run_step "刷新原创角色候选 Windows QA 包" npm run package:candidate:windows:qa:original
run_step "刷新原创边界候选 Windows QA 包" npm run package:candidate:windows:qa:original-only
run_step "刷新办公室审阅包" npm run package:p0-office-review
run_step "刷新城市审阅包" npm run package:city-candidate-review

# 发布准备报告必须先刷新当前源，再执行证据绑定；否则源码变更后会把上一版报告误判为绑定失败。
run_report_step "刷新发布准备报告" npm run release:readiness
run_step "当前源证据绑定" npm run verify:evidence-binding
run_step "当前行为矩阵" npm run test:behavior:current
run_step "扩展行为矩阵" npm run test:expanded-behavior
run_step "原创边界候选预检" env FULL_CANDIDATE_PREFLIGHT_ONLY=1 npm run playtest:candidate:full:original-only
run_step "原创边界候选包身份" npm run verify:candidate:full:original-only
run_step "原创边界 Windows 构建身份" npm run verify:candidate:windows:original-only
run_step "原创边界 Windows QA 包身份" npm run verify:candidate:windows:qa:original-only
run_step "办公室候选配置" npm run verify:candidate:office:configuration
run_step "城市候选配置" npm run verify:candidate:city:configuration
run_step "功能全量回归" npm run test:reference:functional
run_step "候选表现层契约" npm run test:visual-candidate-contract
run_step "图形收口安全拒绝契约" npm run test:finalize:reference:capture
run_step "主机性能烟测" npm run test:performance
run_report_step "要求追踪矩阵" npm run traceability:requirements
run_report_step "发布阻断面板" npm run audit:release-dashboard
run_report_step "提交证据索引" npm run submission:evidence-index
run_report_step "运行时事件缺口报告" npm run trace:gap-report
run_step "运行时事件缺口门禁" npm run verify:trace:gap-report
run_report_step "图形采集准备度" node scripts/verify_graphical_capture_readiness.mjs

print "内部质量验收通过：当前版本可继续研发和内部试玩。"
print "发布状态仍以 docs/readiness-report.json 和 docs/release-blocker-dashboard.json 为准。"
print "任何视觉、权利、目标设备和 Steam 前置阻断都不会被本入口豁免。"
