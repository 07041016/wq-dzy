/**
 * 数据模型与常量。
 * 全部使用 interface / enum，保证可 JSON 序列化，便于写入 Preferences。
 */

/** 设备四大类：照明 / 温控 / 通风 / 遮光 */
export enum DeviceKind {
  LIGHT = 'light',
  AC = 'ac',
  FAN = 'fan',
  CURTAIN = 'curtain'
}

/** 可调环境量 */
export enum EnvKey {
  TEMPERATURE = 'temperature',
  HUMIDITY = 'humidity',
  ILLUMINANCE = 'illuminance',
  NOISE = 'noise'
}

/** 条件算子 */
export enum CondOp {
  GT = '>',
  GE = '>=',
  LT = '<',
  LE = '<=',
  EQ = '=='
}

/** 条件来源 */
export enum CondSource {
  ENV = 'env',
  DEVICE = 'device'
}

/** 一台可控制设备。power 单独一个布尔字段，其余属性放 props，引擎统一按数值比较。 */
export interface Device {
  id: string;
  kind: DeviceKind;
  name: string;
  room: string;
  power: boolean;
  props: Record<string, number>;
  updatedAt: number;
}

/** 一次 tick 的环境输入 */
export interface EnvSnapshot {
  temperature: number;
  humidity: number;
  illuminance: number;
  noise: number;
  updatedAt: number;
}

export interface Condition {
  source: string;
  key: string;
  deviceId: string;
  op: string;
  value: number;
}

export interface ConditionGroup {
  logic: string;
  items: Condition[];
}

export interface DeviceAction {
  deviceId: string;
  property: string;
  value: number;
}

/** 一条“当……就……”规则 */
export interface AutomationRule {
  id: string;
  name: string;
  enabled: boolean;
  priority: number;
  cooldownMs: number;
  createdSeq: number;
  conditionGroup: ConditionGroup;
  actions: DeviceAction[];
  updatedAt: number;
}

export interface ConflictItem {
  ruleId: string;
  ruleName: string;
  targetKey: string;
  want: number;
  keptBy: string;
  keptPriority: number;
}

export interface ExecStep {
  seq: number;
  ruleId: string;
  ruleName: string;
  priority: number;
  conditionText: string;
  actions: DeviceAction[];
  skipped: boolean;
  cooldownRemainMs: number;
}

export interface ExecutionRecord {
  id: number;
  ts: number;
  seq: number;
  ruleId: string;
  ruleName: string;
  conditionText: string;
  matched: boolean;
  actions: DeviceAction[];
  conflicts: ConflictItem[];
  skipped: boolean;
}

export interface ExecutionPlan {
  steps: ExecStep[];
  conflicts: ConflictItem[];
  records: ExecutionRecord[];
}

export interface RuleRuntimeState {
  ruleId: string;
  lastTriggeredAt: number;
}

export interface SceneProfile {
  id: string;
  name: string;
  env: EnvSnapshot;
  devices: Device[];
  createdAt: number;
}

/** 引擎入参：三份快照 + 运行时状态 + 统一时钟 */
export interface EngineInput {
  env: EnvSnapshot;
  devices: Device[];
  rules: AutomationRule[];
  runtime: Map<string, RuleRuntimeState>;
  now: number;
}

/** 一次裁决中单条规则的中间结果 */
export interface ResolvedStep {
  rule: AutomationRule;
  actions: DeviceAction[];
  skipped: boolean;
  cooldownRemainMs: number;
}

export interface ResolveResult {
  steps: ResolvedStep[];
  conflicts: ConflictItem[];
}

export interface RulePayload {
  schemaVersion: number;
  rules: AutomationRule[];
}

export interface DevicePayload {
  schemaVersion: number;
  devices: Device[];
}

export interface ScenePayload {
  schemaVersion: number;
  scenes: SceneProfile[];
}

export interface EnvPayload {
  schemaVersion: number;
  env: EnvSnapshot;
}

/** 各环境量的合法区间，clamp 与校验共用 */
export interface EnvRange {
  min: number;
  max: number;
  unit: string;
  label: string;
}

export const ENV_RANGES: Record<string, EnvRange> = {
  'temperature': { min: -10, max: 45, unit: '℃', label: '温度' },
  'humidity': { min: 0, max: 100, unit: '%', label: '湿度' },
  'illuminance': { min: 0, max: 2000, unit: 'lx', label: '光照' },
  'noise': { min: 0, max: 100, unit: 'dB', label: '噪声' }
};

/** 设备属性的合法区间 */
export const PROP_RANGES: Record<string, EnvRange> = {
  'power': { min: 0, max: 1, unit: '', label: '开关' },
  'brightness': { min: 0, max: 100, unit: '%', label: '亮度' },
  'colorTemp': { min: 3000, max: 6500, unit: 'K', label: '色温' },
  'temperature': { min: 16, max: 30, unit: '℃', label: '温度' },
  'speed': { min: 1, max: 3, unit: '档', label: '档位' },
  'position': { min: 0, max: 100, unit: '%', label: '开合' }
};

export const SCHEMA_VERSION: number = 2;

/** 分段选择器（chip）的一项 */
export interface ChipItem {
  value: string;
  label: string;
}

