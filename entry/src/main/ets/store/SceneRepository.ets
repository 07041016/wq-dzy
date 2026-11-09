import { ScenePayload, SceneProfile, SCHEMA_VERSION } from '../model/Types';
import { Defaults } from '../model/Defaults';
import { Prefs } from './Prefs';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0x0001;
const TAG: string = 'QisheScene';
const KEY_SCENES: string = 'qishe.scenes';

/** 场景演练：3 组预设 + 用户另存的自定义场景 */
export class SceneRepository {
  static async loadScenes(): Promise<SceneProfile[]> {
    const raw: string = await Prefs.getString(KEY_SCENES, '');
    if (raw.length === 0) {
      return Defaults.scenes();
    }
    try {
      const payload: ScenePayload = JSON.parse(raw) as ScenePayload;
      if (payload.schemaVersion !== SCHEMA_VERSION || payload.scenes.length === 0) {
        return Defaults.scenes();
      }
      return payload.scenes;
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'loadScenes failed, fallback to seed');
      return Defaults.scenes();
    }
  }

  static async saveScenes(scenes: SceneProfile[]): Promise<void> {
    const payload: ScenePayload = { schemaVersion: SCHEMA_VERSION, scenes: scenes };
    await Prefs.putString(KEY_SCENES, JSON.stringify(payload));
    await Prefs.flush();
  }

  static findScene(scenes: SceneProfile[], id: string): SceneProfile | undefined {
    for (let i = 0; i < scenes.length; i++) {
      if (scenes[i].id === id) {
        return scenes[i];
      }
    }
    return undefined;
  }
}
