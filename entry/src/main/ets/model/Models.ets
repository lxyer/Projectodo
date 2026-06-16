// 创作中枢 · 数据模型
// @Observed + 子组件 @ObjectLink：让对象属性变化（如 notified/status）能自动刷新 UI。

@Observed
export class Idea {
  id: string;
  content: string;
  tags: string[];
  createdAt: number;
  status: string; // 'draft' 草稿 | 'converted' 已立项

  constructor(id: string, content: string, tags: string[], createdAt: number, status: string) {
    this.id = id;
    this.content = content;
    this.tags = tags;
    this.createdAt = createdAt;
    this.status = status;
  }
}

@Observed
export class ProjectNode {
  name: string;
  owner: string;
  dueAt: number;
  status: string;    // 'pending' | 'inProgress' | 'done'
  notified: boolean;

  constructor(name: string, owner: string, dueAt: number, status: string, notified: boolean) {
    this.name = name;
    this.owner = owner;
    this.dueAt = dueAt;
    this.status = status;
    this.notified = notified;
  }
}

@Observed
export class Project {
  id: string;
  title: string;
  fromIdeaId: string;
  createdAt: number;
  nodes: ProjectNode[];

  constructor(id: string, title: string, fromIdeaId: string, createdAt: number, nodes: ProjectNode[]) {
    this.id = id;
    this.title = title;
    this.fromIdeaId = fromIdeaId;
    this.createdAt = createdAt;
    this.nodes = nodes;
  }
}

export interface NodeTemplate {
  name: string;
  owner: string;
  offsetDays: number;
}

export const NODE_TEMPLATES: NodeTemplate[] = [
  { name: '大纲', owner: '编导', offsetDays: 1 },
  { name: '脚本', owner: '编导', offsetDays: 2 },
  { name: '初稿', owner: '剪辑', offsetDays: 3 },
  { name: '发布', owner: '运营', offsetDays: 5 }
];

export const ALL_ROLES: string[] = ['编导', '剪辑', '运营'];
