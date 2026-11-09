import { ChipItem } from '../model/Types';

/** 分段选择器：一行小标签，点谁选谁。规则编辑器里的条件、算子、设备、属性都用它。 */
@Component
export struct ChipRow {
  @Prop label: string = '';
  @Prop items: ChipItem[] = [];
  @Prop current: string = '';
  onPick: (value: string) => void = (value: string) => {
  };

  build() {
    Column({ space: 4 }) {
      Text(this.label)
        .fontSize(11)
        .fontColor('#94A3B8')
        .width('100%')
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.items, (item: ChipItem) => {
          Text(item.label)
            .fontSize(12)
            .fontColor(this.current === item.value ? Color.White : '#1D4ED8')
            .padding({ left: 10, right: 10, top: 4, bottom: 4 })
            .margin({ right: 6, bottom: 6 })
            .backgroundColor(this.current === item.value ? '#2563EB' : '#EFF6FF')
            .borderRadius(10)
            .onClick(() => {
              this.onPick(item.value);
            })
        }, (item: ChipItem) => item.value)
      }
      .width('100%')
    }
    .width('100%')
  }
}

