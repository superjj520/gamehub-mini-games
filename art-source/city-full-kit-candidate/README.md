# 城市完整候选包

这是一个仅用于接入验收的城市候选组合，不是最终资产包，也不会进入正式发布树。

它把已登记的玩家角色、三轮配送车、Quaternius Downtown 城市建筑和外置 MakeHuman 人群候选组合到真实 `city.tscn` 运行时，验证第三人称镜头、城市任务、行人路线、冲突对象、载具驾驶和城市环境不会因为替换视觉层而断裂。

人群场景通过 `city_crowd_makehuman_runtime_overlay.tscn` 使用 `res://../art-source` 资源路径直接加载，专门解决候选包不应依赖“复制进正式 assets 目录”的问题。测试只在候选源目录外置覆盖，不改变正式运行时源指纹。

当前状态：

- 已通过真实 Godot 城市运行时的完整候选组合接入测试。
- 已验证玩家、四名行人、冲突对象、三轮车、城市建筑、正式第三人称镜头和任务链路。
- 已新增后场仓储立面、卷帘门、装卸月台、配送货箱和后场生活道具候选，并通过节点挂载契约；这些节点只属于视觉层。
- 视觉仍为 `unverified`，未通过人工逐帧验收、目标 Windows 设备验收、碰撞精度验收和最终权利签收。

图形采集边界：无桌面/无头模式只能做导入和逻辑集成验证；`CITY_CANDIDATE_CAPTURE_HEADLESS=1` 不保证有可读的根视口纹理，不能把空图像当作视觉证据。需要 MovieWriter 时，桌面图形环境使用 `CITY_CANDIDATE_MOVIE_CAPTURE=1 CITY_CANDIDATE_MOVIE_VISIBLE=1`；锁屏或无图形后端仍应保留失败元数据，不得回填旧截图。
## 候选试玩入口

运行 `CITY_CANDIDATE_PREFLIGHT_ONLY=1 npm run playtest:candidate:city` 可只做临时运行时导入和集成预检。

运行 `npm run playtest:candidate:city` 会启动城市候选试玩窗口；候选资产只存在于临时运行时副本，关闭窗口后自动清理，不会写入正式资产目录或发布构建。
