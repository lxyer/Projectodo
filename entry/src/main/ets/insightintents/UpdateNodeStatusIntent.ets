// 创作中枢 · 意图⑧「更新节点状态」（"XX 项目的大纲做完了"）
import { InsightIntentEntryExecutor, insightIntent, InsightIntentEntry } from '@kit.AbilityKit';
import { CreationHub } from '../service/CreationHub';

class UpdateNodeResultDef {
  public msg?: string = '';
}

@InsightIntentEntry({
  intentName: 'UpdateNodeStatus',
  domain: 'CreationHubDomain',
  intentVersion: '1.0.1',
  displayName: '更新节点状态',
  displayDescription: '把某个项目的某个节点标记为完成/进行中',
  llmDescription: '当用户说"XX项目的大纲写完了、把YY标记完成"时调用；参数 projectName 项目名、nodeName 节点名(大纲/脚本/初稿/发布)、status 状态(done/inProgress)',
  keywords: ['做完了', '标记完成', '改状态', '完成了', 'UpdateNodeStatus'],
  icon: $r('app.media.layered_image'),
  abilityName: 'EntryAbility',
  executeMode: [insightIntent.ExecuteMode.UI_ABILITY_BACKGROUND],
  parameters: {
    'type': 'object',
    'description': '更新节点状态',
    'properties': {
      'projectName': { 'type': 'string', 'description': '项目名（关键词）', 'minLength': 1 },
      'nodeName': { 'type': 'string', 'description': '节点名：大纲/脚本/初稿/发布', 'minLength': 1 },
      'status': { 'type': 'string', 'description': '状态：done 完成 / inProgress 进行中 / pending 未开始' }
    },
    'required': ['projectName', 'nodeName']
  }
})
export default class UpdateNodeStatusImpl extends InsightIntentEntryExecutor<UpdateNodeResultDef> {
  public projectName?: string = '';
  public nodeName?: string = '';
  public status?: string = 'done';

  async onExecute(): Promise<insightIntent.IntentResult<UpdateNodeResultDef>> {
    const pid: string | undefined = CreationHub.findProjectIdByTitle(this.projectName ?? '');
    if (!pid) {
      const fail: insightIntent.IntentResult<UpdateNodeResultDef> = {
        code: -1,
        result: { msg: '没找到这个项目' }
      };
      return fail;
    }
    const okFlag: boolean = await CreationHub.updateNodeStatus(pid, this.nodeName ?? '', this.status ?? 'done');
    const ok: insightIntent.IntentResult<UpdateNodeResultDef> = {
      code: okFlag ? 0 : -1,
      result: { msg: okFlag ? `已更新「${this.nodeName}」状态 ✅` : '没找到这个节点' }
    };
    return ok;
  }
}
