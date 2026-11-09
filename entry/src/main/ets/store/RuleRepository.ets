import {
  AutomationRule, Device, DevicePayload, EnvPayload, EnvSnapshot, RulePayload, SCHEMA_VERSION
} from '../model/Types';
import { Defaults } from '../model/Defaults';
import { DeviceReader } from '../model/Readers';
import { Prefs } from './Prefs';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0x0001;
const TAG: string = 'QisheRepo';
const KEY_RULES: string = 'qishe.rules';
const KEY_DEVICES: string = 'qishe.devices';
const KEY_ENV: string = 'qishe.env';

/**
 * 规则 / 设备 / 环境的持久化。
 * 都带 schemaVersion 信封：版本不符或 JSON 损坏时回落到种子数据，不让应用打不开。
 */
export class RuleRepository {
  /** 纯函数：解析规则信封，便于单测直接验证版本回落 */
  static decodeRules(raw: string): AutomationRule[] {
    if (raw.length === 0) {
      return Defaults.rules();
    }
    try {
      const payload: RulePayload = JSON.parse(raw) as RulePayload;
      if (payload.schemaVersion !== SCHEMA_VERSION) {
        return Defaults.rules();
      }
      return payload.rules;
    } catch (err) {
      return Defaults.rules();
    }
  }

  static async loadRules(): Promise<AutomationRule[]> {
    const raw: string = await Prefs.getString(KEY_RULES, '');
    if (raw.length === 0) {
      hilog.info(DOMAIN, TAG, 'no rules yet, seed 6 rules');
      return Defaults.rules();
    }
    try {
      const payload: RulePayload = JSON.parse(raw) as RulePayload;
      if (payload.schemaVersion !== SCHEMA_VERSION) {
        hilog.warn(DOMAIN, TAG, 'schema %{public}d != %{public}d, fallback to seed',
          payload.schemaVersion, SCHEMA_VERSION);
        return Defaults.rules();
      }
      return payload.rules;
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'loadRules failed: %{public}s, fallback to seed', JSON.stringify(err));
      return Defaults.rules();
    }
  }

  static async saveRules(rules: AutomationRule[]): Promise<void> {
    const payload: RulePayload = { schemaVersion: SCHEMA_VERSION, rules: rules };
    await Prefs.putString(KEY_RULES, JSON.stringify(payload));
    await Prefs.flush();
  }

  static async loadDevices(): Promise<Device[]> {
    const raw: string = await Prefs.getString(KEY_DEVICES, '');
    if (raw.length === 0) {
      return Defaults.devices();
    }
    try {
      const payload: DevicePayload = JSON.parse(raw) as DevicePayload;
      if (payload.schemaVersion !== SCHEMA_VERSION || payload.devices.length === 0) {
        return Defaults.devices();
      }
      const fixed: Device[] = [];
      for (let i = 0; i < payload.devices.length; i++) {
        fixed.push(DeviceReader.clone(payload.devices[i]));
      }
      return fixed;
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'loadDevices failed, fallback to seed');
      return Defaults.devices();
    }
  }

  static async saveDevices(devices: Device[]): Promise<void> {
    const payload: DevicePayload = { schemaVersion: SCHEMA_VERSION, devices: devices };
    await Prefs.putString(KEY_DEVICES, JSON.stringify(payload));
  }

  static async loadEnv(): Promise<EnvSnapshot> {
    const raw: string = await Prefs.getString(KEY_ENV, '');
    if (raw.length === 0) {
      return Defaults.env();
    }
    try {
      const payload: EnvPayload = JSON.parse(raw) as EnvPayload;
      if (payload.schemaVersion !== SCHEMA_VERSION) {
        return Defaults.env();
      }
      return payload.env;
    } catch (err) {
      return Defaults.env();
    }
  }

  static async saveEnv(env: EnvSnapshot): Promise<void> {
    const payload: EnvPayload = { schemaVersion: SCHEMA_VERSION, env: env };
    await Prefs.putString(KEY_ENV, JSON.stringify(payload));
  }
}
