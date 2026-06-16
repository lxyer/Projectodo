// 创作中枢 · 意图②「查任务」(单意图 · 对应脚本 S4"今天有哪些任务"+二楼扔手机梗)
// 校验点同 RecordIdeaIntent 头部注释。

import { InsightIntentEntryExecutor, insightIntent, InsightIntentEntry } from '@kit.AbilityKit';
import { CreationHub, TaskBrief } from '../service/CreationHub';

class QueryTasksResultDef {
  public msg?: string = '';
}

@InsightIntentEntry({
  intentName: 'QueryTasks',
  domain: 'CreationHubDomain',
  intentVersion: '1.0.1',
  displayName: '查任务',
  displayDescription: '查今天有哪些项目节点到期、归谁负责',
  llmDescription: '当用户问"今天有哪些任务/今天要干什么/项目进度"时调用；返回今日到期与逾期节点及负责人',
  keywords: ['今天有哪些任务', '查任务', '今天要干什么', '项目进度', 'QueryTasks'],
  icon: $r('app.media.layered_image'),
  abilityName: 'EntryAbility',
  executeMode: [insightIntent.ExecuteMode.UI_ABILITY_BACKGROUND],
  parameters: {
    'type': 'object',
    'description': '查询任务',
    'properties': {
      'scope': {
        'type': 'string',
        'description': '查询范围，默认 today（今天）'
      }
    }
  }
})
export default class QueryTasksImpl extends InsightIntentEntryExecutor<QueryTasksResultDef> {
  public scope?: string = 'today'; // 意图参数自动注入

  async onExecute(): Promise<insightIntent.IntentResult<QueryTasksResultDef>> {
    const brief: TaskBrief = CreationHub.queryTasks(this.scope ?? 'today');
    const ok: insightIntent.IntentResult<QueryTasksResultDef> = {
      code: 0,
      result: { msg: brief.text }
    };
    return ok;
  }
}
