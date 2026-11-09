import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AutomationRule, Device, EnvSnapshot, SceneProfile } from '../model/Types';
import { RuleRepository } from '../store/RuleRepository';
import { SceneRepository } from '../store/SceneRepository';
import { LogRepository } from '../store/LogRepository';
import { Prefs } from '../store/Prefs';
import { Defaults } from '../model/Defaults';
import { Keys } from '../model/Keys';
import { TickRunner } from './TickRunner';
import { EnvStore } from './EnvStore';

const DOMAIN: number = 0x0001;
const TAG: string = 'QisheBoot';

/**
 * 冷启动恢复：在首帧之前把四个键与一次 count 读出来，一次性写入 AppStorage，
 * 页面开始订阅时数据已就位，不会出现“先默认值、后跳真实值”的闪变。
 */
export class Boot {
  private static started: boolean = false;

  static async start(context: common.UIAbilityContext): Promise<void> {
    if (Boot.started) {
      return;
    }
    Boot.started = true;
    const begin: number = Date.now();

    const opened: boolean = await Prefs.ensure(context);
    if (!opened) {
      hilog.error(DOMAIN, TAG, 'preferences unavailable, use seed in memory');
    }

    // 四个键 + RDB 并发发起，再按需 await，兼顾并发与类型明确
    const rulesP: Promise<AutomationRule[]> = RuleRepository.loadRules();
    const devicesP: Promise<Device[]> = RuleRepository.loadDevices();
    const envP: Promise<EnvSnapshot> = RuleRepository.loadEnv();
    const scenesP: Promise<SceneProfile[]> = SceneRepository.loadScenes();
    const rdbP: Promise<boolean> = LogRepository.init(context);

    let rules: AutomationRule[] = Defaults.rules();
    let devices: Device[] = Defaults.devices();
    let env: EnvSnapshot = Defaults.env();
    let scenes: SceneProfile[] = Defaults.scenes();
    try {
      rules = await rulesP;
      devices = await devicesP;
      env = await envP;
      scenes = await scenesP;
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'restore partly failed: %{public}s', JSON.stringify(err));
    }
    const rdbOk: boolean = await rdbP;
    const logCount: number = rdbOk ? await LogRepository.count() : 0;

    AppStorage.setOrCreate<AutomationRule[]>(Keys.RULES, rules);
    AppStorage.setOrCreate<Device[]>(Keys.DEVICES, devices);
    AppStorage.setOrCreate<EnvSnapshot>(Keys.ENV, env);
    AppStorage.setOrCreate<SceneProfile[]>(Keys.SCENES, scenes);
    AppStorage.setOrCreate<string>(Keys.ACTIVE_SCENE, '');
    AppStorage.setOrCreate<string>(Keys.CONFLICT_TIP, '');
    AppStorage.setOrCreate<string>(Keys.LAST_PLAN, '');
    AppStorage.setOrCreate<number>(Keys.LOG_COUNT, logCount);
    AppStorage.setOrCreate<number>(Keys.LOG_VERSION, logCount);
    AppStorage.setOrCreate<boolean>(Keys.READY, true);
    TickRunner.resetRuntime();

    hilog.info(DOMAIN, TAG, 'restored %{public}d rules / %{public}d devices / %{public}d logs in %{public}d ms',
      rules.length, devices.length, logCount, Date.now() - begin);
  }

  /** 退出前强制落盘，避免最后一次拖动丢失 */
  static async flush(): Promise<void> {
    const rules: AutomationRule[] | undefined = AppStorage.get<AutomationRule[]>(Keys.RULES);
    const devices: Device[] | undefined = AppStorage.get<Device[]>(Keys.DEVICES);
    if (rules !== undefined) {
      await RuleRepository.saveRules(rules);
    }
    if (devices !== undefined) {
      await RuleRepository.saveDevices(devices);
    }
    await EnvStore.flushNow();
  }

  static rules(): AutomationRule[] {
    const value: AutomationRule[] | undefined = AppStorage.get<AutomationRule[]>(Keys.RULES);
    return value === undefined ? [] : value;
  }

  static devices(): Device[] {
    const value: Device[] | undefined = AppStorage.get<Device[]>(Keys.DEVICES);
    return value === undefined ? [] : value;
  }

  static scenes(): SceneProfile[] {
    const value: SceneProfile[] | undefined = AppStorage.get<SceneProfile[]>(Keys.SCENES);
    return value === undefined ? [] : value;
  }

  static async saveRules(rules: AutomationRule[]): Promise<void> {
    AppStorage.setOrCreate<AutomationRule[]>(Keys.RULES, rules);
    await RuleRepository.saveRules(rules);
  }

  static async saveScenes(scenes: SceneProfile[]): Promise<void> {
    AppStorage.setOrCreate<SceneProfile[]>(Keys.SCENES, scenes);
    await SceneRepository.saveScenes(scenes);
  }
}
