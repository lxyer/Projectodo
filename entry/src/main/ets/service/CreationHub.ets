// 创作中枢 · 业务逻辑（页面和意图都调它 · 操作内存 Hub · 同步即时生效）

import { Idea, Project, ProjectNode, NODE_TEMPLATES, NodeTemplate, ALL_ROLES } from '../model/Models';
import { Hub, Persist, nextId } from '../data/Store';

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
  sortKey: number; // 年月日数值（如 20260618），用于按日期升序排
  constructor(label: string, dateKey: string, items: string[], sortKey: number) {
    this.label = label;
    this.dateKey = dateKey;
    this.items = items;
    this.sortKey = sortKey;
  }
}

export class CreationHub {
  // ① 记灵感
  static async recordIdea(content: string, tags: string[]): Promise<Idea> {
    const idea: Idea = new Idea(nextId(), content, tags, Date.now(), 'draft');
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

  // 删除一个项目（连带其节点一并清掉），并把对应灵感状态还原成 draft，使其能重新立项
  static deleteProject(projectId: string): boolean {
    const idx: number = Hub.projects.findIndex((p: Project) => p.id === projectId);
    if (idx < 0) {
      return false;
    }
    const fromId: string = Hub.projects[idx].fromIdeaId;
    const idea: Idea | undefined = Hub.ideas.find((i: Idea) => i.id === fromId);
    if (idea) {
      idea.status = 'draft';
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

  // 按日期分组的日程（日历页用）：未完成节点，按日期聚合并按日期升序排（含年份，避免跨年同日合并）
  static queryAgenda(): DayGroup[] {
    const map: Map<number, DayGroup> = new Map();
    Hub.projects.forEach((p: Project) => {
      p.nodes.forEach((n: ProjectNode) => {
        if (n.status === 'done') {
          return;
        }
        const d: Date = new Date(n.dueAt);
        const sortKey: number = d.getFullYear() * 10000 + (d.getMonth() + 1) * 100 + d.getDate();
        const label: string = `${d.getMonth() + 1}月${d.getDate()}日`;
        const line: string = `${p.title}·${n.name}（${n.owner}）`;
        const g: DayGroup | undefined = map.get(sortKey);
        if (g) {
          g.items.push(line);
        } else {
          map.set(sortKey, new DayGroup(label, sortKey.toString(), [line], sortKey));
        }
      });
    });
    const groups: DayGroup[] = [];
    map.forEach((g: DayGroup) => {
      groups.push(g);
    });
    groups.sort((a: DayGroup, b: DayGroup) => a.sortKey - b.sortKey);
    return groups;
  }

  // ③ 灵感转项目：建项目 + 按模板排节点（含截止日期）。防重复立项：已立项的灵感直接返回其已有项目
  static async createProjectFromIdea(ideaKeyOrName: string): Promise<Project | undefined> {
    let idea: Idea | undefined = Hub.ideas.find((i: Idea) => i.id === ideaKeyOrName);
    if (!idea) {
      idea = Hub.ideas.find((i: Idea) => i.content.indexOf(ideaKeyOrName) >= 0);
    }
    if (!idea) {
      return undefined;
    }
    const target: Idea = idea;
    if (target.status === 'converted') {
      return Hub.projects.find((p: Project) => p.fromIdeaId === target.id);
    }
    const base: number = Date.now();
    const nodes: ProjectNode[] = NODE_TEMPLATES.map((t: NodeTemplate) =>
      new ProjectNode(t.name, t.owner, base + t.offsetDays * DAY_MS, 'pending', false));
    const project: Project = new Project(
      nextId(), target.content, target.id, base, nodes);
    Hub.projects.unshift(project);
    target.status = 'converted';
    Persist.save();
    return project;
  }

  // ④ 查任务（scope='today' 只看今天到期+逾期；否则全部）。今天按本地自然日（0点切天）计算
  static queryTasks(scope: string): TaskBrief {
    const dNow: Date = new Date(Date.now());
    const todayStart: number = new Date(dNow.getFullYear(), dNow.getMonth(), dNow.getDate()).getTime();
    const todayEnd: number = todayStart + DAY_MS;
    const lines: string[] = [];
    let count: number = 0;
    Hub.projects.forEach((p: Project) => {
      p.nodes.forEach((n: ProjectNode) => {
        if (n.status === 'done') {
          return;
        }
        const overdue: boolean = n.dueAt < todayStart;
        const dueToday: boolean = n.dueAt >= todayStart && n.dueAt < todayEnd;
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

  // ⑥a 一键通知项目内所有节点负责人（返回去重后的人数：同一岗位只算一人）
  static notifyAllInProject(projectId: string): number {
    const p: Project | undefined = Hub.projects.find((x: Project) => x.id === projectId);
    if (!p) {
      return 0;
    }
    const owners: Set<string> = new Set();
    p.nodes.forEach((node: ProjectNode) => {
      console.info(`[创作中枢·模拟通知] 【${p.title}】@${node.owner}：你负责的「${node.name}」请认领`);
      node.notified = true;
      owners.add(node.owner);
    });
    Persist.save();
    return owners.size;
  }

  // ④'' 查今天有哪些项目要推进（含逾期，按本地自然日）
  static queryTodayProjects(): TaskBrief {
    const dNow: Date = new Date(Date.now());
    const todayEnd: number = new Date(dNow.getFullYear(), dNow.getMonth(), dNow.getDate()).getTime() + DAY_MS;
    const names: string[] = [];
    Hub.projects.forEach((p: Project) => {
      const has: boolean = p.nodes.some((n: ProjectNode) =>
        n.status !== 'done' && n.dueAt < todayEnd);
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
    const roles: string[] = ALL_ROLES;
    for (const r of roles) {
      await CreationHub.sendTeamNotify(project.title, r, '新项目已立项，请认领你的节点');
    }
    return `已立项「${project.title}」· ${project.nodes.length} 个节点已排期 · ${roles.length} 位同事已通知 ✅`;
  }
}
