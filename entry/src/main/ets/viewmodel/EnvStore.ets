import { EnvKey, EnvSnapshot } from '../model/Types';
import { EnvReader } from '../model/Readers';
import { Defaults } from '../model/Defaults';
import { RuleRepository } from '../store/RuleRepository';
import { Keys } from '../model/Keys';

/** 环境状态：clamp、写 AppStorage、防抖落盘 */
export class EnvStore {
  private static saveTimer: number = -1;

  static snapshot(): EnvSnapshot {
    const value: EnvSnapshot | undefined = AppStorage.get<EnvSnapshot>(Keys.ENV);
    return value === undefined ? Defaults.env() : value;
  }

  /** 越界先 clamp，返回“新对象”，保证 @StorageLink 能观察到变化 */
  static clampInto(key: string, value: number): EnvSnapshot {
    const base: EnvSnapshot = EnvStore.snapshot();
    const fixed: number = EnvReader.clamp(key, value);
    const next: EnvSnapshot = {
      temperature: base.temperature,
      humidity: base.humidity,
      illuminance: base.illuminance,
      noise: base.noise,
      updatedAt: Date.now()
    };
    switch (key) {
      case EnvKey.TEMPERATURE:
        next.temperature = fixed;
        break;
      case EnvKey.HUMIDITY:
        next.humidity = fixed;
        break;
      case EnvKey.ILLUMINANCE:
        next.illuminance = fixed;
        break;
      case EnvKey.NOISE:
        next.noise = fixed;
        break;
      default:
        break;
    }
    return next;
  }

  static publish(env: EnvSnapshot): void {
    AppStorage.setOrCreate<EnvSnapshot>(Keys.ENV, env);
    EnvStore.scheduleSave(env);
  }

  /** 400 ms 防抖：拖动过程中不反复序列化 */
  static scheduleSave(env: EnvSnapshot): void {
    if (EnvStore.saveTimer !== -1) {
      clearTimeout(EnvStore.saveTimer);
    }
    EnvStore.saveTimer = setTimeout(() => {
      EnvStore.saveTimer = -1;
      RuleRepository.saveEnv(env);
    }, 400);
  }

  static async flushNow(): Promise<void> {
    if (EnvStore.saveTimer !== -1) {
      clearTimeout(EnvStore.saveTimer);
      EnvStore.saveTimer = -1;
    }
    await RuleRepository.saveEnv(EnvStore.snapshot());
  }
}
