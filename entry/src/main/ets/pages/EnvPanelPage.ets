import { Device, EnvKey, EnvSnapshot, SceneProfile } from '../model/Types';
import { DeviceReader, EnvReader, Fmt } from '../model/Readers';
import { Defaults } from '../model/Defaults';
import { EnvStore } from '../viewmodel/EnvStore';
import { TickRunner } from '../viewmodel/TickRunner';
import { Boot } from '../viewmodel/Boot';
import { EnvSliderRow } from '../components/EnvSliderRow';
import { DeviceChip } from '../components/DeviceChip';
import { Ui } from '../common/Ui';
import { util } from '@kit.ArkTS';

/**
 * 环境模拟台：四路滑块驱动一次 tick。
 * 拖动过程只更新数值 + 300 ms 防抖，抬起后由 TickRunner 统一求值。
 */
@Component
export struct EnvPanelPage {
  @StorageLink('envSnapshot') env: EnvSnapshot = Defaults.env();
  @StorageLink('deviceList') devices: Device[] = Defaults.devices();
  @StorageLink('activeSceneId') activeSceneId: string = '';
  @StorageProp('sceneList') scenes: SceneProfile[] = Defaults.scenes();
  @StorageProp('lastPlanTip') lastPlan: string = '';
  @StorageProp('conflictTip') conflictTip: string = '';
  private pendingTick: number = -1;

  private onEnvChange(key: string, value: number): void {
    if (!Number.isFinite(value)) {
      Ui.toast(this.getUIContext(), '数值超出范围');
      return;
    }
    const next: EnvSnapshot = EnvStore.clampInto(key, value);
    this.env = next;
    EnvStore.publish(next);
    this.scheduleTick();
  }

  private scheduleTick(): void {
    if (this.pendingTick !== -1) {
      clearTimeout(this.pendingTick);
    }
    this.pendingTick = setTimeout(() => {
      this.pendingTick = -1;
      TickRunner.tick();
    }, 300);
  }

  private applyScene(scene: SceneProfile): void {
    const env: EnvSnapshot = {
      temperature: scene.env.temperature,
      humidity: scene.env.humidity,
      illuminance: scene.env.illuminance,
      noise: scene.env.noise,
      updatedAt: Date.now()
    };
    this.env = env;
    EnvStore.publish(env);
    this.devices = DeviceReader.cloneAll(scene.devices);
    this.activeSceneId = scene.id;
    this.scheduleTick();
    Ui.toast(this.getUIContext(), `已装载场景「${scene.name}」`);
  }

  private saveScene(): void {
    const list: SceneProfile[] = this.scenes.slice();
    const scene: SceneProfile = {
      id: `S-${util.generateRandomUUID(false).substring(0, 6)}`,
      name: `自定义 ${list.length + 1}`,
      env: this.env,
      devices: DeviceReader.cloneAll(this.devices),
      createdAt: Date.now()
    };
    list.push(scene);
    Boot.saveScenes(list);
    Ui.toast(this.getUIContext(), '已另存为自定义场景');
  }

  build() {
    Scroll() {
      Column({ space: 12 }) {
        Column({ space: 2 }) {
          Row() {
            Text('实时环境').fontSize(15).fontWeight(FontWeight.Bold).fontColor('#0F172A')
            Blank()
            Text('4 项可调').fontSize(11).fontColor('#94A3B8')
          }
          .width('100%')
          .padding({ bottom: 4 })

          EnvSliderRow({
            label: '温度',
            unit: '℃',
            value: this.env.temperature,
            minValue: EnvReader.rangeOf(EnvKey.TEMPERATURE).min,
            maxValue: EnvReader.rangeOf(EnvKey.TEMPERATURE).max,
            stepValue: 0.1,
            digits: 1,
            onValue: (v: number) => {
              this.onEnvChange(EnvKey.TEMPERATURE, v);
            }
          })
          EnvSliderRow({
            label: '湿度',
            unit: '%',
            value: this.env.humidity,
            minValue: EnvReader.rangeOf(EnvKey.HUMIDITY).min,
            maxValue: EnvReader.rangeOf(EnvKey.HUMIDITY).max,
            stepValue: 1,
            digits: 0,
            onValue: (v: number) => {
              this.onEnvChange(EnvKey.HUMIDITY, v);
            }
          })
          EnvSliderRow({
            label: '光照',
            unit: 'lx',
            value: this.env.illuminance,
            minValue: EnvReader.rangeOf(EnvKey.ILLUMINANCE).min,
            maxValue: EnvReader.rangeOf(EnvKey.ILLUMINANCE).max,
            stepValue: 10,
            digits: 0,
            onValue: (v: number) => {
              this.onEnvChange(EnvKey.ILLUMINANCE, v);
            }
          })
          EnvSliderRow({
            label: '噪声',
            unit: 'dB',
            value: this.env.noise,
            minValue: EnvReader.rangeOf(EnvKey.NOISE).min,
            maxValue: EnvReader.rangeOf(EnvKey.NOISE).max,
            stepValue: 1,
            digits: 0,
            onValue: (v: number) => {
              this.onEnvChange(EnvKey.NOISE, v);
            }
          })
        }
        .width('100%')
        .padding(14)
        .backgroundColor(Color.White)
        .borderRadius(14)

        Row() {
          Text(this.lastPlan.length > 0 ? this.lastPlan : '等待环境变化…')
            .fontSize(12)
            .fontColor('#1D4ED8')
            .layoutWeight(1)
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 8, bottom: 8 })
        .backgroundColor('#EFF6FF')
        .borderRadius(10)

        if (this.conflictTip.length > 0) {
          Column({ space: 2 }) {
            Text('⚠ 控制目标冲突').fontSize(12).fontWeight(FontWeight.Bold).fontColor('#B45309')
            Text(this.conflictTip).fontSize(11).fontColor('#B45309')
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(10)
          .backgroundColor('#FFFBEB')
          .borderRadius(10)
          .border({ width: 1, color: '#F59E0B' })
        }

        Column({ space: 6 }) {
          Row() {
            Text('设备现状').fontSize(15).fontWeight(FontWeight.Bold).fontColor('#0F172A')
            Blank()
            Text(`${this.devices.length} 台`).fontSize(11).fontColor('#94A3B8')
          }
          .width('100%')

          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
            ForEach(this.devices, (dev: Device) => {
              DeviceChip({ device: dev })
            }, (dev: Device) => `${dev.id}-${dev.power}-${dev.updatedAt}`)
          }
          .width('100%')
        }
        .width('100%')
        .padding(14)
        .backgroundColor(Color.White)
        .borderRadius(14)

        Column({ space: 6 }) {
          Row() {
            Text('场景演练').fontSize(15).fontWeight(FontWeight.Bold).fontColor('#0F172A')
            Blank()
            Text('另存当前 →')
              .fontSize(11)
              .fontColor('#2563EB')
              .onClick(() => {
                this.saveScene();
              })
          }
          .width('100%')

          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.scenes, (scene: SceneProfile) => {
              Text(scene.name)
                .fontSize(12)
                .fontColor(this.activeSceneId === scene.id ? Color.White : '#1D4ED8')
                .padding({ left: 14, right: 14, top: 7, bottom: 7 })
                .margin({ right: 8, bottom: 8 })
                .backgroundColor(this.activeSceneId === scene.id ? '#2563EB' : '#EFF6FF')
                .borderRadius(16)
                .onClick(() => {
                  this.applyScene(scene);
                })
            }, (scene: SceneProfile) => scene.id)
          }
          .width('100%')
        }
        .width('100%')
        .padding(14)
        .backgroundColor(Color.White)
        .borderRadius(14)
      }
      .padding({ left: 14, right: 14, bottom: 20, top: 4 })
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
  }
}
