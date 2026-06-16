---
name: creation-hub
description: 创作中枢——把"灵感→立项→排期→通知→查询→复盘"编排成一句话就能完成的组合拳。当用户想一次性推进内容生产流程、而不是只做单个动作时调用。
license: demo
metadata:
  version: 1.0.0
  domain: CreationHubDomain
---

> ⚠️ 草案：编排设计 + 意图序列已定。具体 SKILL.md 运行时格式（exec-cli 契约 / scriptManager）由华为工程师明天按 HarmonyOS 7.0 应用 Skill 框架(API26)落地，本文件提供完整编排逻辑，照填即可。
> 已就绪的 8 个原子意图见 entry/src/main/insight_intent.json。

## 触发场景（小艺听到这些 → 调本 Skill 编排，而非单意图）

- "把 XX 灵感立项，下周三发" / "XX 这个想法，开干" → 调 Skill A
- "我今天该干嘛" / "今天的作战计划" / "盘一下今天" → 调 Skill B
- "XX 项目进度怎么样，催一下慢的" / "XX 项目冲刺" → 调 Skill C

不调用（用单意图即可）：只记一条灵感（RecordIdea）、只查一下灵感（QueryIdeas）。

---

## Skill A · 一句话立项（编排 5 个意图）

**一句话**："小艺，把'第一视角开箱'这条灵感立项，下周三发布。"

**编排序列**：
1. `QueryIdeas`(keyword="第一视角开箱") — 在灵感库定位这条灵感
2. `CreateProjectFromIdea`(ideaName) — 建项目
3. （排期）按"下周三发布"倒排 4 个节点：发布=周三，初稿=周一，脚本=上周六，大纲=上周五
4. `NotifyAllInProject`(projectName) — 一次通知编导/剪辑/运营
5. `QueryTasks`(scope=today) — 回播：今天因此新增了哪些待办

**震撼输出**："灵感已立项为《第一视角开箱》。按周三发布倒排了 4 个节点，编导今天就要出大纲。3 位同事已通知。今天你的待办+1。"

> 看点：一句话 = 查找+建项目+智能倒排+群发通知+回播，5 个意图一气呵成。

---

## Skill B · 每日作战室（编排 4 个意图）

**一句话**："小艺，我今天该干嘛？"

**编排序列**：
1. `QueryTodayProjects` — 今天要推进哪几个项目
2. `QueryTasks`(scope=today) — 今天到期/逾期的节点
3. `QueryTasksByOwner`(编导/剪辑/运营) — 各岗位今天分到多少
4. （汇总）生成"今日作战清单"+ 风险提示（逾期）

**震撼输出**："今天 3 个项目在跑，5 个节点到期：编导 2 个、剪辑 2 个、运营 1 个。其中《开箱》的脚本已逾期 1 天，建议先催。"

> 看点：一句日常问话，背后把项目维度、任务维度、人员维度三张表交叉汇总。

---

## Skill C · 项目冲刺（编排 4 个意图）

**一句话**："小艺，《第一视角开箱》进度怎么样？把拖后腿的催一下。"

**编排序列**：
1. `QueryTasksByOwner` / 项目节点扫描 — 取该项目全部节点状态
2. （识别）筛出逾期 + 今日到期节点
3. `NotifyAllInProject`(projectName) — 催相关负责人
4. （回播）项目健康度 + 已催谁

**震撼输出**："《第一视角开箱》4 个节点，2 个逾期：脚本（编导）、初稿（剪辑）。已各催一遍。发布节点还有 3 天，来得及。"

> 看点：一句话完成"查进度→诊断风险→精准催办→回报"，像有个项目助理。

---

## 给华为工程师的落地说明
- 原子意图全部就绪并注册（8 个，见 insight_intent.json）。
- 本 Skill 要做的是"意图路由 + 编排 + 输出整合"，即把上面每个序列用应用 Skill 框架的运行时串起来。
- 排期倒排（Skill A 第 3 步）、三维汇总（Skill B 第 4 步）、风险识别（Skill C 第 2 步）这几处编排逻辑，业务方法已在 CreationHub 备好或可快速加（findProjectIdByTitle / queryTasks / queryTasksByOwner / queryTodayProjects / notifyAllInProject）。
