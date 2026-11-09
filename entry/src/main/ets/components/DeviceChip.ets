import { Device } from '../model/Types';
import { Fmt } from '../model/Readers';

/** 设备现状小卡片：名称 + 开/关 + 主属性。用 @Prop 保证设备值变化时能刷新。 */
@Component
export struct DeviceChip {
  @Prop device: Device;

  private hasProp(key: string): boolean {
    return Object.keys(this.device.props).indexOf(key) >= 0;
  }

  private line(): string {
    if (!this.device.power) {
      return '关';
    }
    if (this.hasProp('brightness')) {
      return `开 · ${Fmt.num(this.device.props['brightness'], 0)}%`;
    }
    if (this.hasProp('temperature')) {
      return `开 · ${Fmt.num(this.device.props['temperature'], 0)}℃`;
    }
    if (this.hasProp('speed')) {
      return `开 · ${Fmt.num(this.device.props['speed'], 0)} 档`;
    }
    if (this.hasProp('position')) {
      return `开 · ${Fmt.num(this.device.props['position'], 0)}%`;
    }
    return '开';
  }

  build() {
    Column({ space: 2 }) {
      Text(this.device.name)
        .fontSize(12)
        .fontColor('#0F172A')
        .fontWeight(FontWeight.Medium)
      Text(this.line())
        .fontSize(11)
        .fontColor(this.device.power ? '#16A34A' : '#94A3B8')
    }
    .alignItems(HorizontalAlign.Start)
    .padding(10)
    .margin({ bottom: 8 })
    .width('48%')
    .backgroundColor('#F7F9FC')
    .borderRadius(10)
  }
}
