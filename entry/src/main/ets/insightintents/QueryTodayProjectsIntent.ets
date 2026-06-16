// 创作中枢 · 意图⑦「今天有哪些项目」（"今天有哪些项目要推进"）
import { InsightIntentEntryExecutor, insightIntent, InsightIntentEntry } from '@kit.AbilityKit';
import { CreationHub, TaskBrief } from '../service/CreationHub';

class QueryTodayProjectsResultDef {
  public msg?: string = '';
}

@InsightIntentEntry({
  intentName: 'QueryTodayProjects',
  domain: 'CreationHubDomain',
  intentVersion: '1.0.1',
  displayName: '今日项目',
  displayDescription: '查今天有哪些项目要推进',
  llmDescription: '当用户问"今天有哪些项目、今天要推进什么、今天的项目"时调用',
  keywords: ['今天有哪些项目', '今天要推进什么', '今天的项目', 'QueryTodayProjects'],
  icon: $r('app.media.layered_image'),
  abilityName: 'EntryAbility',
  executeMode: [insightIntent.ExecuteMode.UI_ABILITY_BACKGROUND],
  parameters: {
    'type': 'object',
    'description': '查今日项目',
    'properties': {}
  }
})
export default class QueryTodayProjectsImpl extends InsightIntentEntryExecutor<QueryTodayProjectsResultDef> {
  async onExecute(): Promise<insightIntent.IntentResult<QueryTodayProjectsResultDef>> {
    const brief: TaskBrief = CreationHub.queryTodayProjects();
    const ok: insightIntent.IntentResult<QueryTodayProjectsResultDef> = {
      code: 0,
      result: { msg: brief.text }
    };
    return ok;
  }
}
