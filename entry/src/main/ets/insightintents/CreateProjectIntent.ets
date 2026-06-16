// 创作中枢 · 意图⑤「灵感转项目」（"把那条灵感转成项目"）— Skill 组合拳的核心入口
import { InsightIntentEntryExecutor, insightIntent, InsightIntentEntry } from '@kit.AbilityKit';
import { CreationHub } from '../service/CreationHub';

class CreateProjectResultDef {
  public msg?: string = '';
}

@InsightIntentEntry({
  intentName: 'CreateProjectFromIdea',
  domain: 'CreationHubDomain',
  intentVersion: '1.0.1',
  displayName: '灵感转项目',
  displayDescription: '把一条灵感转成项目，自动排期并通知团队',
  llmDescription: '当用户说"把XX灵感转成项目、立项、开干"时调用；参数 ideaName 为灵感关键词；会建项目、排4个节点、通知编导/剪辑/运营',
  keywords: ['转成项目', '立项', '开干', '把灵感变成项目', 'CreateProjectFromIdea'],
  icon: $r('app.media.layered_image'),
  abilityName: 'EntryAbility',
  executeMode: [insightIntent.ExecuteMode.UI_ABILITY_BACKGROUND],
  parameters: {
    'type': 'object',
    'description': '灵感转项目',
    'properties': {
      'ideaName': {
        'type': 'string',
        'description': '要转成项目的灵感关键词',
        'minLength': 1
      }
    },
    'required': ['ideaName']
  }
})
export default class CreateProjectImpl extends InsightIntentEntryExecutor<CreateProjectResultDef> {
  public ideaName?: string = '';

  async onExecute(): Promise<insightIntent.IntentResult<CreateProjectResultDef>> {
    const msg: string = await CreationHub.convertAndNotify(this.ideaName ?? '');
    const ok: insightIntent.IntentResult<CreateProjectResultDef> = {
      code: 0,
      result: { msg: msg }
    };
    return ok;
  }
}
