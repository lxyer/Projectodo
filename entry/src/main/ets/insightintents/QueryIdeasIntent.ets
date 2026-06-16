// 创作中枢 · 意图④「查灵感」（"我都记了哪些灵感"）
import { InsightIntentEntryExecutor, insightIntent, InsightIntentEntry } from '@kit.AbilityKit';
import { Idea } from '../model/Models';
import { CreationHub } from '../service/CreationHub';

class QueryIdeasResultDef {
  public msg?: string = '';
}

@InsightIntentEntry({
  intentName: 'QueryIdeas',
  domain: 'CreationHubDomain',
  intentVersion: '1.0.1',
  displayName: '查灵感',
  displayDescription: '查询灵感库里记了哪些灵感',
  llmDescription: '当用户问"我记了哪些灵感、灵感库里有什么、最近的想法"时调用；可选参数 keyword 按关键词过滤',
  keywords: ['查灵感', '我记了哪些灵感', '灵感库', '最近的想法', 'QueryIdeas'],
  icon: $r('app.media.layered_image'),
  abilityName: 'EntryAbility',
  executeMode: [insightIntent.ExecuteMode.UI_ABILITY_BACKGROUND],
  parameters: {
    'type': 'object',
    'description': '查询灵感',
    'properties': {
      'keyword': {
        'type': 'string',
        'description': '可选，按关键词过滤'
      }
    }
  }
})
export default class QueryIdeasImpl extends InsightIntentEntryExecutor<QueryIdeasResultDef> {
  public keyword?: string = '';

  async onExecute(): Promise<insightIntent.IntentResult<QueryIdeasResultDef>> {
    const list: Idea[] = CreationHub.queryIdeas(this.keyword ?? '');
    const msg: string = list.length === 0
      ? '灵感库还是空的，先记一条吧。'
      : `共 ${list.length} 条灵感：` + list.map((i: Idea) => i.content).join('；') + '。';
    const ok: insightIntent.IntentResult<QueryIdeasResultDef> = {
      code: 0,
      result: { msg: msg }
    };
    return ok;
  }
}
