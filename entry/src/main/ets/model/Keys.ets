/** AppStorage 键名集中定义，避免字符串散落各处 */
export class Keys {
  static readonly ENV: string = 'envSnapshot';
  static readonly DEVICES: string = 'deviceList';
  static readonly RULES: string = 'ruleList';
  static readonly SCENES: string = 'sceneList';
  static readonly ACTIVE_SCENE: string = 'activeSceneId';
  static readonly CONFLICT_TIP: string = 'conflictTip';
  static readonly LOG_VERSION: string = 'logVersion';
  static readonly LOG_COUNT: string = 'logCount';
  static readonly READY: string = 'appReady';
  static readonly LAST_PLAN: string = 'lastPlanTip';
}

/**
 * 进程内事件名（@kit.BasicServicesKit 的 emitter）。
 * API 24 的 emitter.on/emit 只接受 InnerEvent 或字符串事件名，这里统一用字符串，
 * 语义也更直白：'env:changed' → 环境变化，'plan:applied' → 一次 tick 已落库。
 */
export class Events {
  static readonly ENV_CHANGED: string = 'env:changed';
  static readonly RULE_CHANGED: string = 'rule:changed';
  static readonly PLAN_APPLIED: string = 'plan:applied';
}

