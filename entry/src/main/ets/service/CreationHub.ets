// 创作中枢 · 业务逻辑（页面和意图都调它 · 操作内存 Hub · 同步即时生效）

import { util } from '@kit.ArkTS';
import { Idea, Project, ProjectNode, NODE_TEMPLATES, NodeTemplate } from '../model/Models';
import { Hub, Persist } from '../data/Store';

const DAY_MS: number = 24 * 60 * 60 * 1000;

export class TaskBrief {
  text: string;
  count: number;
  constructor(text: string, count: number) {
    this.text = text;
    this.count = count;
  }
}

export class StatBrief {
  ideaCount: number;
  projectCount: number;
  todayCount: number;
  doneCount: number;
  constructor(ideaCount: number, projectCount: number, todayCount: number, doneCount: number) {
    this.ideaCount = ideaCount;
    this.projectCount = projectCount;
    this.todayCount = todayCount;
    this.doneCount = doneCount;
  }
}

export class DayGroup {
  label: string;
  dateKey: string;
  items: string[];
  constructor(label: string, dateKey: string, items: string[]) {
    this.label = label;
    this.dateKey = dateKey;
    this.items = items;
  }
}

export class CreationHub {
  // ① 记灵感
  static async recordIdea(content: string, tags: string[]): Promise<Idea> {
    const idea: Idea = new Idea(util.generateRandomUUID(true), content, tags, Date.now(), 'draft');
    Hub.ideas.unshift(idea);
    Persist.save();
    return idea;
  }

  // ② 查灵感
  static queryIdeas(keyword: string): Idea[] {
    if (keyword.length === 0) {
      return Hub.ideas.slice();
    }
    return Hub.ideas.filter((i: Idea) => i.content.indexOf(keyword) >= 0);
  }

  static queryProjects(): Project[] {
    return Hub.projects.slice();
  }

  // 删除一条灵感
  static deleteIdea(ideaId: string): boolean {
    const idx: number = Hub.ideas.findIndex((i: Idea) => i.id === ideaId);
    if (idx < 0) {
      return false;
    }
    Hub.ideas.splice(idx, 1);
    Persist.save();
    return true;
  }

  // 删除一个项目（连带其节点一并清掉）
  static deleteProject(projectId: string): boolean {
    const idx: number = Hub.projects.findIndex((p: Project) => p.id === projectId);
    if (idx < 0) {
      return false;
    }
    Hub.projects.splice(idx, 1);
    Persist.save();
    return true;
  }

  // 供页面直接改了对象属性后持久化（如节点打勾）
  static saveNow(): void {
    Persist.save();
  }

  // 按标题找项目 id（意图按名称匹配用）
  static findProjectIdByTitle(title: string): string | undefined {
    const p: Project | undefined = Hub.projects.find((x: Project) =>
      x.title === title || x.title.indexOf(title) >= 0);
    return p ? p.id : undefined;
  }

  // 概览统计（今日页用）：待办 = 所有未完成节点；已完成 = done 节点
  static countStats(): StatBrief {
    let todo: number = 0;
    let done: number = 0;
    Hub.projects.forEach((p: Project) => {
      p.nodes.forEach((n: ProjectNode) => {
        if (n.status === 'done') {
          done++;
        } else {
          todo++;
        }
      });
    });
    return new StatBrief(Hub.ideas.length, Hub.projects.length, todo, done);
  }

  // 按日期分组的日程（日历页用）：未完成节点，按日期聚合
  static queryAgenda(): DayGroup[] {
    const map: Map<string, string[]> = new Map();
    Hub.projects.forEach((p: Project) => {
      p.nodes.forEach((n: ProjectNode) => {
        if (n.status === 'done') {
          return;
        }
        const d: Date = new Date(n.dueAt);
        const key: string = `${d.getMonth() + 1}月${d.getDate()}日`;
        const line: string = `${p.title}·${n.name}（${n.owner}）`;
        const arr: string[] | undefined = map.get(key);
        if (arr) {
          arr.push(line);
        } else {
          map.set(key, [line]);
        }
      });
    });
    const groups: DayGroup[] = [];
    map.forEach((items: string[], key: string) => {
      groups.push(new DayGroup(key, key, items));
    });
    return groups;
  }

  // ③ 灵感转项目：建项目 + 按模板排 4 节点（含截止日期）
  static async createProjectFromIdea(ideaKeyOrName: string): Promise<Project | undefined> {
    let idea: Idea | undefined = Hub.ideas.find((i: Idea) => i.id === ideaKeyOrName);
    if (!idea) {
      idea = Hub.ideas.find((i: Idea) => i.content.indexOf(ideaKeyOrName) >= 0);
    }
    if (!idea) {
      return undefined;
    }
    const base: number = Date.now();
    const nodes: ProjectNode[] = NODE_TEMPLATES.map((t: NodeTemplate) =>
      new ProjectNode(t.name, t.owner, base + t.offsetDays * DAY_MS, 'pending', false));
    const project: Project = new Project(
      util.generateRandomUUID(true), idea.content, idea.id, base, nodes);
    Hub.projects.unshift(project);
    idea.status = 'converted';
    Persist.save();
    return project;
  }

  // ④ 查任务（scope='today' 只看今日到期+逾期；否则全部）
  static queryTasks(scope: string): TaskBrief {
    const now: number = Date.now();
    const lines: string[] = [];
    let count: number = 0;
    Hub.projects.forEach((p: Project) => {
      p.nodes.forEach((n: ProjectNode) => {
        if (n.status === 'done') {
          return;
        }
        const overdue: boolean = n.dueAt < now;
        const dueToday: boolean = (n.dueAt - now) < DAY_MS && n.dueAt >= now;
        const hit: boolean = scope === 'today' ? (overdue || dueToday) : true;
        if (hit) {
          count++;
          const tag: string = overdue ? '已逾期' : (dueToday ? '今天到期' : '进行中');
          lines.push(`${p.title} 的「${n.name}」${tag}，归${n.owner}`);
        }
      });
    });
    const text: string = count === 0
      ? '今天没有到期的任务，都在掌控之中。'
      : `今天有 ${count} 个节点要盯：` + lines.join('；') + '。';
    return new TaskBrief(text, count);
  }

  // ④' 按岗位查任务（"编导有哪些任务"）
  static queryTasksByOwner(owner: string): TaskBrief {
    const lines: string[] = [];
    let count: number = 0;
    Hub.projects.forEach((p: Project) => {
      p.nodes.forEach((n: ProjectNode) => {
        if (n.owner === owner && n.status !== 'done') {
          count++;
          lines.push(`${p.title} 的「${n.name}」`);
        }
      });
    });
    const text: string = count === 0
      ? `${owner}手上没有待办，轻松。`
      : `${owner}有 ${count} 个待办：` + lines.join('；') + '。';
    return new TaskBrief(text, count);
  }

  // ⑤ 更新节点状态
  static async updateNodeStatus(projectId: string, nodeName: string, status: string): Promise<boolean> {
    const p: Project | undefined = Hub.projects.find((x: Project) => x.id === projectId);
    if (!p) {
      return false;
    }
    const n: ProjectNode | undefined = p.nodes.find((x: ProjectNode) => x.name === nodeName);
    if (!n) {
      return false;
    }
    n.status = status;
    Persist.save();
    return true;
  }

  // ⑥ 通知单个节点的负责人（模拟发送 + 标记已通知）
  static notifyNode(projectId: string, nodeName: string): boolean {
    const p: Project | undefined = Hub.projects.find((x: Project) => x.id === projectId);
    if (!p) {
      return false;
    }
    const n: ProjectNode | undefined = p.nodes.find((x: ProjectNode) => x.name === nodeName);
    if (!n) {
      return false;
    }
    console.info(`[创作中枢·模拟通知] 【${p.title}】@${n.owner}：你负责的「${n.name}」请认领`);
    n.notified = true;
    Persist.save();
    return true;
  }

  // ⑥a 一键通知项目内所有节点负责人（返回通知人数）
  static notifyAllInProject(projectId: string): number {
    const p: Project | undefined = Hub.projects.find((x: Project) => x.id === projectId);
    if (!p) {
      return 0;
    }
    let n: number = 0;
    p.nodes.forEach((node: ProjectNode) => {
      console.info(`[创作中枢·模拟通知] 【${p.title}】@${node.owner}：你负责的「${node.name}」请认领`);
      node.notified = true;
      n++;
    });
    Persist.save();
    return n;
  }

  // ④'' 查今天有哪些项目要推进
  static queryTodayProjects(): TaskBrief {
    const now: number = Date.now();
    const names: string[] = [];
    Hub.projects.forEach((p: Project) => {
      const has: boolean = p.nodes.some((n: ProjectNode) =>
        n.status !== 'done' && (n.dueAt < now || (n.dueAt - now) < DAY_MS));
      if (has) {
        names.push(p.title);
      }
    });
    const text: string = names.length === 0
      ? '今天没有需要推进的项目。'
      : `今天有 ${names.length} 个项目要推进：${names.join('、')}。`;
    return new TaskBrief(text, names.length);
  }

  // ⑥' 发团队通知（模拟）
  static async sendTeamNotify(projectTitle: string, role: string, message: string): Promise<boolean> {
    console.info(`[创作中枢·模拟通知] 【${projectTitle}】@${role}：${message}`);
    return true;
  }

  // 组合：立项 + 给三个岗位发通知
  static async convertAndNotify(ideaKeyOrName: string): Promise<string> {
    const project: Project | undefined = await CreationHub.createProjectFromIdea(ideaKeyOrName);
    if (!project) {
      return '没找到这条灵感，换个关键词试试。';
    }
    const roles: string[] = ['编导', '剪辑', '运营'];
    for (const r of roles) {
      await CreationHub.sendTeamNotify(project.title, r, '新项目已立项，请认领你的节点');
    }
    return `已立项「${project.title}」· 4 个节点已排期 · ${roles.length} 位同事已通知 ✅`;
  }
}
