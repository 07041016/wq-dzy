import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ConflictItem, DeviceAction, ExecutionRecord } from '../model/Types';

const DOMAIN: number = 0x0001;
const TAG: string = 'QisheLog';
const TABLE: string = 'execution_log';
const MAX_ROWS: number = 500;

const DDL: string = 'CREATE TABLE IF NOT EXISTS execution_log ('
  + 'id INTEGER PRIMARY KEY AUTOINCREMENT, '
  + 'ts INTEGER NOT NULL, '
  + 'seq INTEGER NOT NULL, '
  + 'rule_id TEXT NOT NULL, '
  + 'rule_name TEXT NOT NULL, '
  + 'condition_text TEXT, '
  + 'matched INTEGER DEFAULT 0, '
  + 'actions_json TEXT, '
  + 'conflicts_json TEXT, '
  + 'skipped INTEGER DEFAULT 0)';

const IDX: string = 'CREATE INDEX IF NOT EXISTS idx_log_ts ON execution_log (ts DESC)';

const TRIM: string = 'DELETE FROM execution_log WHERE id NOT IN '
  + '(SELECT id FROM execution_log ORDER BY ts DESC LIMIT ' + MAX_ROWS + ')';

const COLUMNS: string[] = ['id', 'ts', 'seq', 'rule_id', 'rule_name', 'condition_text',
  'matched', 'actions_json', 'conflicts_json', 'skipped'];

/**
 * 执行日志：RDB 一张表，按 ts 倒序索引，保留最近 500 条。
 * 写失败只记 HiLog 并返回，绝不中断设备联动。
 */
export class LogRepository {
  private static rdb: relationalStore.RdbStore | null = null;
  private static healthy: boolean = false;

  static async init(context: common.UIAbilityContext): Promise<boolean> {
    if (LogRepository.rdb !== null) {
      return LogRepository.healthy;
    }
    try {
      const config: relationalStore.StoreConfig = {
        name: 'qishe_log.db',
        securityLevel: relationalStore.SecurityLevel.S1
      };
      LogRepository.rdb = await relationalStore.getRdbStore(context, config);
      await LogRepository.rdb.executeSql(DDL);
      await LogRepository.rdb.executeSql(IDX);
      LogRepository.healthy = true;
      hilog.info(DOMAIN, TAG, 'rdb ready');
      return true;
    } catch (err) {
      LogRepository.healthy = false;
      hilog.error(DOMAIN, TAG, 'rdb init failed: %{public}s', JSON.stringify(err));
      return false;
    }
  }

  static available(): boolean {
    return LogRepository.rdb !== null && LogRepository.healthy;
  }

  static async append(records: ExecutionRecord[]): Promise<void> {
    if (records.length === 0 || LogRepository.rdb === null) {
      return;
    }
    try {
      for (let i = 0; i < records.length; i++) {
        const r: ExecutionRecord = records[i];
        const bucket: relationalStore.ValuesBucket = {
          'ts': r.ts,
          'seq': r.seq,
          'rule_id': r.ruleId,
          'rule_name': r.ruleName,
          'condition_text': r.conditionText,
          'matched': r.matched ? 1 : 0,
          'actions_json': JSON.stringify(r.actions),
          'conflicts_json': JSON.stringify(r.conflicts),
          'skipped': r.skipped ? 1 : 0
        };
        await LogRepository.rdb.insert(TABLE, bucket);
      }
      await LogRepository.rdb.executeSql(TRIM);
    } catch (err) {
      LogRepository.healthy = false;
      hilog.warn(DOMAIN, TAG, 'append failed: %{public}s', JSON.stringify(err));
    }
  }

  static async queryPage(offset: number, size: number): Promise<ExecutionRecord[]> {
    const out: ExecutionRecord[] = [];
    if (LogRepository.rdb === null) {
      return out;
    }
    try {
      const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates(TABLE);
      predicates.orderByDesc('ts');
      predicates.offsetAs(offset);
      predicates.limitAs(size);
      const rs: relationalStore.ResultSet = await LogRepository.rdb.query(predicates, COLUMNS);
      while (rs.goToNextRow()) {
        out.push(LogRepository.readRow(rs));
      }
      rs.close();
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'query failed: %{public}s', JSON.stringify(err));
    }
    return out;
  }

  /** ResultSet 的取值可能抛异常，这里统一兜底成一条“占位记录”，不影响其余行 */
  static readRow(rs: relationalStore.ResultSet): ExecutionRecord {
    try {
      const idIndex: number = rs.getColumnIndex('id');
      const tsIndex: number = rs.getColumnIndex('ts');
      const seqIndex: number = rs.getColumnIndex('seq');
      const ruleIdIndex: number = rs.getColumnIndex('rule_id');
      const ruleNameIndex: number = rs.getColumnIndex('rule_name');
      const condIndex: number = rs.getColumnIndex('condition_text');
      const matchedIndex: number = rs.getColumnIndex('matched');
      const actionsIndex: number = rs.getColumnIndex('actions_json');
      const conflictsIndex: number = rs.getColumnIndex('conflicts_json');
      const skippedIndex: number = rs.getColumnIndex('skipped');
      return {
        id: rs.getLong(idIndex),
        ts: rs.getLong(tsIndex),
        seq: rs.getLong(seqIndex),
        ruleId: rs.getString(ruleIdIndex),
        ruleName: rs.getString(ruleNameIndex),
        conditionText: rs.getString(condIndex),
        matched: rs.getLong(matchedIndex) === 1,
        actions: LogRepository.parseActions(rs.getString(actionsIndex)),
        conflicts: LogRepository.parseConflicts(rs.getString(conflictsIndex)),
        skipped: rs.getLong(skippedIndex) === 1
      };
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'read row failed: %{public}s', JSON.stringify(err));
      return {
        id: 0, ts: 0, seq: 0, ruleId: '', ruleName: '（记录读取失败）',
        conditionText: '', matched: false, actions: [], conflicts: [], skipped: false
      };
    }
  }

  static parseActions(json: string): DeviceAction[] {
    try {
      return JSON.parse(json) as DeviceAction[];
    } catch (err) {
      return [];
    }
  }

  static parseConflicts(json: string): ConflictItem[] {
    try {
      return JSON.parse(json) as ConflictItem[];
    } catch (err) {
      return [];
    }
  }

  static async count(): Promise<number> {
    if (LogRepository.rdb === null) {
      return 0;
    }
    try {
      const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates(TABLE);
      const rs: relationalStore.ResultSet = await LogRepository.rdb.query(predicates, ['id']);
      const total: number = rs.rowCount;
      rs.close();
      return total < 0 ? 0 : total;
    } catch (err) {
      return 0;
    }
  }

  static async clear(): Promise<void> {
    if (LogRepository.rdb === null) {
      return;
    }
    try {
      await LogRepository.rdb.executeSql('DELETE FROM execution_log');
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'clear failed');
    }
  }
}
