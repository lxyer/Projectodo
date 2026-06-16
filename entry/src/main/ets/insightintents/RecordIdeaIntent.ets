// 创作中枢 · 意图①「记灵感」(单意图 · 今天可用意图框架调试工具自测)
// 语法严格照华为官方《使用装饰器开发意图》示例(API20+)。
// ⚠️ 待 DevEco/CodeGenie 校验点：
//   1. this.context 的获取——InsightIntentEntryExecutor 基类的 context 属性名以 SDK 提示为准；
//      若基类不直接提供，改为在 EntryAbility.onCreate 里 Store.init。
//   2. icon 资源 $r('app.media.layered_image') 换成你工程里的实际图标。

import { InsightIntentEntryExecutor, insightIntent, InsightIntentEntry } from '@kit.AbilityKit';
import { CreationHub } from '../service/CreationHub';

class RecordIdeaResultDef {
  public msg?: string = '';
}

@InsightIntentEntry({
  intentName: 'RecordIdea',
  domain: 'CreationHubDomain',
  intentVersion: '1.0.1',
  displayName: '记灵感',
  displayDescription: '把一条灵感记进创作中枢',
  llmDescription: '当用户想记录一条灵感、想法、点子时调用；参数 content 为灵感内容',
  keywords: ['记灵感', '记一条灵感', '记录想法', 'RecordIdea'],
  icon: $r('app.media.layered_image'),
  abilityName: 'EntryAbility',
  executeMode: [insightIntent.ExecuteMode.UI_ABILITY_BACKGROUND],
  parameters: {
    'type': 'object',
    'description': '记录一条灵感',
    'properties': {
      'content': {
        'type': 'string',
        'description': '灵感的内容',
        'minLength': 1
      }
    },
    'required': ['content']
  }
})
export default class RecordIdeaImpl extends InsightIntentEntryExecutor<RecordIdeaResultDef> {
  public content?: string = ''; // 意图参数自动注入为类成员

  async onExecute(): Promise<insightIntent.IntentResult<RecordIdeaResultDef>> {
    const text: string = this.content ?? '';
    if (text.length === 0) {
      const fail: insightIntent.IntentResult<RecordIdeaResultDef> = {
        code: -1,
        result: { msg: '没听清要记什么灵感' }
      };
      return fail;
    }
    await CreationHub.recordIdea(text, []);
    const ok: insightIntent.IntentResult<RecordIdeaResultDef> = {
      code: 0,
      result: { msg: `已记下灵感：${text}` }
    };
    return ok;
  }
}
