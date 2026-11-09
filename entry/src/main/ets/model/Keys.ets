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

/** 进程内事件名（@ohos.events.emitter） */
export class Events {
  static readonly ENV_CHANGED: number = 1001;
  static readonly RULE_CHANGED: number = 1002;
  static readonly PLAN_APPLIED: number = 1003;
}
