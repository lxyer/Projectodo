// 创作中枢 · 数据仓（内存缓存 Hub + 端侧 RDB/SQLite 持久化）
// 架构：UI 直接读内存 Hub（@Observed 响应式）；每次写操作后 Persist.save() 全量覆盖落盘到 SQLite。
//       启动 Persist.init() 从 RDB 读回重建实例；空库则 seed 预置演示数据。
// 设计取舍：数据量小（几十条），save 用「先清表再整表写入」，简单可靠；
//          所有 RDB 操作 try-catch + [DB] 诊断日志，落盘失败也不影响内存与 UI。
// 关键：用同步接口（getRdbStoreSync/querySync/insertSync/executeSync），保证 onCreate 里同步
//      把数据填进 Hub，页面渲染时数据已就绪（不重蹈异步时序的坑）。

import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { Idea, Project, ProjectNode, NODE_TEMPLATES, NodeTemplate } from '../model/Models';

class DataHub {
  ideas: Idea[] = [];
  projects: Project[] = [];
}

export const Hub: DataHub = new DataHub();

// 唯一 ID 生成器：时间戳 + 自增序号，保证任何环境都唯一。
// 不用 generateRandomUUID——预览器里它是 mock 实现，会返回重复值，
// 导致 ForEach 的 key 冲突、新增项被当成「已存在」而不渲染。
let idSeq: number = 0;
export function nextId(): string {
  idSeq++;
  return Date.now().toString() + '_' + idSeq.toString();
}

const DB_NAME: string = 'creation_hub.db';
const DAY_MS: number = 24 * 60 * 60 * 1000;
let store: relationalStore.RdbStore | undefined = undefined;

const SQL_IDEAS: string =
  'CREATE TABLE IF NOT EXISTS ideas (id TEXT PRIMARY KEY, content TEXT, tags TEXT, createdAt INTEGER, status TEXT)';
const SQL_PROJECTS: string =
  'CREATE TABLE IF NOT EXISTS projects (id TEXT PRIMARY KEY, title TEXT, fromIdeaId TEXT, createdAt INTEGER)';
const SQL_NODES: string =
  'CREATE TABLE IF NOT EXISTS nodes (nodeKey TEXT PRIMARY KEY, projectId TEXT, name TEXT, owner TEXT, dueAt INTEGER, status TEXT, notified INTEGER)';

export class Persist {
  // App 启动调一次：建库建表 → 读回数据 → 空库预置演示数据
  static init(ctx: common.Context): void {
    try {
      const config: relationalStore.StoreConfig = {
        name: DB_NAME,
        securityLevel: relationalStore.SecurityLevel.S1
      };
      store = relationalStore.getRdbStoreSync(ctx, config);
      store.executeSync(SQL_IDEAS);
      store.executeSync(SQL_PROJECTS);
      store.executeSync(SQL_NODES);
      console.info('[DB] 数据库就绪');
      Persist.load();
      if (Hub.ideas.length === 0 && Hub.projects.length === 0) {
        Persist.seed();
      }
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      console.error(`[DB] init 失败 code=${err.code} msg=${err.message}`);
    }
  }

  // 从 RDB 读回 → 重建 @Observed 实例
  static load(): void {
    if (!store) {
      return;
    }
    const s: relationalStore.RdbStore = store;
    try {
      const ideas: Idea[] = [];
      const rs1: relationalStore.ResultSet =
        s.querySync(new relationalStore.RdbPredicates('ideas').orderByDesc('createdAt'));
      while (rs1.goToNextRow()) {
        const tagsStr: string = rs1.getString(rs1.getColumnIndex('tags'));
        let tags: string[] = [];
        try {
          tags = JSON.parse(tagsStr) as string[];
        } catch (e2) {
          tags = [];
        }
        ideas.push(new Idea(
          rs1.getString(rs1.getColumnIndex('id')),
          rs1.getString(rs1.getColumnIndex('content')),
          tags,
          rs1.getLong(rs1.getColumnIndex('createdAt')),
          rs1.getString(rs1.getColumnIndex('status'))
        ));
      }
      rs1.close();

      const projects: Project[] = [];
      const rs2: relationalStore.ResultSet =
        s.querySync(new relationalStore.RdbPredicates('projects').orderByDesc('createdAt'));
      while (rs2.goToNextRow()) {
        const pid: string = rs2.getString(rs2.getColumnIndex('id'));
        const nodes: ProjectNode[] = [];
        const rs3: relationalStore.ResultSet =
          s.querySync(new relationalStore.RdbPredicates('nodes').equalTo('projectId', pid).orderByAsc('dueAt'));
        while (rs3.goToNextRow()) {
          nodes.push(new ProjectNode(
            rs3.getString(rs3.getColumnIndex('name')),
            rs3.getString(rs3.getColumnIndex('owner')),
            rs3.getLong(rs3.getColumnIndex('dueAt')),
            rs3.getString(rs3.getColumnIndex('status')),
            rs3.getLong(rs3.getColumnIndex('notified')) === 1
          ));
        }
        rs3.close();
        projects.push(new Project(
          pid,
          rs2.getString(rs2.getColumnIndex('title')),
          rs2.getString(rs2.getColumnIndex('fromIdeaId')),
          rs2.getLong(rs2.getColumnIndex('createdAt')),
          nodes
        ));
      }
      rs2.close();

      Hub.ideas = ideas;
      Hub.projects = projects;
      console.info(`[DB] 读回 ideas=${ideas.length} projects=${projects.length}`);
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      console.error(`[DB] load 失败 code=${err.code} msg=${err.message}`);
    }
  }

  // 全量覆盖：先清空三表再整表写入（数据量小，简单可靠）
  static save(): void {
    if (!store) {
      console.error('[DB] save 跳过：store 不可用，数据未落盘');
      return;
    }
    const s: relationalStore.RdbStore = store;
    try {
      s.executeSync('DELETE FROM ideas');
      s.executeSync('DELETE FROM projects');
      s.executeSync('DELETE FROM nodes');

      Hub.ideas.forEach((i: Idea) => {
        const vb: relationalStore.ValuesBucket = {
          'id': i.id,
          'content': i.content,
          'tags': JSON.stringify(i.tags),
          'createdAt': i.createdAt,
          'status': i.status
        };
        s.insertSync('ideas', vb);
      });

      Hub.projects.forEach((p: Project) => {
        const pvb: relationalStore.ValuesBucket = {
          'id': p.id,
          'title': p.title,
          'fromIdeaId': p.fromIdeaId,
          'createdAt': p.createdAt
        };
        s.insertSync('projects', pvb);
        p.nodes.forEach((n: ProjectNode) => {
          const nvb: relationalStore.ValuesBucket = {
            'nodeKey': p.id + '#' + n.name,
            'projectId': p.id,
            'name': n.name,
            'owner': n.owner,
            'dueAt': n.dueAt,
            'status': n.status,
            'notified': n.notified ? 1 : 0
          };
          s.insertSync('nodes', nvb);
        });
      });

      console.info(`[DB] 已落盘 ideas=${Hub.ideas.length} projects=${Hub.projects.length}`);
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      console.error(`[DB] save 失败 code=${err.code} msg=${err.message}`);
    }
  }

  // 首次启动预置演示数据（方便现场演示，一打开就有内容）
  static seed(): void {
    const now: number = Date.now();
    const i1: Idea = new Idea(nextId(), '做一期鸿蒙 ArkAF 端侧智能体框架的深度拆解', [], now, 'draft');
    const i2: Idea = new Idea(nextId(), '万兆家庭网络组网实测：从布线到跑满带宽', [], now - 1000, 'draft');
    const i3: Idea = new Idea(nextId(), 'AI 眼镜横评：六款旗舰一次看懂', [], now - 2000, 'converted');
    Hub.ideas.push(i1, i2, i3);

    const nodes: ProjectNode[] = NODE_TEMPLATES.map((t: NodeTemplate) =>
      new ProjectNode(t.name, t.owner, now + t.offsetDays * DAY_MS, 'pending', false));
    const p: Project = new Project(nextId(), 'AI 眼镜横评：六款旗舰一次看懂', i3.id, now, nodes);
    Hub.projects.push(p);

    Persist.save();
    console.info('[DB] 已预置演示数据');
  }
}
