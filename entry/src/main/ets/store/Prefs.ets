import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0x0001;
const TAG: string = 'QishePrefs';
const STORE_NAME: string = 'qishe';

/**
 * Preferences 的统一入口：四个小键（rules / devices / env / scenes）都走这里。
 * 只存字符串，业务对象由各仓储负责 JSON 序列化。
 */
export class Prefs {
  private static store: preferences.Preferences | null = null;
  private static opening: boolean = false;

  static async ensure(context: common.UIAbilityContext): Promise<boolean> {
    if (Prefs.store !== null) {
      return true;
    }
    if (Prefs.opening) {
      return false;
    }
    Prefs.opening = true;
    try {
      Prefs.store = await preferences.getPreferences(context, STORE_NAME);
      hilog.info(DOMAIN, TAG, 'preferences opened: %{public}s', STORE_NAME);
      return true;
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'open failed: %{public}s', JSON.stringify(err));
      return false;
    } finally {
      Prefs.opening = false;
    }
  }

  static ready(): boolean {
    return Prefs.store !== null;
  }

  static async getString(key: string, defValue: string): Promise<string> {
    if (Prefs.store === null) {
      return defValue;
    }
    try {
      const value = await Prefs.store.get(key, defValue);
      return value as string;
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'get %{public}s failed: %{public}s', key, JSON.stringify(err));
      return defValue;
    }
  }

  static async putString(key: string, value: string): Promise<void> {
    if (Prefs.store === null) {
      return;
    }
    try {
      await Prefs.store.put(key, value);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'put %{public}s failed: %{public}s', key, JSON.stringify(err));
    }
  }

  /** 关键操作立即落盘，不等系统调度 */
  static async flush(): Promise<void> {
    if (Prefs.store === null) {
      return;
    }
    try {
      await Prefs.store.flush();
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'flush failed: %{public}s', JSON.stringify(err));
    }
  }

  static async remove(key: string): Promise<void> {
    if (Prefs.store === null) {
      return;
    }
    try {
      await Prefs.store.delete(key);
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'delete %{public}s failed', key);
    }
  }
}
