// 创作中枢 · 主框架（底部 Tab + 今日概览 + 番茄钟 + 日历 + 完成彩屑动画 + 点击振动）
import { promptAction } from '@kit.ArkUI';
import { vibrator } from '@kit.SensorServiceKit';
import { Idea, Project, ProjectNode } from '../model/Models';
import { CreationHub, TaskBrief, StatBrief, DayGroup } from '../service/CreationHub';

// 轻触振动（音效类反馈 · 失败静默）
function vibe(ms: number): void {
  try {
    vibrator.startVibration({ type: 'time', duration: ms }, { id: 0, usage: 'touch' })
      .then(() => {})
      .catch(() => {});
  } catch (e) {
  }
}

// 全局数据版本号 +1 → 所有 View 的 @Watch 监听到就刷新（解决跨 Tab 不刷新）
function bumpData(): void {
  const v: number = (AppStorage.get('dataVersion') as number) ?? 0;
  AppStorage.setOrCreate('dataVersion', v + 1);
}

function celebrate(): void {
  AppStorage.setOrCreate('celebrate', true);
  vibe(24);
}

// 全屏彩屑庆祝层
@Component
struct CelebrateLayer {
  @StorageLink('celebrate') @Watch('onCele') celebrate: boolean = false;
  @State p: number = 0;

  onCele(): void {
    if (this.celebrate) {
      this.p = 0;
      animateTo({ duration: 650, curve: Curve.EaseOut }, () => {
        this.p = 1;
      });
      setTimeout(() => {
        this.celebrate = false;
        this.p = 0;
      }, 720);
    }
  }

  build() {
    if (this.celebrate) {
      Stack() {
        Text('🎉').fontSize(46).translate({ y: -90 * this.p }).opacity(1 - this.p)
        Text('🎊').fontSize(40).translate({ x: -72 * this.p, y: -64 * this.p }).opacity(1 - this.p)
        Text('✨').fontSize(40).translate({ x: 72 * this.p, y: -64 * this.p }).opacity(1 - this.p)
        Text('🎈').fontSize(34).translate({ x: -42 * this.p, y: -104 * this.p }).opacity(1 - this.p)
        Text('⭐').fontSize(34).translate({ x: 42 * this.p, y: -104 * this.p }).opacity(1 - this.p)
      }
      .width('100%')
      .height('100%')
      .hitTestBehavior(HitTestMode.None)
    }
  }
}

// 统计卡
@Component
struct StatCard {
  label: string = '';
  @Prop value: number = 0;
  accent: string = '#3D5AFE';

  build() {
    Column() {
      Text(this.value.toString())
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.accent)
      Text(this.label)
        .fontSize(12)
        .fontColor('#8A8A8A')
        .margin({ top: 4 })
    }
    .layoutWeight(1)
    .padding({ top: 16, bottom: 16 })
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
    .shadow(ShadowStyle.OUTER_DEFAULT_SM)
  }
}

// 番茄钟卡
@Component
struct FocusCard {
  @State seconds: number = 1500;
  @State running: boolean = false;
  private timerId: number = -1;

  fmt(): string {
    const m: number = Math.floor(this.seconds / 60);
    const s: number = this.seconds % 60;
    const mm: string = m < 10 ? '0' + m.toString() : m.toString();
    const ss: string = s < 10 ? '0' + s.toString() : s.toString();
    return mm + ':' + ss;
  }

  toggle(): void {
    vibe(18);
    if (this.running) {
      clearInterval(this.timerId);
      this.running = false;
    } else {
      this.running = true;
      this.timerId = setInterval(() => {
        if (this.seconds > 0) {
          this.seconds = this.seconds - 1;
        } else {
          clearInterval(this.timerId);
          this.running = false;
          this.seconds = 1500;
          celebrate();
          promptAction.showToast({ message: '专注完成，奖励自己一下 🎉' });
        }
      }, 1000);
    }
  }

  reset(): void {
    clearInterval(this.timerId);
    this.running = false;
    this.seconds = 1500;
  }

  aboutToDisappear(): void {
    clearInterval(this.timerId);
  }

  build() {
    Column() {
      Text('专注一会儿')
        .fontSize(14)
        .fontColor('#8A8A8A')
      Stack() {
        Progress({ value: 1500 - this.seconds, total: 1500, type: ProgressType.Ring })
          .width(130)
          .height(130)
          .color('#3D5AFE')
        Text(this.fmt())
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1F36')
      }
      .margin({ top: 14, bottom: 14 })
      Row() {
        Button(this.running ? '暂停' : '开始')
          .fontSize(14)
          .backgroundColor('#3D5AFE')
          .borderRadius(10)
          .height(40)
          .layoutWeight(1)
          .onClick(() => {
            this.toggle();
          })
        Button('重置')
          .fontSize(14)
          .fontColor('#3D5AFE')
          .backgroundColor('#ECEFFE')
          .borderRadius(10)
          .height(40)
          .layoutWeight(1)
          .margin({ left: 10 })
          .onClick(() => {
            this.reset();
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding(18)
    .backgroundColor('#FFFFFF')
    .borderRadius(20)
    .shadow(ShadowStyle.OUTER_DEFAULT_SM)
  }
}

// 灵感卡片
@Component
struct IdeaItem {
  @ObjectLink idea: Idea;

  async onConvert(): Promise<void> {
    let msg: string = '';
    let ok: boolean = false;
    try {
      msg = await CreationHub.convertAndNotify(this.idea.id);
      ok = msg.indexOf('已立项') >= 0;
    } catch (e) {
      msg = '立项失败，请重试';
    }
    bumpData();
    if (ok) {
      celebrate();
    }
    promptAction.showToast({ message: msg });
  }

  onDelete(): void {
    CreationHub.deleteIdea(this.idea.id);
    bumpData();
    vibe(16);
    promptAction.showToast({ message: '已删除灵感 🗑️' });
  }

  build() {
    Row() {
      Column() {
        Text(this.idea.content)
          .fontSize(16)
          .fontColor('#1A1F36')
          .fontWeight(FontWeight.Medium)
        Text(this.idea.status === 'converted' ? '已立项' : '草稿')
          .fontSize(11)
          .fontColor(this.idea.status === 'converted' ? '#34A853' : '#9AA0B4')
          .backgroundColor(this.idea.status === 'converted' ? '#E6F4EA' : '#F0F2F8')
          .borderRadius(6)
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .margin({ top: 10 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (this.idea.status !== 'converted') {
        Button('转项目')
          .fontSize(13)
          .fontColor(Color.White)
          .backgroundColor('#3D5AFE')
          .borderRadius(10)
          .height(36)
          .padding({ left: 16, right: 16 })
          .onClick(() => {
            this.onConvert();
          })
      } else {
        Text('✓').fontSize(18).fontColor('#34A853')
      }
      Text('🗑️')
        .fontSize(16)
        .margin({ left: 14 })
        .onClick(() => {
          this.onDelete();
        })
    }
    .width('100%')
    .padding(18)
    .backgroundColor('#FFFFFF')
    .borderRadius(20)
    .shadow(ShadowStyle.OUTER_DEFAULT_MD)
  }
}

// 节点行
@Component
struct NodeItem {
  @ObjectLink node: ProjectNode;
  projectId: string = '';

  onToggle(): void {
    vibe(16);
    this.node.status = this.node.status === 'done' ? 'pending' : 'done';
    CreationHub.saveNow();
    bumpData();
    if (this.node.status === 'done') {
      celebrate();
    }
  }

  onNotify(): void {
    const ok: boolean = CreationHub.notifyNode(this.projectId, this.node.name);
    vibe(20);
    bumpData();
    promptAction.showToast({ message: ok ? `已通知 ${this.node.owner} ✅` : '通知失败，没找到该节点' });
  }

  fmt(ts: number): string {
    const d: Date = new Date(ts);
    return `${d.getMonth() + 1}月${d.getDate()}日`;
  }

  build() {
    Row() {
      Stack() {
        Circle({ width: 22, height: 22 })
          .fillOpacity(0)
          .stroke(this.node.status === 'done' ? '#34A853' : '#C5CAD6')
          .strokeWidth(1.5)
        if (this.node.status === 'done') {
          Text('✓').fontSize(13).fontColor('#34A853')
        }
      }
      .onClick(() => {
        this.onToggle();
      })

      Column() {
        Text(this.node.name)
          .fontSize(15)
          .fontColor(this.node.status === 'done' ? '#B0B4BA' : '#1A1F36')
          .decoration({ type: this.node.status === 'done' ? TextDecorationType.LineThrough : TextDecorationType.None })
        Row() {
          Text(this.node.owner)
            .fontSize(11)
            .fontColor('#5B6B8C')
            .backgroundColor('#F0F2F8')
            .borderRadius(5)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          Text('截止 ' + this.fmt(this.node.dueAt))
            .fontSize(11)
            .fontColor('#9AA0B4')
            .margin({ left: 8 })
        }
        .margin({ top: 6 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 12 })

      if (this.node.notified) {
        Text('已通知 ✓').fontSize(12).fontColor('#34A853')
      } else {
        Button('通知')
          .fontSize(12)
          .fontColor('#3D5AFE')
          .backgroundColor('#ECEFFE')
          .borderRadius(8)
          .height(30)
          .padding({ left: 14, right: 14 })
          .onClick(() => {
            this.onNotify();
          })
      }
    }
    .width('100%')
    .padding({ top: 12, bottom: 12 })
  }
}

// 项目卡
@Component
struct ProjectItem {
  @ObjectLink project: Project;

  onNotifyAll(): void {
    const nodes: ProjectNode[] = this.project.nodes;
    if (nodes.length === 0) {
      promptAction.showToast({ message: '没有可通知的人' });
      return;
    }
    const projectId: string = this.project.id;
    const owners: Set<string> = new Set();
    let i: number = 0;
    let timer: number = -1;
    // 逐个通知：每隔 500ms 点亮一个，营造「一个个发出去」的真实节奏
    timer = setInterval(() => {
      if (i >= nodes.length) {
        clearInterval(timer);
        celebrate();
        promptAction.showToast({ message: `已逐个通知 ${owners.size} 人 ✅` });
        return;
      }
      const node: ProjectNode = nodes[i];
      CreationHub.notifyNode(projectId, node.name);
      owners.add(node.owner);
      vibe(16);
      bumpData();
      i = i + 1;
    }, 500);
  }

  onDelete(): void {
    CreationHub.deleteProject(this.project.id);
    bumpData();
    vibe(16);
    promptAction.showToast({ message: '已删除项目 🗑️' });
  }

  build() {
    Column() {
      Row() {
        Text(this.project.title)
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1F36')
          .layoutWeight(1)
        Button('一键通知')
          .fontSize(12)
          .fontColor(Color.White)
          .backgroundColor('#3D5AFE')
          .borderRadius(8)
          .height(32)
          .padding({ left: 14, right: 14 })
          .onClick(() => {
            this.onNotifyAll();
          })
        Text('🗑️')
          .fontSize(15)
          .margin({ left: 10 })
          .onClick(() => {
            this.onDelete();
          })
      }
      .width('100%')
      .margin({ bottom: 4 })

      ForEach(this.project.nodes, (node: ProjectNode) => {
        NodeItem({ node: node, projectId: this.project.id })
        Divider().color('#F0F2F8')
      }, (node: ProjectNode) => this.project.id + node.name)
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(18)
    .backgroundColor('#FFFFFF')
    .borderRadius(20)
    .shadow(ShadowStyle.OUTER_DEFAULT_MD)
  }
}

// ===== Tab 1：今日概览 =====
@Component
struct TodayView {
  @StorageProp('dataVersion') @Watch('onDataChange') dataVersion: number = 0;
  @State stat: StatBrief = new StatBrief(0, 0, 0, 0);
  @State todayText: string = '';

  aboutToAppear(): void {
    this.refresh();
  }

  onDataChange(): void {
    this.refresh();
  }

  refresh(): void {
    this.stat = CreationHub.countStats();
    const b: TaskBrief = CreationHub.queryTasks('today');
    this.todayText = b.text;
  }

  build() {
    Column() {
      Column() {
        Text('今日概览')
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
        Text('掌控全局，一眼看清')
          .fontSize(14)
          .fontColor('#CCFFFFFF')
          .margin({ top: 6 })
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .padding({ left: 20, right: 20, top: 22, bottom: 22 })
      .linearGradient({ angle: 135, colors: [['#3D5AFE', 0.0], ['#7C4DFF', 1.0]] })
      .borderRadius({ bottomLeft: 24, bottomRight: 24 })

      Scroll() {
        Column() {
          Row({ space: 12 }) {
            StatCard({ label: '灵感', value: this.stat.ideaCount, accent: '#7C4DFF' })
            StatCard({ label: '项目', value: this.stat.projectCount, accent: '#3D5AFE' })
            StatCard({ label: '待办', value: this.stat.todayCount, accent: '#EA4335' })
            StatCard({ label: '已完成', value: this.stat.doneCount, accent: '#34A853' })
          }
          .width('100%')
          .margin({ top: 16 })

          Row() {
            Text('📣').fontSize(16)
            Text(this.todayText)
              .fontSize(13)
              .fontColor('#5A4A1A')
              .layoutWeight(1)
              .margin({ left: 8 })
          }
          .width('100%')
          .padding(14)
          .backgroundColor('#FFF7E0')
          .borderRadius(14)
          .margin({ top: 14 })

          FocusCard()
            .margin({ top: 14 })
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 20 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .linearGradient({ angle: 180, colors: [['#EEF2FF', 0.0], ['#F7F8FC', 0.35], ['#F7F8FC', 1.0]] })
  }
}

// ===== Tab 2：灵感 =====
@Component
struct IdeasView {
  @StorageProp('dataVersion') @Watch('onDataChange') dataVersion: number = 0;
  @State ideas: Idea[] = [];
  @State draft: string = '';

  aboutToAppear(): void {
    this.refresh();
  }

  onDataChange(): void {
    this.refresh();
  }

  refresh(): void {
    this.ideas = CreationHub.queryIdeas('');
  }

  async onRecord(): Promise<void> {
    const text: string = this.draft.trim();
    if (text.length === 0) {
      promptAction.showToast({ message: '先写点灵感内容' });
      return;
    }
    // 双保险：持久化即使抛错也不中断 UI 刷新（灵感已进内存）
    let ok: boolean = true;
    try {
      await CreationHub.recordIdea(text, []);
    } catch (e) {
      ok = false;
    }
    this.draft = '';
    bumpData();
    this.refresh();
    if (ok) {
      vibe(16);
      promptAction.showToast({ message: '灵感已记下 ✅' });
    } else {
      promptAction.showToast({ message: '记录失败，请重试' });
    }
  }

  build() {
    Column() {
      Column() {
        Text('创作中枢')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
        Text('一句话，从灵感到立项')
          .fontSize(14)
          .fontColor('#CCFFFFFF')
          .margin({ top: 6 })
        Row() {
          TextInput({ placeholder: '记一条灵感…', text: this.draft })
            .layoutWeight(1)
            .height(46)
            .backgroundColor('#FFFFFF')
            .borderRadius(12)
            .padding({ left: 14, right: 14 })
            .placeholderColor('#B0B4BA')
            .fontColor('#1A1F36')
            .onChange((v: string) => {
              this.draft = v;
            })
            .onSubmit(() => {
              this.onRecord();
            })
          Button('记下')
            .height(46)
            .margin({ left: 10 })
            .backgroundColor('#FFFFFF')
            .fontColor('#3D5AFE')
            .fontWeight(FontWeight.Medium)
            .borderRadius(12)
            .padding({ left: 18, right: 18 })
            .onClick(() => {
              this.onRecord();
            })
        }
        .width('100%')
        .margin({ top: 18 })
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .padding({ left: 20, right: 20, top: 22, bottom: 22 })
      .linearGradient({ angle: 135, colors: [['#3D5AFE', 0.0], ['#7C4DFF', 1.0]] })
      .borderRadius({ bottomLeft: 24, bottomRight: 24 })

      if (this.ideas.length === 0) {
        Column() {
          Text('💡').fontSize(48)
          Text('还没有灵感，记一条试试')
            .fontSize(14)
            .fontColor('#9AA0B4')
            .margin({ top: 12 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 14 }) {
          ForEach(this.ideas, (idea: Idea) => {
            ListItem() {
              IdeaItem({ idea: idea })
            }
          }, (idea: Idea) => idea.id)
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ left: 16, right: 16, top: 16, bottom: 16 })
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .linearGradient({ angle: 180, colors: [['#EEF2FF', 0.0], ['#F7F8FC', 0.35], ['#F7F8FC', 1.0]] })
  }
}

// ===== Tab 3：项目 =====
@Component
struct ProjectsView {
  @StorageProp('dataVersion') @Watch('onDataChange') dataVersion: number = 0;
  @State projects: Project[] = [];
  @State brief: string = '';
  @State activeChip: string = '';

  aboutToAppear(): void {
    this.refresh();
  }

  onDataChange(): void {
    this.refresh();
  }

  refresh(): void {
    this.applyFilter();
  }

  // 按当前选中的岗位 chip 过滤项目列表（全部/今天=不过滤）
  applyFilter(): void {
    const all: Project[] = CreationHub.queryProjects();
    if (this.activeChip === '编导' || this.activeChip === '剪辑' || this.activeChip === '运营') {
      this.projects = all.filter((p: Project) =>
        p.nodes.some((n: ProjectNode) => n.owner === this.activeChip));
    } else {
      this.projects = all;
    }
  }

  onChip(label: string): void {
    if (this.activeChip === label) {
      // 再点一次取消选中
      this.activeChip = '';
      this.brief = '';
    } else {
      this.activeChip = label;
      if (label === '今天') {
        this.brief = CreationHub.queryTodayProjects().text;
      } else if (label === '全部') {
        this.brief = '';
      } else {
        this.brief = CreationHub.queryTasksByOwner(label).text;
      }
    }
    this.applyFilter();
  }

  @Builder
  Chip(label: string) {
    Text(label)
      .fontSize(13)
      .fontColor(this.activeChip === label ? '#3D5AFE' : '#FFFFFF')
      .backgroundColor(this.activeChip === label ? '#FFFFFF' : '#33FFFFFF')
      .borderRadius(16)
      .padding({ left: 16, right: 16, top: 7, bottom: 7 })
      .onClick(() => {
        this.onChip(label);
      })
  }

  build() {
    Column() {
      Column() {
        Text('项目看板')
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
        Scroll() {
          Row({ space: 10 }) {
            ForEach(['全部', '今天', '编导', '剪辑', '运营'], (r: string) => {
              this.Chip(r);
            }, (r: string) => r)
          }
        }
        .width('100%')
        .margin({ top: 16 })
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .align(Alignment.Start)
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .padding({ left: 20, right: 20, top: 22, bottom: 20 })
      .linearGradient({ angle: 135, colors: [['#3D5AFE', 0.0], ['#7C4DFF', 1.0]] })
      .borderRadius({ bottomLeft: 24, bottomRight: 24 })

      if (this.brief.length > 0) {
        Row() {
          Text('📣').fontSize(16)
          Text(this.brief)
            .fontSize(13)
            .fontColor('#5A4A1A')
            .layoutWeight(1)
            .margin({ left: 8 })
        }
        .width('90%')
        .padding(14)
        .backgroundColor('#FFF7E0')
        .borderRadius(14)
        .margin({ top: 14 })
      }

      if (this.projects.length === 0) {
        Column() {
          Text('📋').fontSize(48)
          Text('还没有项目')
            .fontSize(15)
            .fontColor('#5B6B8C')
            .margin({ top: 12 })
          Text('去「灵感」页把一条灵感转成项目')
            .fontSize(13)
            .fontColor('#9AA0B4')
            .margin({ top: 6 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 14 }) {
          ForEach(this.projects, (p: Project) => {
            ListItem() {
              ProjectItem({ project: p })
            }
          }, (p: Project) => p.id)
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ left: 16, right: 16, top: 14, bottom: 16 })
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .linearGradient({ angle: 180, colors: [['#EEF2FF', 0.0], ['#F7F8FC', 0.35], ['#F7F8FC', 1.0]] })
  }
}

// ===== Tab 4：日历 / 日程 =====
@Component
struct CalendarView {
  @StorageProp('dataVersion') @Watch('onDataChange') dataVersion: number = 0;
  @State groups: DayGroup[] = [];

  aboutToAppear(): void {
    this.refresh();
  }

  onDataChange(): void {
    this.refresh();
  }

  refresh(): void {
    this.groups = CreationHub.queryAgenda();
  }

  build() {
    Column() {
      Column() {
        Text('日程')
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
        Text('按截止日期看所有节点')
          .fontSize(14)
          .fontColor('#CCFFFFFF')
          .margin({ top: 6 })
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .padding({ left: 20, right: 20, top: 22, bottom: 22 })
      .linearGradient({ angle: 135, colors: [['#3D5AFE', 0.0], ['#7C4DFF', 1.0]] })
      .borderRadius({ bottomLeft: 24, bottomRight: 24 })

      if (this.groups.length === 0) {
        Column() {
          Text('🗓️').fontSize(48)
          Text('暂无日程')
            .fontSize(15)
            .fontColor('#5B6B8C')
            .margin({ top: 12 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 14 }) {
          ForEach(this.groups, (g: DayGroup) => {
            ListItem() {
              Column() {
                Row() {
                  Text('🗓️').fontSize(14)
                  Text(g.label)
                    .fontSize(15)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#3D5AFE')
                    .margin({ left: 6 })
                }
                ForEach(g.items, (it: string) => {
                  Text(it)
                    .fontSize(14)
                    .fontColor('#1A1F36')
                    .width('100%')
                    .padding({ top: 8, bottom: 8 })
                }, (it: string) => g.dateKey + it)
              }
              .alignItems(HorizontalAlign.Start)
              .width('100%')
              .padding(16)
              .backgroundColor('#FFFFFF')
              .borderRadius(20)
              .shadow(ShadowStyle.OUTER_DEFAULT_MD)
            }
          }, (g: DayGroup) => g.dateKey)
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ left: 16, right: 16, top: 14, bottom: 16 })
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .linearGradient({ angle: 180, colors: [['#EEF2FF', 0.0], ['#F7F8FC', 0.35], ['#F7F8FC', 1.0]] })
  }
}

@Entry
@Component
struct MainPage {
  @State idx: number = 0;

  @Builder
  bar(label: string, icon: string, i: number) {
    Column() {
      Text(icon).fontSize(20)
      Text(label)
        .fontSize(11)
        .fontColor(this.idx === i ? '#3D5AFE' : '#9AA0B4')
        .margin({ top: 2 })
    }
    .width('100%')
    .padding({ top: 6, bottom: 6 })
  }

  build() {
    Stack() {
      Tabs({ index: this.idx }) {
        TabContent() {
          TodayView()
        }.tabBar(this.bar('今日', '📊', 0))

        TabContent() {
          IdeasView()
        }.tabBar(this.bar('灵感', '💡', 1))

        TabContent() {
          ProjectsView()
        }.tabBar(this.bar('项目', '📁', 2))

        TabContent() {
          CalendarView()
        }.tabBar(this.bar('日历', '🗓️', 3))
      }
      .barPosition(BarPosition.End)
      .onChange((i: number) => {
        this.idx = i;
      })

      CelebrateLayer()
    }
    .width('100%')
    .height('100%')
  }
}
