# 创作中枢 · 开发说明（2026-06-16 · 功能全堆版）

> B 站视频《手机上的 Skill》演示 demo。HarmonyOS 7.0 / API 26 / ArkTS。
> 一个完整的内容生产任务管理 App + 8 个意图 + Skill 编排，给小艺一句话调多意图。

## 文件结构
```
entry/src/main/
├── insight_intent.json                 # 8 个意图注册
├── skills/creation-hub/SKILL.md         # Skill 编排草案（给华为落地，3 组合拳）
├── ets/
│   ├── model/Models.ets                # @Observed 数据类 + 节点模板 + 状态色
│   ├── data/Store.ets                  # 内存数据仓 Hub
│   ├── service/CreationHub.ets         # 业务逻辑(记/查/转/通知/查询/统计/日程)
│   ├── pages/MainPage.ets              # ★主框架：4 Tab + 所有视图/组件/动效（单文件避免组件重名）
│   └── insightintents/                 # 8 个意图实现
│       ├── RecordIdeaIntent / QueryIdeasIntent / CreateProjectIntent
│       ├── NotifyAllIntent / QueryTasksIntent / QueryByOwnerIntent
│       └── QueryTodayProjectsIntent / UpdateNodeStatusIntent
```

## MainPage.ets 里有什么（4 个底部 Tab）
1. **今日**（TodayView）：4 个统计卡（灵感/项目/今日待办/已完成）+ 今日播报 + **番茄钟**（FocusCard·Progress Ring 倒计时·完成放彩屑）
2. **灵感**（IdeasView）：渐变标题卡 + 记灵感 + 灵感卡片（转项目）
3. **项目**（ProjectsView）：项目卡 + 节点(圆圈复选/截止日期/通知)+ 一键通知 + 岗位筛选 chips
4. **日历**（CalendarView）：按截止日期分组的日程

外加全局 **CelebrateLayer**（完成/立项/通知时彩屑庆祝 🎉🎊✨ + animateTo 飘落）+ **点击振动**（vibe）。

## 动效 / 反馈
- 彩屑庆祝：`AppStorage('celebrate')` + `@Watch` 触发 `animateTo`，emoji 上飘淡出
- 触觉：`vibrator.startVibration`（需 VIBRATE 权限，已加 module.json5；失败静默）
- 番茄钟：`setInterval` 倒计时 + `Progress` 环形

## ⚠️ 待 DevEco/CodeGenie 编译校验（这版新 API 多，AI 无法离线验证）
Tabs/TabContent/tabBar/barPosition · Progress(ProgressType.Ring) · AppStorage/@StorageLink/@Watch · animateTo/Curve · vibrator(@kit.SensorServiceKit)/startVibration 参数 · Circle.stroke/fillOpacity · translate/scale/decoration 对象 · HitTestMode/setInterval · 8 个意图装饰器 · icon 资源。
报错就按文件+行号逐个改，逻辑层（内存仓+@Observed 刷新）是稳的。

## 明天华为现场
1. 应用内 Skill 编排（按 skills/creation-hub/SKILL.md 的 3 组合拳落地 SKILL.md 运行时）
2. 小艺端到端联调（演示场景见脚本目录 00_小艺演示场景.md：一句话调 5/4/4 个意图）
3. 持久化：若意图后台进程要与 UI 跨进程共享数据，把内存 Hub 换 preferences

## 官方文档
- 装饰器开发意图：https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/insight-intent-decorator-development
- 应用 Skill 开发指南：https://gitcode.com/openharmony/docs/blob/master/zh-cn/application-dev/application-models/arkts-skill-development-guide.md
