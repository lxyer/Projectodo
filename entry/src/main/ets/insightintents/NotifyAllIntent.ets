// 创作中枢 · 意图⑥「一键通知项目」（"通知 XX 项目的所有人"）
import { InsightIntentEntryExecutor, insightIntent, InsightIntentEntry } from '@kit.AbilityKit';
import { CreationHub } from '../service/CreationHub';

class NotifyAllResultDef {
  public msg?: string = '';
}

@InsightIntentEntry({
  intentName: 'NotifyAllInProject',
  domain: 'CreationHubDomain',
  intentVersion: '1.0.1',
  displayName: '一键通知项目',
  displayDescription: '通知某个项目里所有节点的负责人',
  llmDescription: '当用户说"通知XX项目所有人、催一下XX项目、一键通知"时调用；参数 projectName 为项目名',
  keywords: ['一键通知', '通知所有人', '催一下项目', 'NotifyAllInProject'],
  icon: $r('app.media.layered_image'),
  abilityName: 'EntryAbility',
  executeMode: [insightIntent.ExecuteMode.UI_ABILITY_BACKGROUND],
  parameters: {
    'type': 'object',
    'description': '一键通知项目',
    'properties': {
      'projectName': {
        'type': 'string',
        'description': '项目名（关键词）',
        'minLength': 1
      }
    },
    'required': ['projectName']
  }
})
export default class NotifyAllImpl extends InsightIntentEntryExecutor<NotifyAllResultDef> {
  public projectName?: string = '';

  async onExecute(): Promise<insightIntent.IntentResult<NotifyAllResultDef>> {
    const pid: string | undefined = CreationHub.findProjectIdByTitle(this.projectName ?? '');
    if (!pid) {
      const fail: insightIntent.IntentResult<NotifyAllResultDef> = {
        code: -1,
        result: { msg: '没找到这个项目' }
      };
      return fail;
    }
    const n: number = CreationHub.notifyAllInProject(pid);
    const ok: insightIntent.IntentResult<NotifyAllResultDef> = {
      code: 0,
      result: { msg: `已通知 ${n} 位同事 ✅` }
    };
    return ok;
  }
}
