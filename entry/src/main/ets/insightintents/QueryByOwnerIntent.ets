// 创作中枢 · 意图③「查某人任务」(按岗位查 · "编导有哪些任务")
// 校验点同 RecordIdeaIntent 头部注释。

import { InsightIntentEntryExecutor, insightIntent, InsightIntentEntry } from '@kit.AbilityKit';
import { CreationHub, TaskBrief } from '../service/CreationHub';

class QueryByOwnerResultDef {
  public msg?: string = '';
}

@InsightIntentEntry({
  intentName: 'QueryTasksByOwner',
  domain: 'CreationHubDomain',
  intentVersion: '1.0.1',
  displayName: '查某人任务',
  displayDescription: '查某个岗位/同事手上有哪些待办',
  llmDescription: '当用户问"编导/剪辑/运营有哪些任务、在忙什么、谁的活"时调用；参数 owner 是岗位名',
  keywords: ['编导有哪些任务', '剪辑的任务', '运营在忙什么', '谁的任务', 'QueryTasksByOwner'],
  icon: $r('app.media.layered_image'),
  abilityName: 'EntryAbility',
  executeMode: [insightIntent.ExecuteMode.UI_ABILITY_BACKGROUND],
  parameters: {
    'type': 'object',
    'description': '按岗位查任务',
    'properties': {
      'owner': {
        'type': 'string',
        'description': '岗位名，如 编导/剪辑/运营',
        'minLength': 1
      }
    },
    'required': ['owner']
  }
})
export default class QueryByOwnerImpl extends InsightIntentEntryExecutor<QueryByOwnerResultDef> {
  public owner?: string = ''; // 意图参数自动注入

  async onExecute(): Promise<insightIntent.IntentResult<QueryByOwnerResultDef>> {
    const brief: TaskBrief = CreationHub.queryTasksByOwner(this.owner ?? '编导');
    const ok: insightIntent.IntentResult<QueryByOwnerResultDef> = {
      code: 0,
      result: { msg: brief.text }
    };
    return ok;
  }
}
