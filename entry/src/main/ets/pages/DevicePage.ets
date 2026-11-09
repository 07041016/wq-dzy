import { Device, PROP_RANGES, EnvRange } from '../model/Types';
import { DeviceReader, Fmt } from '../model/Readers';
import { Defaults } from '../model/Defaults';
import { RuleRepository } from '../store/RuleRepository';

/**
 * 设备面板：展示 4 类 5 台设备，可手动开关与步进调整属性。
 * 手动调整直接落盘，不触发 tick（避免和规则互相覆盖导致抖动）。
 */
@Component
export struct DevicePage {
  @StorageLink('deviceList') devices: Device[] = Defaults.devices();

  private persist(next: Device[]): void {
    this.devices = next;
    RuleRepository.saveDevices(next);
  }

  private togglePower(dev: Device, on: boolean): void {
    const next: Device[] = DeviceReader.cloneAll(this.devices);
    const target: Device | undefined = DeviceReader.find(next, dev.id);
    if (target === undefined) {
      return;
    }
    target.power = on;
    target.updatedAt = Date.now();
    this.persist(next);
  }

  private bump(dev: Device, prop: string, delta: number): void {
    const next: Device[] = DeviceReader.cloneAll(this.devices);
    const target: Device | undefined = DeviceReader.find(next, dev.id);
    if (target === undefined) {
      return;
    }
    const current: number = DeviceReader.read(target, prop);
    if (Number.isNaN(current)) {
      return;
    }
    const value: number = DeviceReader.clampProp(prop, current + delta);
    DeviceReader.write(target, prop, value);
    target.updatedAt = Date.now();
    this.persist(next);
  }

  private hasProp(dev: Device, key: string): boolean {
    return Object.keys(dev.props).indexOf(key) >= 0;
  }

  /** light / ac / fan / curtain 的中文名 */
  private kindText(kind: string): string {
    if (kind === 'light') {
      return '照明';
    }
    if (kind === 'ac') {
      return '温控';
    }
    if (kind === 'fan') {
      return '通风';
    }
    if (kind === 'curtain') {
      return '遮光';
    }
    return kind;
  }

  private propLabel(prop: string): string {
    const range: EnvRange | undefined = PROP_RANGES[prop];
    return range === undefined ? prop : range.label;
  }

  @Builder
  propRow(dev: Device, prop: string, delta: number) {
    Row() {
      Text(this.propLabel(prop))
        .fontSize(12)
        .fontColor('#64748B')
        .width(52)
      Text(Fmt.deviceProp(dev, prop))
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor('#0F172A')
        .layoutWeight(1)
        .textAlign(TextAlign.End)
      Text('−')
        .fontSize(16)
        .fontColor('#2563EB')
        .width(34)
        .height(28)
        .textAlign(TextAlign.Center)
        .backgroundColor('#EFF6FF')
        .borderRadius(8)
        .onClick(() => {
          this.bump(dev, prop, -delta);
        })
      Text('+')
        .fontSize(16)
        .fontColor('#2563EB')
        .width(34)
        .height(28)
        .textAlign(TextAlign.Center)
        .backgroundColor('#EFF6FF')
        .borderRadius(8)
        .margin({ left: 8 })
        .onClick(() => {
          this.bump(dev, prop, delta);
        })
    }
    .width('100%')
    .margin({ top: 6 })
  }

  @Builder
  deviceCard(dev: Device) {
    Column({ space: 4 }) {
      Row({ space: 8 }) {
        Text(dev.name)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#0F172A')
          .layoutWeight(1)
        Text(dev.power ? '开' : '关')
          .fontSize(11)
          .fontColor(dev.power ? '#16A34A' : '#94A3B8')
        Toggle({ type: ToggleType.Switch, isOn: dev.power })
          .selectedColor('#2563EB')
          .onChange((isOn: boolean) => {
            this.togglePower(dev, isOn);
          })
      }
      .width('100%')

      Text(`${dev.room} · ${this.kindText(dev.kind)}`)
        .fontSize(10)
        .fontColor('#94A3B8')
        .width('100%')

      if (this.hasProp(dev, 'brightness')) {
        this.propRow(dev, 'brightness', 10)
      }
      if (this.hasProp(dev, 'temperature')) {
        this.propRow(dev, 'temperature', 1)
      }
      if (this.hasProp(dev, 'speed')) {
        this.propRow(dev, 'speed', 1)
      }
      if (this.hasProp(dev, 'position')) {
        this.propRow(dev, 'position', 10)
      }
    }
    .width('100%')
    .padding(14)
    .backgroundColor(Color.White)
    .borderRadius(14)
    .margin({ bottom: 10 })
  }

  build() {
    List({ space: 0 }) {
      ForEach(this.devices, (dev: Device) => {
        ListItem() {
          this.deviceCard(dev)
        }
      }, (dev: Device) => `${dev.id}-${dev.power}-${dev.updatedAt}`)
    }
    .width('100%')
    .height('100%')
    .padding({ left: 14, right: 14, top: 4 })
    .scrollBar(BarState.Off)
  }
}


